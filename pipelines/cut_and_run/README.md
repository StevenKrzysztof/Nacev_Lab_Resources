# Cut&Run / CUT&Tag Analysis Template

This directory contains the Nacev Lab template for Cut&Run and CUT&Tag analysis. These assays profile protein-DNA or chromatin-associated signal and are commonly used to study transcriptional regulation, enhancer activity, chromatin state, and epigenetic changes in cancer biology models.

Use this directory as a reusable starting point. Project-specific sample sheets, configs, logs, and outputs should live in a project workspace such as `/path/to/project`, not in this repository.

## Template Files

| File | Purpose |
| --- | --- |
| `examples/sample_sheet.example.csv` | Minimal metadata table for paired-end Cut&Run/CUT&Tag libraries |
| `examples/config.example.yaml` | Generic project, reference, analysis, and resource settings |

## Planned Workflow

| Step | Purpose |
| --- | --- |
| Input validation | Confirm sample sheet columns, FASTQ paths, controls, and reference settings |
| FASTQ quality control | Review read quality, adapter content, and sequencing issues |
| Adapter trimming | Remove adapter sequence and low-quality bases when needed |
| Alignment | Map paired-end reads to the selected reference genome |
| BAM filtering and QC | Remove low-quality alignments and summarize mapping metrics |
| Fragment analysis | Check fragment size distributions expected for the assay |
| Signal track generation | Create normalized tracks for genome browser review |
| Peak calling | Identify enriched regions relative to controls when available |
| Summary reporting | Capture QC, key settings, and output locations |

## Input Philosophy

This pipeline should use a sample sheet and configuration file instead of hardcoded sample names, private project paths, or dataset-specific folder structures.

## Minimum Metadata Expectations

- `sample_id` should be stable, generic, and free of private identifiers.
- `condition` should describe the experimental group.
- `target` should describe the antibody target or control.
- `replicate` should identify the biological replicate.
- `fastq_r1` and `fastq_r2` should point to paired FASTQ files in the project workspace.
- `control_sample_id` should identify the matched control sample when one is available.

## Pre-Run Checklist

- [ ] FASTQ files are available and read pairs match the sample sheet.
- [ ] Reference genome and chromosome size files match the organism and genome build.
- [ ] Control samples are assigned for target samples when appropriate.
- [ ] Adapter trimming and duplicate handling choices are documented.
- [ ] No raw data, private information, or project-specific absolute paths are committed here.
