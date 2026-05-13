# Cut&Run / CUT&Tag Input Requirements

This workflow uses two user-edited files:

- `sample_sheet.csv` for sample-level metadata and FASTQ paths.
- `config.yaml` for project paths, reference files, software paths, and analysis parameters.

Do not edit the reusable examples in this repository for a real project. Copy them into `/path/to/project` and edit the copies.

## Required Sample Sheet Columns

| Column | Required | Description |
| --- | --- | --- |
| `sample_id` | Yes | Stable, non-private sample identifier used in output file names |
| `condition` | Yes | Experimental group, treatment, genotype, or other comparison label |
| `target` | Yes | Antibody target, chromatin mark, protein, or control target |
| `replicate` | Yes | Biological replicate label |
| `fastq_r1` | Yes | Path to paired-end R1 FASTQ |
| `fastq_r2` | Yes | Path to paired-end R2 FASTQ |
| `control_sample_id` | For peak calling | Matching control sample, often IgG or input-like control |
| `normalization_group` | For spike-in tracks | Group of samples normalized together using the minimum spike-in count |
| `peak_type` | For MACS3 | `narrow` or `broad` |
| `include_spikein` | For spike-in tracks | `true` if spike-in alignment should be used for this sample |

## Required Reference Files

| Reference | Config key | Used by |
| --- | --- | --- |
| Primary genome Bowtie2 index prefix | `reference.bowtie2_index` | Primary alignment |
| Spike-in Bowtie2 index prefix | `reference.spikein_bowtie2_index` | Spike-in alignment and normalization |
| Chromosome sizes file | `reference.chromosome_sizes` | bedGraph to BigWig conversion |
| Blacklist BED file | `reference.blacklist_bed` | Optional removal of problematic regions |
| Canonical chromosome list | `reference.canonical_chromosomes` | Optional chromosome filtering |
| SEACR script path | `software.seacr_script` | SEACR peak calling |

## Peak-Calling Configuration

| Setting | Example | Notes |
| --- | --- | --- |
| `peak_calling.run_seacr` | `true` | Enables SEACR bedGraph-based peak calling |
| `peak_calling.run_macs3` | `true` | Enables MACS3 BAM-based peak calling |
| `peak_calling.run_sicer2` | `false` | Enables SICER2 broad-domain calling; disabled by default |
| `peak_calling.sicer2_bin` | `SICER2` | Command name in the active environment; some installs may use `sicer` |
| `peak_calling.sicer2_genome` | `hg38` | Genome label recognized by the installed SICER2 version |
| `peak_calling.sicer2_effective_genome_fraction` | `0.74` | Effective genome fraction/size adjustment |
| `peak_calling.sicer2_window_size` | `200` | Genomic window used to scan enrichment |
| `peak_calling.sicer2_gap_size` | `600` | Distance allowed between enriched windows when merging broad domains |
| `peak_calling.sicer2_fragment_size` | `150` | Estimated fragment length |
| `peak_calling.sicer2_pvalue` | `0.01` | Documented p-value placeholder; exact flag depends on SICER2 version |
| `peak_calling.sicer2_fdr` | `0.05` | FDR threshold for enriched domains |

SICER2 command-line options vary across installations. Check `SICER2 --help` or the local executable help before running a project.

Genome examples:

- Human hg38 data: use an hg38 BAM, hg38 references, and a SICER2 genome setting recognized as hg38.
- Legacy human hg19 data: use hg19 consistently across BAMs and SICER2 genome settings.
- Mouse mm10 data: use mm10 consistently across BAMs and SICER2 genome settings.
- Mouse mm39 data: only use mm39 if the installed SICER2/reference setup supports it and all files match mm39.

## Required Software

The standardized scripts preserve the major tools used by the original implementation.

| Tool | Used for |
| --- | --- |
| `bash` | Running workflow scripts |
| `yq` | Reading values from `config.yaml` |
| `awk`, `sed`, `sort`, `grep` | Text processing and summaries |
| `cutadapt` | Adapter, first-base, polyA, and polyG trimming |
| `bowtie2` | Primary and spike-in alignment |
| `samtools` | BAM conversion, sorting, indexing, read counts, and quick checks |
| `picard` | Duplicate removal using `MarkDuplicates` |
| `bedtools` | Blacklist filtering, genome coverage, and reads-in-peaks |
| `bedGraphToBigWig` | BigWig creation from bedGraph |
| `bamCoverage` | CPM-normalized BigWig generation |
| `bigWigToBedGraph` | bedGraph creation from CPM BigWig |
| `macs3` | Narrow and broad peak calling |
| `SEACR` | Stringent and relaxed peak calling from bedGraph tracks |
| `SICER2` or `sicer` | Broad-domain peak calling from BAM files |

## Pre-Run Checklist

- [ ] FASTQ files exist and are readable.
- [ ] Sample identifiers do not contain patient identifiers or private information.
- [ ] Control samples are listed in the sample sheet before peak calling.
- [ ] Genome and spike-in indexes match the expected organism and build.
- [ ] Chromosome names in BAMs, chromosome sizes, blacklist, and peaks use the same naming convention.
- [ ] SICER2 genome and effective genome settings match the BAM genome build if SICER2 is enabled.
- [ ] `yq --version` works in the active software environment.
- [ ] Project-specific paths point to `/path/to/project` copies, not files inside this template repository.
