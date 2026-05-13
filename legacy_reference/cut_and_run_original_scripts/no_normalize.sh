#!/bin/bash
#SBATCH --job-name=no_normalize_MSK
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
OUTPUT_DIR="/ix1/bnacev/ziw183/Fei_data/MSK/no_spikein"
CHROM_SIZES="/ix1/bnacev/ziw183/ref/hg38/hg38.chrom.sizes.txt"
TRACK_SUMMARY="$OUTPUT_DIR/track_generation_summary.txt"

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

if [ ! -f "$CHROM_SIZES" ]; then
    echo "[FATAL] Chrom sizes not found: $CHROM_SIZES"
    exit 1
fi

TEST_BAM=$(find "$INPUT_DIR" -name "*_final.bam" -type f | head -1)
if [ -z "$TEST_BAM" ]; then
    echo "[FATAL] No *_final.bam files found in $INPUT_DIR"
    exit 1
fi
if ! samtools quickcheck "$TEST_BAM" 2>/dev/null; then
    echo "[FATAL] Test BAM is corrupted: $TEST_BAM"
    exit 1
fi

echo "  INPUT_DIR:   $INPUT_DIR"
echo "  CHROM_SIZES: $CHROM_SIZES"
echo "  OUTPUT_DIR:  $OUTPUT_DIR"
echo "  Test BAM OK: $TEST_BAM"
echo ""

# ==============================
# Generate tracks with deepTools bamCoverage (CPM normalization)
# ==============================
echo "========================================"
echo "Track Generation with deepTools (CPM normalization)"
echo "========================================"
echo ""

echo -e "Sample\tHuman_Mapped_Reads" > "$TRACK_SUMMARY"

for sample_dir in "$INPUT_DIR"/SYO-1_*; do
    if [ -d "$sample_dir" ]; then
        sample=$(basename "$sample_dir")

        BAM_FILE="$INPUT_DIR/${sample}/${sample}_final.bam"

        if [ ! -f "$BAM_FILE" ]; then
            echo "[ERROR] BAM not found: $BAM_FILE"
            continue
        fi

        if ! samtools quickcheck "$BAM_FILE" 2>/dev/null; then
            echo "[ERROR] BAM is corrupted: $BAM_FILE"
            continue
        fi

        echo "Processing: $sample"

        # Output files
        CPM_BIGWIG="$OUTPUT_DIR/bigwig/${sample}_cpm.bw"
        CPM_BEDGRAPH="$OUTPUT_DIR/bedgraph/${sample}_cpm.bedgraph"

        # Get read count for summary
        READ_COUNT=$(samtools view -c "$BAM_FILE")
        echo "    Mapped reads: $READ_COUNT"

        # -------------------------
        # Generate CPM-normalized bigWig with deepTools
        # Use _final.bam directly (already deduped + filtered in alignment pipeline)
        # -------------------------
        echo "  [1/3] Generating CPM-normalized bigWig (deepTools)..."
        bamCoverage \
            -b "$BAM_FILE" \
            -o "$CPM_BIGWIG" \
            --normalizeUsing CPM \
            --binSize 10 \
            --extendReads \
            -p "$THREADS"

        # -------------------------
        # Convert bigWig to bedGraph (for SEACR)
        # -------------------------
        echo "  [2/3] Converting to bedGraph..."
        bigWigToBedGraph "$CPM_BIGWIG" "$CPM_BEDGRAPH"

        # -------------------------
        # Record summary
        # -------------------------
        echo -e "${sample}\t${READ_COUNT}" >> "$TRACK_SUMMARY"

        echo "  [3/3] Done: $sample"
        echo ""
    fi
done

echo "========================================"
echo "Processing complete!"
echo ""
echo "Outputs:"
echo "  BigWigs (for IGV):     $OUTPUT_DIR/bigwig/"
echo "  BedGraphs (for SEACR): $OUTPUT_DIR/bedgraph/"
echo "  Summary:               $TRACK_SUMMARY"
echo ""
echo "deepTools bamCoverage parameters used:"
echo "  --normalizeUsing CPM"
echo "  --binSize 10"
echo "  --extendReads"
echo ""
echo "NOTE: These tracks use CPM normalization (no spike-in)."
echo "      For quantitative comparisons, use spike-in normalized tracks."
echo "========================================"