#!/usr/bin/env bash
set -euo pipefail

# Nacev Lab TE-expression template: STAR alignment for TElocal.
# Current TE-expression standard: mouse mm10.
#
# STAR is used here because TElocal needs genome-aligned BAM input.
# For regular gene-level RNA-seq, use Salmon instead.

FASTQ_DIR="/path/to/raw_fastq"
OUTPUT_DIR="/path/to/output/star_mm10"
STAR_INDEX="/path/to/star_index_mm10"
THREADS=8
READ1_SUFFIX="_1.fastq.gz"
READ2_SUFFIX="_2.fastq.gz"
READ_FILES_COMMAND="zcat"

mkdir -p "$OUTPUT_DIR"

command -v STAR >/dev/null 2>&1 || { echo "[FATAL] STAR not found in PATH"; exit 1; }

if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "[FATAL] FASTQ_DIR does not exist: $FASTQ_DIR"
    exit 1
fi

if [[ ! -d "$STAR_INDEX" ]]; then
    echo "[FATAL] STAR_INDEX does not exist: $STAR_INDEX"
    exit 1
fi

echo "Mouse mm10 STAR alignment for TElocal"
echo "FASTQ_DIR:  $FASTQ_DIR"
echo "OUTPUT_DIR: $OUTPUT_DIR"
echo "STAR_INDEX: $STAR_INDEX"
echo

found_any=false

for r1 in "$FASTQ_DIR"/*"$READ1_SUFFIX"; do
    [[ -e "$r1" ]] || continue
    found_any=true

    filename=$(basename "$r1")
    sample_id="${filename%$READ1_SUFFIX}"
    r2="$FASTQ_DIR/${sample_id}${READ2_SUFFIX}"

    if [[ ! -f "$r2" ]]; then
        echo "[WARNING] Missing R2 for $sample_id: $r2"
        continue
    fi

    sample_out="$OUTPUT_DIR/$sample_id"
    mkdir -p "$sample_out"
    out_prefix="$sample_out/${sample_id}_"

    echo "========================================"
    echo "Processing sample: $sample_id"
    echo "R1: $r1"
    echo "R2: $r2"
    echo "Output prefix: $out_prefix"

    STAR \
        --runThreadN "$THREADS" \
        --genomeDir "$STAR_INDEX" \
        --readFilesIn "$r1" "$r2" \
        --readFilesCommand "$READ_FILES_COMMAND" \
        --outFileNamePrefix "$out_prefix" \
        --outSAMtype BAM SortedByCoordinate \
        --outFilterMultimapNmax 100

    bam_file="${out_prefix}Aligned.sortedByCoord.out.bam"
    if [[ -f "$bam_file" ]]; then
        echo "Finished $sample_id: $bam_file"
    else
        echo "[WARNING] STAR finished but sorted BAM was not found for $sample_id"
    fi
done

if [[ "$found_any" == false ]]; then
    echo "[FATAL] No R1 FASTQ files found using pattern: $FASTQ_DIR/*$READ1_SUFFIX"
    exit 1
fi

echo "All available mouse mm10 STAR samples processed."
