# Cut&Run / CUT&Tag Workflow Overview

The workflow is split into three scripts so each stage can be reviewed and rerun independently.

## 1. Alignment And Filtering

Script: `scripts/01_align_filter.sh`

Main steps preserved from `align2.sh`:

1. Read samples from the sample sheet.
2. Trim the first bases and common adapter/polyA/polyG sequence with `cutadapt`.
3. Align paired reads to the primary genome with `bowtie2`.
4. Convert SAM to sorted BAM with `samtools`.
5. Remove duplicates with Picard `MarkDuplicates`.
6. Filter to properly paired reads at the configured MAPQ threshold.
7. Optionally keep only configured canonical chromosomes.
8. Optionally remove blacklist regions with `bedtools intersect -v`.
9. Align trimmed reads to a spike-in genome when enabled.
10. Write an alignment and spike-in summary table.

## 2. Track Generation

Script: `scripts/02_generate_tracks.sh`

Main steps preserved from `normalize.sh` and `no_normalize.sh`:

| Track type | Logic |
| --- | --- |
| Spike-in normalized | Within each `normalization_group`, use the smallest positive spike-in count as the reference and scale each sample by `min_spikein / sample_spikein`. Generate bedGraph with `bedtools genomecov -scale`, then convert to BigWig. |
| CPM normalized | Use `bamCoverage --normalizeUsing CPM`, then convert BigWig to bedGraph for SEACR-compatible outputs. |

The old scripts duplicated pre-flight checks and output setup. The standardized script handles both normalization modes in one place.

## 3. Peak Calling And FRiP

Script: `scripts/03_call_peaks.sh`

Main steps preserved from `peak_call.sh`:

1. Use the sample sheet to map each target sample to its `control_sample_id`.
2. Run SEACR stringent and relaxed peak calling on bedGraph tracks when enabled.
3. Run MACS3 in narrow or broad mode based on `peak_type`.
4. Count peaks and write summary tables.
5. Calculate FRiP using filtered BAMs and called peaks.

## Major Generalizations From The Original Scripts

| Original assumption | Standardized behavior |
| --- | --- |
| Samples discovered from one raw FASTQ directory | Samples come from `sample_sheet.csv` |
| Sample names parsed to find condition and target | `condition`, `target`, and `peak_type` are explicit columns |
| WT/KO IgG controls auto-detected from sample names | Controls are declared with `control_sample_id` |
| Human hg38 and Drosophila paths hardcoded | Reference paths are in `config.yaml` |
| One lab/user output path hardcoded | Outputs are under `project.output_dir` |
| Separate normalized and non-normalized scripts | One track script handles spike-in and CPM modes |
| Fixed mark list determines MACS3 mode | `peak_type` is project metadata |
| SLURM email and partition hardcoded | Cluster submission is left to project-specific wrappers |
