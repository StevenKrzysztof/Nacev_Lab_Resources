# Bulk RNA-seq Troubleshooting

## Common Issues

| Problem | Likely cause | First checks |
| --- | --- | --- |
| Salmon cannot find FASTQs | Sample sheet path typo | Check `fastq_r1` and `fastq_r2` paths |
| Low Salmon mapping rate | Wrong index, contamination, poor read quality, or library mismatch | Review FastQC, trimming logs, and Salmon logs |
| `tximport` cannot find `quant.sf` | Output directory naming mismatch | Confirm each sample has a Salmon folder with `quant.sf` |
| Gene IDs do not map | GTF does not match Salmon index or ID format | Check genome build and `ignoreAfterBar` setting |
| DESeq2 design fails | Metadata column missing or has one level | Check sample metadata and factor levels |
| PCA shows unexpected clustering | Batch effect, sample swap, or biology | Review metadata, QC reports, and library metrics |
| Enrichment returns few terms | Wrong gene ID type or small gene list | Confirm identifier conversion and background universe |
| STAR BAM missing for TE analysis | STAR failed or output prefix changed | Check STAR logs and output directory |
| TElocal gives missing annotation errors | TE annotation path or build mismatch | Confirm mm10 gene GTF and mm10 TE annotation |

## Debugging Checklist

- [ ] The project uses the intended species and genome build.
- [ ] FASTQ pairs are correctly matched.
- [ ] Salmon index and GTF are from the same build.
- [ ] STAR index, GTF, and TE annotation are from the same build.
- [ ] Sample names in metadata match output folder names.
- [ ] Contrasts are written in the intended direction.
- [ ] R package organism database matches species.
- [ ] No private sample details are included when sharing logs or screenshots.

## When Asking For Help

Include:

- The exact command or R section that failed.
- The relevant log file.
- A de-identified sample metadata table.
- The genome build and annotation version.
- The location pattern for outputs, using placeholders if needed.
