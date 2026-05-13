#!/usr/bin/env bash
set -euo pipefail

# Nacev Lab TE-expression template: TElocal for mouse mm10.
#
# This script is currently mouse/mm10 only.
# Human/hg38 TE-expression scripts will be added later after annotation choices
# and expected outputs are standardized.

STAR_OUTPUT_DIR="/path/to/output/star_mm10"
OUTPUT_DIR="/path/to/output/telocal_mm10"
GENE_GTF="/path/to/annotation.gtf"
TE_ANNOTATION="/path/to/te_annotation.gtf"
BAM_SUFFIX="_Aligned.sortedByCoord.out.bam"

mkdir -p "$OUTPUT_DIR"

command -v TElocal >/dev/null 2>&1 || { echo "[FATAL] TElocal not found in PATH"; exit 1; }

if [[ ! -d "$STAR_OUTPUT_DIR" ]]; then
    echo "[FATAL] STAR_OUTPUT_DIR does not exist: $STAR_OUTPUT_DIR"
    exit 1
fi

if [[ ! -f "$GENE_GTF" ]]; then
    echo "[FATAL] GENE_GTF does not exist: $GENE_GTF"
    exit 1
fi

if [[ ! -f "$TE_ANNOTATION" ]]; then
    echo "[FATAL] TE_ANNOTATION does not exist: $TE_ANNOTATION"
    exit 1
fi

echo "Mouse mm10 TElocal"
echo "STAR_OUTPUT_DIR: $STAR_OUTPUT_DIR"
echo "OUTPUT_DIR:      $OUTPUT_DIR"
echo "GENE_GTF:        $GENE_GTF"
echo "TE_ANNOTATION:   $TE_ANNOTATION"
echo

found_any=false

for bam_file in "$STAR_OUTPUT_DIR"/*/*"$BAM_SUFFIX"; do
    [[ -e "$bam_file" ]] || continue
    found_any=true

    bam_name=$(basename "$bam_file")
    sample_id="${bam_name%$BAM_SUFFIX}"
    project_prefix="$OUTPUT_DIR/$sample_id"

    echo "========================================"
    echo "Processing sample: $sample_id"
    echo "Input BAM: $bam_file"
    echo "Output prefix: $project_prefix"

    TElocal \
        --sortByPos \
        -b "$bam_file" \
        --GTF "$GENE_GTF" \
        --TE "$TE_ANNOTATION" \
        --project "$project_prefix"

    expected_count_table="${project_prefix}.cntTable"
    if [[ -f "$expected_count_table" ]]; then
        echo "Finished $sample_id: $expected_count_table"
    else
        echo "[WARNING] TElocal finished but expected count table was not found for $sample_id"
    fi
done

if [[ "$found_any" == false ]]; then
    echo "[FATAL] No BAM files found using pattern: $STAR_OUTPUT_DIR/*/*$BAM_SUFFIX"
    exit 1
fi

echo "All available mouse mm10 TElocal samples processed."
