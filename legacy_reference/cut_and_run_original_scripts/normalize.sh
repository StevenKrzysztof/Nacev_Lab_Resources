#!/bin/bash
#SBATCH --job-name=normalize_MSK
#SBATCH --time=8:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=60
#SBATCH --mem=128G
#SBATCH --partition=HTC
#SBATCH --mail-user=ZIW183@pitt.edu
#SBATCH --mail-type=BEGIN,END,FAIL

source ~/.bashrc
conda activate benlab

# ==============================
# CONFIGURATION
# ==============================
# *** CRITICAL: must be aligned2, NOT aligned ***
INPUT_DIR="/ix1/bnacev/ziw183/Fei_data/MSK/aligned2"
OUTPUT_DIR="/ix1/bnacev/ziw183/Fei_data/MSK/normalized_tracks"
CHROM_SIZES="/ix1/bnacev/ziw183/ref/hg38/hg38.chrom.sizes.txt"
SUMMARY_FILE="$INPUT_DIR/alignment_and_spikein_summary.txt"
NORM_SUMMARY="$OUTPUT_DIR/normalization_summary.txt"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/bedgraph"
mkdir -p "$OUTPUT_DIR/bigwig"

THREADS=16

# ==============================
# PRE-FLIGHT CHECKS
# ==============================
echo "========================================"
echo "Pre-flight checks"
echo "========================================"

if [ ! -f "$SUMMARY_FILE" ]; then
    echo "[FATAL] Summary file not found: $SUMMARY_FILE"
    exit 1
fi

if [ ! -f "$CHROM_SIZES" ]; then
    echo "[FATAL] Chrom sizes not found: $CHROM_SIZES"
    exit 1
fi

# Verify a _final.bam exists and is readable
TEST_BAM=$(find "$INPUT_DIR" -name "*_final.bam" -type f | head -1)
if [ -z "$TEST_BAM" ]; then
    echo "[FATAL] No *_final.bam files found in $INPUT_DIR"
    exit 1
fi
if ! samtools quickcheck "$TEST_BAM" 2>/dev/null; then
    echo "[FATAL] Test BAM is corrupted: $TEST_BAM"
    exit 1
fi

echo "  INPUT_DIR:    $INPUT_DIR"
echo "  SUMMARY_FILE: $SUMMARY_FILE"
echo "  CHROM_SIZES:  $CHROM_SIZES"
echo "  OUTPUT_DIR:   $OUTPUT_DIR"
echo "  Test BAM OK:  $TEST_BAM"
echo ""

# ==============================
# Helper: extract target (mark) from sample name
# ==============================
get_target() {
    echo "$1" | sed 's/^SYO-1_\(WT\|KO\)_//' | sed 's/_IGO_.*//'
}

# ==============================
# STEP 1: Calculate target-specific scale factors
# ==============================
echo "========================================"
echo "Step 1: Calculating target-specific scale factors"
echo "========================================"
echo ""
echo "NOTE: old and new antibody batches are normalized SEPARATELY."
echo "      e.g. H3K36me2_old and H3K36me2_new are independent groups."
echo ""

echo -e "Sample\tTarget\tDm_SpikeIn_Reads\tTarget_Min_Dm_SpikeIn\tScale_Factor" > "$NORM_SUMMARY"

targets=$(tail -n +2 "$SUMMARY_FILE" | awk -F'\t' '{print $1}' \
    | while read s; do get_target "$s"; done \
    | sort -u)

echo "Detected target groups:"
echo "$targets"
echo ""

for target in $targets; do
    echo "Processing target group: $target"

    samples=$(tail -n +2 "$SUMMARY_FILE" | awk -F'\t' '{print $1}' \
        | while read s; do
            t=$(get_target "$s")
            [ "$t" = "$target" ] && echo "$s"
        done)

    min_dm_spike=999999999
    for sample in $samples; do
        dm_spike_count=$(grep "^${sample}	" "$SUMMARY_FILE" | cut -f4)
        if [ -n "$dm_spike_count" ] && [ "$dm_spike_count" -gt 0 ] && [ "$dm_spike_count" -lt "$min_dm_spike" ]; then
            min_dm_spike=$dm_spike_count
        fi
    done

    if [ "$min_dm_spike" -eq 999999999 ]; then
        echo "  [WARNING] No valid Drosophila spike-in counts found for $target"
        min_dm_spike=0
    fi

    echo "  Min Drosophila spike-in (reference): $min_dm_spike"

    for sample in $samples; do
        dm_spike_count=$(grep "^${sample}	" "$SUMMARY_FILE" | cut -f4)

        if [ -n "$dm_spike_count" ] && [ "$dm_spike_count" -gt 0 ] && [ "$min_dm_spike" -gt 0 ]; then
            scale_factor=$(awk -v min="$min_dm_spike" -v spike="$dm_spike_count" 'BEGIN {printf "%.6f", min/spike}')
        else
            scale_factor="0"
        fi

        echo -e "${sample}\t${target}\t${dm_spike_count}\t${min_dm_spike}\t${scale_factor}" >> "$NORM_SUMMARY"
        echo "    $sample: Dm=$dm_spike_count, scale=$scale_factor"
    done
    echo ""
done

# ==============================
# STEP 2: Generate normalized tracks
# ==============================
echo ""
echo "========================================"
echo "Step 2: Generating normalized tracks..."
echo "========================================"

tail -n +2 "$NORM_SUMMARY" | while IFS=$'\t' read -r sample target dm_spike min_dm scale_factor; do

    if [ "$scale_factor" == "0" ] || [ -z "$scale_factor" ]; then
        echo "[SKIP] $sample has scale_factor=0 or empty"
        continue
    fi

    BAM_FILE="$INPUT_DIR/${sample}/${sample}_final.bam"

    if [ ! -f "$BAM_FILE" ]; then
        echo "[ERROR] BAM not found: $BAM_FILE"
        continue
    fi

    if ! samtools quickcheck "$BAM_FILE" 2>/dev/null; then
        echo "[ERROR] BAM is corrupted: $BAM_FILE"
        continue
    fi

    echo "Processing: $sample (Target: $target, scale: $scale_factor)"

    # Output files
    NORM_BEDGRAPH="$OUTPUT_DIR/bedgraph/${sample}_normalized.bedgraph"
    NORM_BIGWIG="$OUTPUT_DIR/bigwig/${sample}_normalized.bw"

    # -------------------------
    # Generate coverage with spike-in normalization
    # Use _final.bam directly (already deduped + filtered in alignment pipeline)
    # -------------------------
    echo "  [1/3] Generating coverage with Drosophila spike-in normalization..."
    bedtools genomecov \
        -ibam "$BAM_FILE" \
        -bg \
        -scale "$scale_factor" \
        | sort -k1,1 -k2,2n > "$NORM_BEDGRAPH"

    if [ ! -s "$NORM_BEDGRAPH" ]; then
        echo "  [ERROR] BedGraph is empty for $sample. Skipping."
        continue
    fi

    # -------------------------
    # Convert to bigWig
    # -------------------------
    echo "  [2/3] Converting to bigWig..."
    bedGraphToBigWig "$NORM_BEDGRAPH" "$CHROM_SIZES" "$NORM_BIGWIG"

    echo "  [3/3] Done: $sample"
    echo ""

done

echo "========================================"
echo "Processing complete!"
echo ""
echo "Outputs:"
echo "  BedGraphs (for SEACR): $OUTPUT_DIR/bedgraph/"
echo "  BigWigs (for IGV):     $OUTPUT_DIR/bigwig/"
echo "  Summary:               $NORM_SUMMARY"
echo ""
echo "Normalization groups (old/new separated):"
echo "  Each target (e.g. H3K36me2_old vs H3K36me2_new) was normalized"
echo "  independently using its own minimum Drosophila spike-in reference."
echo "========================================"