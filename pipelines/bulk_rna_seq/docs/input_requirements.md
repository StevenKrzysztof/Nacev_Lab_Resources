# Bulk RNA-seq Input Requirements

## Gene-Level Salmon RNA-seq

| Input | Required | Notes |
| --- | --- | --- |
| Paired FASTQ files | Yes | Use approved non-private sample names |
| Sample metadata table | Yes | Include sample ID, condition, replicate, and relevant covariates |
| Salmon transcriptome index | Yes | Must match species and genome build |
| GTF annotation | Yes | Used to build `tx2gene` for tximport |
| Contrast table | Recommended | Makes comparison direction explicit |
| Reference genome build note | Yes | Use hg38 for human and mm10 for mouse standards |

## TE-Expression RNA-seq

| Input | Required | Notes |
| --- | --- | --- |
| Paired FASTQ files | Yes | Same FASTQs can be used for STAR alignment |
| STAR genome index | Yes | Current TE standard uses mouse mm10 |
| Gene GTF | Yes | Must match STAR index build |
| TE annotation | Yes | Must match genome build and TElocal expectations |
| TElocal `.cntTable` files | Downstream | Input to TE DESeq2 analysis |
| Sample metadata table | Yes | Used for DESeq2 design and plots |

## Recommended Sample Metadata Columns

| Column | Description |
| --- | --- |
| `sample_id` | Stable sample identifier |
| `condition` | Main biological group or treatment |
| `replicate` | Biological replicate |
| `fastq_r1` | R1 FASTQ path |
| `fastq_r2` | R2 FASTQ path |
| `species` | `human` or `mouse` |
| `genome_build` | `hg38` or `mm10` for current standards |
| `batch` | Optional batch/covariate if relevant |

## Pre-Run Checklist

- [ ] FASTQ file names do not contain private identifiers.
- [ ] Sample metadata match FASTQ files exactly.
- [ ] Human projects use hg38 unless explicitly justified.
- [ ] Mouse projects use mm10 unless explicitly justified.
- [ ] Salmon index, GTF, and annotation package match the same build.
- [ ] STAR index, GTF, and TE annotation match the same build for TE analysis.
- [ ] Planned contrasts are approved before running DESeq2.
