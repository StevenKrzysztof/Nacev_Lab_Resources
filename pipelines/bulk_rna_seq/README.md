# Bulk RNA-seq Analysis Template

This directory contains the Nacev Lab template for bulk RNA-seq analysis. Bulk RNA-seq is used to quantify gene expression across experimental conditions and can support differential expression, sample quality assessment, and pathway-level interpretation in cancer biology studies.

Use this directory as a reusable starting point. Project-specific sample sheets, configs, logs, count matrices, and result tables should live in a project workspace such as `/path/to/project`, not in this repository.

## Template Files

| File | Purpose |
| --- | --- |
| `examples/sample_sheet.example.csv` | Minimal metadata table for RNA-seq libraries |
| `examples/config.example.yaml` | Generic project, reference, analysis, and resource settings |

## Planned Workflow

| Step | Purpose |
| --- | --- |
| Input validation | Confirm sample metadata, FASTQ paths, and config settings |
| FASTQ quality control | Review read quality, adapter content, and sequencing issues |
| Adapter trimming | Remove adapter sequence and low-quality bases when needed |
| Quantification or alignment | Estimate transcript abundance or align reads to the genome |
| Gene-level summarization | Produce a gene-by-sample count matrix |
| Sample QC | Review library size, detected genes, PCA, and sample distances |
| Differential expression | Test approved contrasts using the documented design formula |
| Visualization | Generate PCA plots, heatmaps, volcano plots, and expression summaries |
| Enrichment analysis | Interpret ranked or significant genes using pathway and gene set methods |

## Input Philosophy

This pipeline should use a sample sheet and configuration file instead of hardcoded sample names, private project paths, or dataset-specific folder structures.

## Minimum Metadata Expectations

- `sample_id` should be stable, generic, and free of private identifiers.
- `condition` should describe the experimental group.
- `replicate` should identify the biological replicate.
- `fastq_r1` and `fastq_r2` should point to FASTQ files in the project workspace.
- Additional covariates such as `batch`, `timepoint`, or `treatment` should be added when relevant to the experimental design.

## Pre-Run Checklist

- [ ] FASTQ files are available and match the sample sheet.
- [ ] Biological replicates are correctly labeled.
- [ ] Genome build, annotation version, and quantification reference are documented.
- [ ] Planned contrasts and covariates are reviewed before results are generated.
- [ ] No raw data, private information, or project-specific absolute paths are committed here.
