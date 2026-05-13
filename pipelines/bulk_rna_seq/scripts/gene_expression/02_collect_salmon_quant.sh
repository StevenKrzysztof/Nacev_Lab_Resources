#!/usr/bin/env bash
set -euo pipefail

# Collect Salmon quant.sf paths for downstream R Markdown analysis.
# This script does not run DESeq2. DESeq2 belongs in:
#   pipelines/bulk_rna_seq/rmarkdown/bulk_rna_seq_salmon_deseq2_standard.Rmd

SALMON_DIR="/path/to/output/salmon"
OUTPUT_DIR="/path/to/output/metadata"
QUANT_FILE_LIST="$OUTPUT_DIR/salmon_quant_files.tsv"
SAMPLE_METADATA_TEMPLATE="$OUTPUT_DIR/sample_metadata_template.csv"

mkdir -p "$OUTPUT_DIR"

if [[ ! -d "$SALMON_DIR" ]]; then
    echo "[FATAL] SALMON_DIR does not exist: $SALMON_DIR"
    exit 1
fi

echo -e "sample_id\tquant_sf" > "$QUANT_FILE_LIST"
echo "sample_id,condition,replicate,fastq_r1,fastq_r2" > "$SAMPLE_METADATA_TEMPLATE"

found_any=false

for sample_dir in "$SALMON_DIR"/*; do
    [[ -d "$sample_dir" ]] || continue

    sample_id=$(basename "$sample_dir")
    quant_file="$sample_dir/quant.sf"

    if [[ -f "$quant_file" ]]; then
        found_any=true
        echo -e "${sample_id}\t${quant_file}" >> "$QUANT_FILE_LIST"
        echo "${sample_id},condition_placeholder,replicate_placeholder,/path/to/raw_fastq/${sample_id}_1.fastq.gz,/path/to/raw_fastq/${sample_id}_2.fastq.gz" >> "$SAMPLE_METADATA_TEMPLATE"
    else
        echo "[WARNING] Missing quant.sf in: $sample_dir"
    fi
done

if [[ "$found_any" == false ]]; then
    echo "[FATAL] No quant.sf files found under: $SALMON_DIR"
    exit 1
fi

echo "Created Salmon quant file list:"
echo "  $QUANT_FILE_LIST"
echo
echo "Created editable sample metadata template:"
echo "  $SAMPLE_METADATA_TEMPLATE"
echo
echo "Next step: edit the metadata columns, then run the Salmon DESeq2 R Markdown template."
