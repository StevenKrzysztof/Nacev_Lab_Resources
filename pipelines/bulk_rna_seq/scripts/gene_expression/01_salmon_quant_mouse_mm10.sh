#!/usr/bin/env bash
set -euo pipefail

# Nacev Lab bulk RNA-seq template: mouse gene-level quantification with Salmon.
# Standard reference: mouse mm10.
#
# Edit the variables below before running this script on a real project.
# Example expected FASTQs:
#   /path/to/raw_fastq/sample1_1.fastq.gz
#   /path/to/raw_fastq/sample1_2.fastq.gz

FASTQ_DIR="/path/to/raw_fastq"
OUTPUT_DIR="/path/to/output/salmon_mm10"
SALMON_INDEX="/path/to/salmon_index_mm10"
THREADS=8
LIBRARY_TYPE="A"
READ1_SUFFIX="_1.fastq.gz"
READ2_SUFFIX="_2.fastq.gz"

mkdir -p "$OUTPUT_DIR"

command -v salmon >/dev/null 2>&1 || { echo "[FATAL] salmon not found in PATH"; exit 1; }

if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "[FATAL] FASTQ_DIR does not exist: $FASTQ_DIR"
    exit 1
fi

if [[ ! -d "$SALMON_INDEX" ]]; then
    echo "[FATAL] SALMON_INDEX does not exist: $SALMON_INDEX"
    exit 1
fi

echo "Mouse mm10 Salmon quantification"
echo "FASTQ_DIR:    $FASTQ_DIR"
echo "OUTPUT_DIR:   $OUTPUT_DIR"
echo "SALMON_INDEX: $SALMON_INDEX"
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

    echo "========================================"
    echo "Processing sample: $sample_id"
    echo "R1: $r1"
    echo "R2: $r2"
    echo "Output: $sample_out"

    salmon quant \
        -i "$SALMON_INDEX" \
        -l "$LIBRARY_TYPE" \
        -1 "$r1" \
        -2 "$r2" \
        -p "$THREADS" \
        --validateMappings \
        -o "$sample_out"

    if [[ -f "$sample_out/quant.sf" ]]; then
        echo "Finished $sample_id: $sample_out/quant.sf"
    else
        echo "[WARNING] Salmon finished but quant.sf was not found for $sample_id"
    fi
done

if [[ "$found_any" == false ]]; then
    echo "[FATAL] No R1 FASTQ files found using pattern: $FASTQ_DIR/*$READ1_SUFFIX"
    exit 1
fi

echo "All available mouse mm10 Salmon samples processed."
