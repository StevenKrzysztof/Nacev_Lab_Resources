# TE-Expression Workflow

## Current Status

The current TE-expression section provides the mouse/mm10 standard. A human/hg38 TE-expression version will be added later.

TE-expression analysis is different from regular gene-level RNA-seq because it requires genome-aligned reads and TE annotations. For this reason, STAR and TElocal are used for TE workflows even though Salmon remains the standard for regular gene-level RNA-seq.

## Reference Files Used

| Reference file | Role |
| --- | --- |
| `STAR_align_mouse.sh` | Mouse STAR alignment plus TElocal example |
| `align_TE_batch1.sh` | Human STAR alignment reference for future hg38 TE standard |
| `TElocal_batch1.sh` | TElocal command reference |
| `TE_tumor_group.Rmd` | TE count import, filtering, DESeq2, plots, and TE summaries |

## Mouse/mm10 TE Workflow

| Step | Purpose | Inputs | Outputs |
| --- | --- | --- | --- |
| FASTQ QC and trimming | Prepare reads for alignment | Paired FASTQs | QC reports, trimmed FASTQs |
| STAR alignment | Create genome-aligned BAM files | FASTQs, mm10 STAR index | Sorted BAM files and STAR logs |
| TElocal | Count reads assigned to TEs | STAR BAMs, mm10 gene GTF, mm10 TE annotation | `.cntTable` files |
| TE count import | Build TE count matrix | TElocal `.cntTable` files | TE-by-sample count matrix |
| DESeq2 | Test TE-expression contrasts | TE count matrix, metadata | Differential TE tables |
| TE summaries | Interpret TE classes and patterns | DESeq2 results | TE class plots, PCA, heatmaps |

## Executable Templates

| Script | Use |
| --- | --- |
| `scripts/te_expression/01_star_align_for_telocal_mouse_mm10.sh` | Align paired-end FASTQs to mm10 with STAR and produce sorted BAM files |
| `scripts/te_expression/02_telocal_mouse_mm10.sh` | Run TElocal on STAR BAM files with mm10-compatible gene and TE annotations |

STAR is used in this workflow because TElocal requires BAM input. This is different from routine gene-level RNA-seq, where Salmon is the standard.

## Script Inputs And Outputs

| Step | Inputs | Outputs |
| --- | --- | --- |
| STAR alignment | Paired FASTQs, mm10 STAR index | Sorted coordinate BAM files and STAR logs |
| TElocal | STAR BAM files, mm10 gene GTF, mm10 TE annotation | Per-sample `.cntTable` files |
| Downstream TE analysis | `.cntTable` files and sample metadata | TE count matrix, DESeq2 results, TE QC plots |

## Required Reference Consistency

All TE inputs must use the same genome build:

- STAR index
- Gene GTF
- TE annotation
- BAM chromosome names
- Downstream interpretation files

For the current mouse standard, use mm10 consistently. Do not combine mm10 BAM files with mm39 or human TE annotations.

## What To Generalize From Previous Projects

- Replace hardcoded sample lists with a sample sheet.
- Replace project-specific STAR output paths with configurable paths.
- Replace project-specific GTF and TE annotation paths with reference settings.
- Keep the TElocal command structure: `TElocal --sortByPos -b sample.bam --GTF genes.gtf --TE te_annotation.locInd --project output_prefix`.
- Keep TE row filtering logic that identifies TE IDs from TElocal output.
- Keep DESeq2, PCA, heatmap, and TE class summary sections, but generalize contrasts and sample groups.

## Example TElocal Command

```bash
TElocal \
  --sortByPos \
  -b star/sample1_control_rep1.Aligned.sortedByCoord.out.bam \
  --GTF /path/to/reference/mm10.genes.gtf \
  --TE /path/to/reference/mm10_rmsk_TE.gtf.locInd \
  --project te_counts/sample1_control_rep1
```

## Human/hg38 Note

The previous human-oriented TE files are useful references, but they are not yet a finalized lab standard. A future hg38 TE standard should define:

- hg38 STAR index
- hg38-compatible gene GTF
- hg38 TE annotation for TElocal
- sample sheet structure
- expected output directories
- validated downstream R import steps
