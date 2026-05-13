# Cut&Run / CUT&Tag Pipeline Template

This directory contains a standardized, reusable Cut&Run / CUT&Tag workflow for the Nacev Lab. It is based on the legacy scripts in `legacy_reference/cut_and_run_original_scripts/`, but has been reorganized to use a sample sheet, a configuration file, generic paths, and documented assumptions.

The goal is to preserve the core analysis logic while removing dataset-specific assumptions such as hardcoded directories, private user paths, fixed sample naming patterns, and project-specific WT/KO parsing.

## What This Template Does

| Stage | Script | Main outputs |
| --- | --- | --- |
| Alignment and filtering | `scripts/01_align_filter.sh` | Trimmed-read logs, filtered BAM files, alignment/spike-in summary |
| Track generation | `scripts/02_generate_tracks.sh` | Spike-in normalized and/or CPM-normalized bedGraph and BigWig tracks |
| Peak calling and FRiP | `scripts/03_call_peaks.sh` | SEACR peaks, MACS3 peaks, peak count summaries, FRiP summary |

## Quick Start

Copy the examples into a project workspace outside this repository.

```bash
cp pipelines/cut_and_run/examples/sample_sheet.example.csv /path/to/project/metadata/sample_sheet.csv
cp pipelines/cut_and_run/examples/config.example.yaml /path/to/project/config/cut_and_run.config.yaml
```

Edit the copied files so they point to project FASTQs, reference files, output directories, and analysis settings. Then run:

```bash
bash pipelines/cut_and_run/scripts/01_align_filter.sh /path/to/project/config/cut_and_run.config.yaml /path/to/project/metadata/sample_sheet.csv
bash pipelines/cut_and_run/scripts/02_generate_tracks.sh /path/to/project/config/cut_and_run.config.yaml /path/to/project/metadata/sample_sheet.csv
bash pipelines/cut_and_run/scripts/03_call_peaks.sh /path/to/project/config/cut_and_run.config.yaml /path/to/project/metadata/sample_sheet.csv
```

These scripts are written as transparent lab templates. They can be run directly, wrapped in SLURM scripts, or translated into a workflow manager later.

## Key Assumptions

- FASTQ files are paired-end.
- Sample metadata are provided in `sample_sheet.csv`; sample names are not inferred from file names.
- Final alignment files are deduplicated, MAPQ-filtered, properly paired, optionally limited to configured chromosomes, and optionally blacklist-filtered.
- Spike-in normalization uses spike-in mapped read counts within each `normalization_group`.
- CPM tracks are available as a non-spike-in alternative.
- SEACR uses bedGraph tracks and matched controls from the sample sheet.
- MACS3 uses filtered BAM files and uses `peak_type` from the sample sheet to choose narrow or broad mode.
- FRiP is calculated from called peaks and filtered BAM files.

## Legacy Script Audit

| Legacy script | Kept | Generalized or removed |
| --- | --- | --- |
| `align2.sh` | Cutadapt trimming, Bowtie2 local sensitive paired-end alignment, Picard duplicate removal, MAPQ/proper-pair filtering, blacklist removal, spike-in alignment, summary metrics | Hardcoded data/reference/output paths, email, SLURM settings, sample discovery from `*_R1_001.fastq.gz`, human-only labels, fixed chromosome list |
| `normalize.sh` | Spike-in scale-factor logic, bedtools genome coverage, bedGraph to BigWig conversion | Target extraction from SYO-1 sample names, old/new antibody batch assumptions, hardcoded directories |
| `no_normalize.sh` | CPM track generation with deepTools `bamCoverage`, BigWig to bedGraph conversion | Duplicated BAM checks and output setup now shared with spike-in track generation |
| `peak_call.sh` | SEACR stringent/relaxed calls, MACS3 narrow/broad calls, FRiP calculation and summaries | WT/KO IgG auto-detection, SYO-1 mark parsing, fixed mark lists, hardcoded SEACR and output paths |

## Documentation

- [Input requirements](docs/input_requirements.md)
- [Workflow overview](docs/workflow_overview.md)
- [Output description](docs/output_description.md)
- [Troubleshooting](docs/troubleshooting.md)

## Data Policy

Do not commit raw sequencing data, private sample names, patient information, unpublished project results, credentials, or hardcoded project-specific paths to this repository. Use placeholders such as `/path/to/project`, `/path/to/reference`, `sample_id`, `condition`, `replicate`, `fastq_r1`, and `fastq_r2` in reusable templates.
