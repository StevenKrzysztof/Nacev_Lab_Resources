# Cut&Run / CUT&Tag Output Description

Output paths are controlled by `project.output_dir` in `config.yaml`.

## Directory Layout

```text
/path/to/project/results/cut_and_run/
  alignment/
  tracks/
    spikein/
      bedgraph/
      bigwig/
    cpm/
      bedgraph/
      bigwig/
  peaks/
    seacr/
      stringent/
      relaxed/
    macs3/
      narrow/
      broad/
  summaries/
```

## Alignment Outputs

| Output | Description |
| --- | --- |
| `alignment/sample_id/sample_id_R1_trimmed.fq.gz` | Trimmed R1 reads, retained only if cleanup is disabled |
| `alignment/sample_id/sample_id_R2_trimmed.fq.gz` | Trimmed R2 reads, retained only if cleanup is disabled |
| `alignment/sample_id/cutadapt.log` | Trimming log |
| `alignment/sample_id/sample_id.bowtie2.primary.log` | Primary genome alignment log |
| `alignment/sample_id/sample_id.dedup.metrics.txt` | Picard duplicate metrics |
| `alignment/sample_id/sample_id.final.bam` | Filtered BAM used downstream |
| `alignment/sample_id/sample_id.final.bam.bai` | BAM index |
| `summaries/alignment_and_spikein_summary.tsv` | Per-sample alignment and spike-in counts |

## Track Outputs

| Output | Description |
| --- | --- |
| `tracks/spikein/bedgraph/sample_id.spikein_normalized.bedgraph` | Spike-in normalized coverage for SEACR |
| `tracks/spikein/bigwig/sample_id.spikein_normalized.bw` | Spike-in normalized browser track |
| `tracks/cpm/bigwig/sample_id.cpm.bw` | CPM-normalized browser track |
| `tracks/cpm/bedgraph/sample_id.cpm.bedgraph` | CPM-normalized bedGraph for optional SEACR use |
| `summaries/spikein_normalization_summary.tsv` | Spike-in scale factors by normalization group |
| `summaries/cpm_track_summary.tsv` | CPM track read-count summary |

## Peak Outputs

| Output | Description |
| --- | --- |
| `peaks/seacr/stringent/sample_id.stringent.bed` | Stringent SEACR peaks |
| `peaks/seacr/relaxed/sample_id.relaxed.bed` | Relaxed SEACR peaks |
| `peaks/macs3/narrow/sample_id_peaks.narrowPeak` | MACS3 narrow peaks |
| `peaks/macs3/broad/sample_id_peaks.broadPeak` | MACS3 broad peaks |
| `summaries/seacr_peak_summary.tsv` | SEACR peak counts |
| `summaries/macs3_peak_summary.tsv` | MACS3 peak counts |
| `summaries/frip_summary.tsv` | Reads-in-peaks and FRiP metrics |

## Interpretation Notes

- BigWig tracks are for visual inspection and comparison in a genome browser.
- SEACR and MACS3 peak sets may differ because they use different models and input formats.
- FRiP values should be interpreted with target biology, signal breadth, sequencing depth, and control quality in mind.
- Broad histone marks often require different expectations than narrow transcription factor or active enhancer marks.
