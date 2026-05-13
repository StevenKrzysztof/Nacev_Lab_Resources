#!/bin/bash
#SBATCH --job-name=cutnrun_batch2
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=60
#SBATCH --mem=256G
#SBATCH --time=24:00:00
#SBATCH --partition=HTC
#SBATCH --mail-user=ZIW183@pitt.edu
#SBATCH --mail-type=BEGIN,END,FAIL

# ==============================
# CUT&RUN Pipeline — human (hg38) + Drosophila Spike-in
# Project: SYO-1 WT/KO MSK Data
# ==============================

# source ~/.bashrc
# conda activate benlab

# ==============================
# CONFIGURATION
# ==============================

# Raw data (FASTQs)
DATA_PATH="/ix1/bnacev/ziw183/Fei_data/MSK/Raw_data"

# human genome index (hg38)
INDEX_PATH="/ix1/bnacev/ziw183/ref/hg38/hg38"

# Drosophila spike-in index
SPIKE_DM_INDEX="/ix1/bnacev/ziw183/ref/Drosophila/Sequence/Bowtie2Index/genome"

# Output base directory
OUTPUT_BASE="/ix1/bnacev/ziw183/Fei_data/MSK/aligned2"

# Reference files
CHROM_SIZES="/ix1/bnacev/ziw183/ref/hg38/hg38.chrom.sizes.txt"
BLACKLIST_BED="/ix1/bnacev/ziw183/ref/hg38/hg38-blacklist.v2.bed"

# Threads
THREADS=60

# Summary file
SUMMARY_FILE="$OUTPUT_BASE/alignment_and_spikein_summary.txt"

# Create main output dir
mkdir -p "$OUTPUT_BASE"

# Initialize summary file with header
echo -e "Sample\thuman_Align_Rate\thuman_Mapped_Reads\tDrosophila_Mapped_Reads\tDm_Scale_Factor_100k" > "$SUMMARY_FILE"

# ==============================
# BUILD SAMPLE LIST
# ==============================

SAMPLE_LIST=($(ls "$DATA_PATH"/*_R1_001.fastq.gz 2>/dev/null \
    | xargs -I{} basename {} \
    | sed 's/_R1_001\.fastq\.gz$//' \
    | sort))

TOTAL_SAMPLES=${#SAMPLE_LIST[@]}
echo "========================================"
echo "human CUT&RUN Pipeline — Drosophila Spike-in"
echo "========================================"
echo "Total samples found: $TOTAL_SAMPLES"
echo "Raw data:            $DATA_PATH"
echo "Output base:         $OUTPUT_BASE"
echo "human index:         $INDEX_PATH"
echo "Drosophila index:    $SPIKE_DM_INDEX"
echo

# ==============================
# LOOP OVER ALL SAMPLES
# ==============================

COUNT=0
for SAMPLE in "${SAMPLE_LIST[@]}"; do
    COUNT=$((COUNT + 1))
    echo "========================================"
    echo "Processing sample ($COUNT/$TOTAL_SAMPLES): $SAMPLE"

    R1_FILE="$DATA_PATH/${SAMPLE}_R1_001.fastq.gz"
    R2_FILE="$DATA_PATH/${SAMPLE}_R2_001.fastq.gz"

    # Check if files exist
    if [ ! -f "$R1_FILE" ] || [ ! -f "$R2_FILE" ]; then
        echo "  [ERROR] Missing R1 or R2 for $SAMPLE. Skipping."
        continue
    fi

    echo "  R1: $(basename $R1_FILE)"
    echo "  R2: $(basename $R2_FILE)"

    SAMPLE_OUT="$OUTPUT_BASE/$SAMPLE"
    mkdir -p "$SAMPLE_OUT"

    # -------------------------
    # 1) Cutadapt: trim first 3 bp + Illumina Universal Adapter + PolyA + PolyG
    # -------------------------
    echo "  [1/9] Trimming (cut 3bp, Illumina adapter, polyA, polyG)..."
    TRIMMED_R1="$SAMPLE_OUT/${SAMPLE}_R1_trimmed.fq.gz"
    TRIMMED_R2="$SAMPLE_OUT/${SAMPLE}_R2_trimmed.fq.gz"

    cutadapt \
        --cut 3 \
        -a AGATCGGAAGAG \
        -A AGATCGGAAGAG \
        -a "A{20}" -A "A{20}" \
        -a "G{20}" -A "G{20}" \
        -m 20 \
        -o "$TRIMMED_R1" \
        -p "$TRIMMED_R2" \
        "$R1_FILE" "$R2_FILE" > "$SAMPLE_OUT/cutadapt.log" 2>&1

    # -------------------------
    # 2) Align to human (hg38)
    # -------------------------
    echo "  [2/9] Aligning to human (hg38)..."
    SAM_FILE="$SAMPLE_OUT/${SAMPLE}.sam"
    SORTED_BAM="$SAMPLE_OUT/${SAMPLE}_sorted.bam"
    LOG_human="$SAMPLE_OUT/${SAMPLE}_bowtie2_human.log"

    bowtie2 \
        -x "$INDEX_PATH" \
        -1 "$TRIMMED_R1" \
        -2 "$TRIMMED_R2" \
        --local --very-sensitive-local \
        --no-unal --no-mixed --no-discordant \
        --phred33 \
        -I 10 -X 700 \
        --dovetail \
        --rg-id "$SAMPLE" \
        --rg "SM:$SAMPLE" \
        --rg "PL:ILLUMINA" \
        --rg "LB:$SAMPLE" \
        -p "$THREADS" \
        -S "$SAM_FILE" \
        2> "$LOG_human"

    # -------------------------
    # 3) Sort BAM
    # -------------------------
    echo "  [3/9] Sorting BAM..."
    samtools view -Sb "$SAM_FILE" | samtools sort -@ "$THREADS" -o "$SORTED_BAM"
    samtools index "$SORTED_BAM"
    rm "$SAM_FILE"

    # -------------------------
    # 4) Picard MarkDuplicates
    # -------------------------
    echo "  [4/9] Removing duplicates (Picard)..."
    DEDUP_BAM="$SAMPLE_OUT/${SAMPLE}_dedup.bam"
    DUP_METRICS="$SAMPLE_OUT/${SAMPLE}_dup_metrics.txt"

    picard MarkDuplicates \
        I="$SORTED_BAM" \
        O="$DEDUP_BAM" \
        M="$DUP_METRICS" \
        REMOVE_DUPLICATES=true \
        VALIDATION_STRINGENCY=LENIENT

    samtools index "$DEDUP_BAM"
    rm "$SORTED_BAM" "${SORTED_BAM}.bai"

    # -------------------------
    # 5) Filter: MAPQ>=30, properly paired, canonical chroms, no blacklist
    # -------------------------
    echo "  [5/9] Filtering (MAPQ>=30, canonical chroms, no blacklist)..."
    FILTERED_BAM="$SAMPLE_OUT/${SAMPLE}_filtered.bam"
    FINAL_BAM="$SAMPLE_OUT/${SAMPLE}_final.bam"

    # MAPQ>=30 + properly paired + canonical autosomes + chrX
    samtools view -b -q 30 -f 2 "$DEDUP_BAM" \
        chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 \
        chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 \
        chrX \
        > "$FILTERED_BAM"

    # Remove blacklist regions
    bedtools intersect -v -a "$FILTERED_BAM" -b "$BLACKLIST_BED" > "$FINAL_BAM"

    samtools index "$FINAL_BAM"
    rm "$DEDUP_BAM" "${DEDUP_BAM}.bai" "$FILTERED_BAM"

    human_READS=$(samtools view -c "$FINAL_BAM")
    echo "      > human mapped reads (final): $human_READS"

    # -------------------------
    # 6) Align to DROSOPHILA (Spike-in)
    # -------------------------
    echo "  [6/9] Aligning to DROSOPHILA spike-in..."
    DM_LOG="$SAMPLE_OUT/${SAMPLE}_bowtie2_drosophila.log"

    DM_SPIKE_COUNT=$(bowtie2 \
        -x "$SPIKE_DM_INDEX" \
        -1 "$TRIMMED_R1" \
        -2 "$TRIMMED_R2" \
        --local --very-sensitive-local \
        --no-unal --no-mixed --no-discordant \
        --phred33 \
        -I 10 -X 700 \
        --dovetail \
        -p "$THREADS" \
        2> "$DM_LOG" \
        | samtools view -c -F 4 -)

    echo "      > Drosophila spike-in reads: $DM_SPIKE_COUNT"

    # -------------------------
    # 7) Scale Factor (Drosophila)
    # -------------------------
    if [ "$DM_SPIKE_COUNT" -gt 0 ]; then
        DM_SCALE_FACTOR=$(awk -v c="$DM_SPIKE_COUNT" 'BEGIN {printf "%.6f", 100000 / c}')
    else
        DM_SCALE_FACTOR="0"
        echo "      [WARNING] Drosophila spike-in count is 0!"
    fi
    echo "      > Dm scale factor (100k): $DM_SCALE_FACTOR"

    # -------------------------
    # 8) Extract Alignment Rate
    # -------------------------
    ALIGN_RATE=$(grep "overall alignment rate" "$LOG_human" | awk '{print $1}')
    [ -z "$ALIGN_RATE" ] && ALIGN_RATE="NA"

    # -------------------------
    # 9) Write to Summary
    # -------------------------
    echo -e "${SAMPLE}\t${ALIGN_RATE}\t${human_READS}\t${DM_SPIKE_COUNT}\t${DM_SCALE_FACTOR}" >> "$SUMMARY_FILE"

    # Cleanup trimmed reads
    rm "$TRIMMED_R1" "$TRIMMED_R2"

    echo "  Done: $SAMPLE ($COUNT/$TOTAL_SAMPLES)"
    echo
done

echo "========================================"
echo "All $TOTAL_SAMPLES samples processed."
echo "Summary file: $SUMMARY_FILE"
echo "========================================"