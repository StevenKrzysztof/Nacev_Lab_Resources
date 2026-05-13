# Gene-Expression Scripts

These scripts are transparent templates for regular gene-level bulk RNA-seq.

The Nacev Lab standard is:

```text
paired FASTQ files -> Salmon quantification -> tximport / DESeq2 R Markdown
```

Use Salmon for routine gene-level quantification. Do not use STAR counts as the default gene-expression standard.

## Scripts

| Script | Standard reference | Purpose |
| --- | --- | --- |
| `01_salmon_quant_human_hg38.sh` | Human hg38 | Run Salmon on paired-end FASTQs |
| `01_salmon_quant_mouse_mm10.sh` | Mouse mm10 | Run Salmon on paired-end FASTQs |
| `02_collect_salmon_quant.sh` | Any Salmon output | Check `quant.sf` files and create downstream metadata helpers |

## Before Running

Edit the variables near the top of each script:

- `FASTQ_DIR`
- `OUTPUT_DIR`
- `SALMON_INDEX`
- `THREADS`
- `LIBRARY_TYPE`
- `READ1_SUFFIX`
- `READ2_SUFFIX`

The example FASTQ pattern is:

```text
sample1_1.fastq.gz
sample1_2.fastq.gz
sample2_1.fastq.gz
sample2_2.fastq.gz
```

## After Salmon

Run `02_collect_salmon_quant.sh`, edit the generated metadata template, then run:

```text
pipelines/bulk_rna_seq/rmarkdown/bulk_rna_seq_salmon_deseq2_standard.Rmd
```

Do not commit real FASTQs, Salmon output folders, `quant.sf` files, or private sample metadata to this repository.
