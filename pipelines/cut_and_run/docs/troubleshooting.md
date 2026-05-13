# Cut&Run / CUT&Tag Troubleshooting

## Common Problems

| Problem | Likely cause | First checks |
| --- | --- | --- |
| Script exits before processing samples | Missing config, sample sheet, or `yq` | Confirm paths and run `yq --version` |
| Missing R1 or R2 error | FASTQ path typo or inaccessible storage | Check `fastq_r1` and `fastq_r2` in the sample sheet |
| Low primary alignment rate | Wrong genome build, contamination, poor quality, or trimming issue | Review `sample_id.bowtie2.primary.log` and `cutadapt.log` |
| No spike-in scale factor | Spike-in disabled, missing spike-in index, or zero spike-in reads | Check `include_spikein`, `spikein.enabled`, and spike-in Bowtie2 logs |
| Empty bedGraph | Empty or invalid BAM, chromosome mismatch, or over-filtering | Run `samtools quickcheck` and inspect read counts |
| BigWig conversion fails | Chromosome names differ between bedGraph and chrom sizes | Compare BAM contigs with `reference.chromosome_sizes` |
| SEACR cannot find control track | Missing `control_sample_id` or track source mismatch | Confirm control sample and `peak_calling.seacr_track_source` |
| MACS3 output is missing | Missing BAM, wrong `peak_type`, or MACS3 failure | Read the per-sample MACS3 log |
| FRiP is very low | Weak enrichment, poor control, broad diffuse signal, or wrong peak set | Review tracks manually and compare SEACR/MACS3 calls |

## Debugging Checklist

- [ ] Confirm the sample appears exactly once in the sample sheet.
- [ ] Confirm all input paths are absolute project paths or valid relative paths from where the script is run.
- [ ] Confirm no sample ID contains spaces or commas.
- [ ] Confirm `control_sample_id` matches another `sample_id` exactly.
- [ ] Confirm `peak_type` is `narrow` or `broad`.
- [ ] Confirm chromosome naming is consistent, for example `chr1` versus `1`.
- [ ] Confirm the active software environment contains all required tools.

## When Asking For Help

Include:

- The command that was run.
- The copied project config with private paths removed.
- The copied sample sheet with private sample details removed.
- The relevant log file from `alignment/`, `tracks/`, or `peaks/`.
- The affected sample ID and workflow step.
