# Gene-Level Bulk RNA-seq Workflow

## Standard

The Nacev Lab standard for regular gene-level bulk RNA-seq is Salmon quantification followed by `tximport` and DESeq2.

Salmon is preferred because it is fast, reproducible, and designed for transcript quantification from RNA-seq reads. Gene-level analysis is performed by importing transcript-level Salmon results into R with `tximport`, using a transcript-to-gene mapping derived from a matching GTF file.

## Reference Files Used

| Reference file | Role |
| --- | --- |
| `salmon_alignment.sh` | Mouse Salmon quantification example |
| `align_batch1.sh` | Human Salmon quantification example |
| `tumor_group.Rmd` | Salmon `quant.sf` import with `tximport` |
| `Andrew_tumor_STAR_version.Rmd` | Downstream DESeq2/QC/enrichment style after a count matrix is loaded |

`Andrew_tumor_STAR_version.Rmd` should not define the standard quantification method for routine gene-level RNA-seq. It is useful for the analysis structure after count import.

## Workflow Steps

| Step | Purpose | Main inputs | Main outputs |
| --- | --- | --- | --- |
| FASTQ organization | Make sample paths reviewable | Paired FASTQ files, sample metadata | Organized project directory |
| FASTQ QC | Detect sequencing or library issues | FASTQs | FastQC and MultiQC reports |
| Trimming | Remove adapters or low-quality bases | FASTQs | Trimmed FASTQs and logs |
| Salmon quantification | Estimate transcript abundance | FASTQs, Salmon index | `quant.sf` for each sample |
| tximport | Summarize transcript quantification to genes | `quant.sf`, GTF-derived `tx2gene` | Gene-level counts |
| DESeq2 | Test planned contrasts | Count matrix, metadata | Differential expression tables |
| QC visualization | Review samples and expression structure | Transformed counts, metadata | PCA and heatmaps |
| Enrichment | Interpret gene lists and rankings | DE results, gene sets | GO/KEGG/Hallmark/GSEA outputs |

## Executable Templates

| Script | Use |
| --- | --- |
| `scripts/gene_expression/01_salmon_quant_human_hg38.sh` | Human hg38 Salmon quantification |
| `scripts/gene_expression/01_salmon_quant_mouse_mm10.sh` | Mouse mm10 Salmon quantification |
| `scripts/gene_expression/02_collect_salmon_quant.sh` | Check `quant.sf` files and create metadata helpers |
| `rmarkdown/bulk_rna_seq_salmon_deseq2_standard.Rmd` | Import Salmon output with tximport and run DESeq2 downstream analysis |

The shell scripts stop after Salmon quantification and collection. DESeq2, plots, and enrichment belong in the R Markdown template so the statistical analysis remains inspectable and reproducible.

## Script Inputs And Outputs

| Step | Inputs | Outputs |
| --- | --- | --- |
| Salmon quantification | Paired FASTQs, Salmon index, read suffix pattern | One output folder per sample with `quant.sf` |
| Salmon collection | Salmon output folder | `salmon_quant_files.tsv` and editable sample metadata template |
| R Markdown analysis | `quant.sf` files, metadata, GTF | DESeq2 tables, QC plots, heatmaps, volcano plots, enrichment outputs |

## What To Generalize From Previous Projects

- Replace hardcoded sample vectors with a sample metadata table.
- Replace hardcoded directories with project-level paths.
- Replace project-specific variables such as genotype/treatment names with generic design columns.
- Choose `org.Hs.eg.db` or `org.Mm.eg.db` based on species.
- Keep contrast direction explicit, for example `treated_vs_control`.
- Keep reference build consistent across Salmon index, GTF, and annotation package.

## Recommended R Analysis Sections

1. Load libraries.
2. Define project paths and output directory.
3. Read sample metadata.
4. Create `tx2gene` from the matching GTF.
5. Import Salmon results with `tximport`.
6. Build a DESeq2 object with the approved design.
7. Filter low-count genes.
8. Run DESeq2.
9. Export planned contrasts.
10. Generate PCA and heatmaps.
11. Run GO, KEGG, Hallmark, or GSEA-style enrichment.
12. Save session information.

## Minimal Salmon Import Pattern

```r
library(tximport)
library(rtracklayer)
library(DESeq2)

sample_table <- read.csv("/path/to/project/metadata/sample_sheet.csv")

gtf <- import("/path/to/reference/gencode.annotation.gtf")
tx2gene <- unique(na.omit(data.frame(
  tx_id = mcols(gtf)$transcript_id,
  gene_id = mcols(gtf)$gene_id
)))

files <- file.path("/path/to/project/salmon", sample_table$sample_id, "quant.sf")
names(files) <- sample_table$sample_id

txi <- tximport(files, type = "salmon", tx2gene = tx2gene, ignoreAfterBar = TRUE)
dds <- DESeqDataSetFromTximport(txi, sample_table, design = ~ condition)
```
