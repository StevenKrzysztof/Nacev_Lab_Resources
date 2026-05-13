# Bulk RNA-seq Analysis Workflow

## Purpose

This folder documents the Nacev Lab standard workflow for bulk RNA-seq analysis, from paired-end FASTQ files to Salmon quantification, gene-level DESeq2 analysis, QC plots, differential expression tables, and pathway interpretation.

The lab standard for regular gene-level bulk RNA-seq is Salmon-based quantification. STAR alignment is still useful when BAM files are required, such as transposable-element analysis, genome-browser inspection, splice-aware alignment projects, or special analyses requested by collaborators.

This README first explains the workflow step by step, then summarizes how the previous project files should inform the standardized repository structure. The examples below use fake teaching sample names only.

## Reference File Audit

| Reference file | Use in lab standard | Keep | Generalize |
| --- | --- | --- | --- |
| `salmon_alignment.sh` | Mouse Salmon quantification reference | Cutadapt, FastQC, Salmon paired-end quantification | Hardcoded input/output paths, sample prefix patterns, email, conda environment, GRCm38 naming; use mm10 as current mouse standard |
| `align_batch1.sh` | Human Salmon quantification reference | Salmon quantification pattern for human data | Hardcoded project paths, sample folders, thread counts, batch-specific output layout; use hg38 as current human standard |
| `tumor_group.Rmd` | Main gene-level Salmon import reference | `tximport` loading of Salmon `quant.sf`, `tx2gene`, DESeq2 from imported Salmon counts | Project-specific sample names, paths, design variables, contrasts, titles, and mouse package choices |
| `Andrew_tumor_STAR_version.Rmd` | Downstream analysis style reference after count matrix exists | DESeq2 structure, filtering logic, PCA, heatmaps, result exports, GO/KEGG/Hallmark enrichment sections | STAR/featureCounts input should not replace Salmon for regular gene-level RNA-seq |
| `STAR_align_mouse.sh` | Mouse STAR and TElocal reference | STAR sorted BAM generation and paired TElocal execution | Dataset paths, sample prefix, mm10 paths, integrated project layout |
| `align_TE_batch1.sh` | Human STAR alignment reference for TE-style workflows | STAR sorted BAM logic and high multimapping allowance | Dataset paths, sample names, use of pre-trimmed FASTQs, human TE standard is not finalized yet |
| `TElocal_batch1.sh` | Human TElocal-style reference | TElocal command shape and required GTF/TE annotation inputs | Hardcoded sample list, paths, and project-specific TE annotations; human/hg38 standard will be added later |
| `TE_tumor_group.Rmd` | TE-expression downstream reference | Loading `.cntTable` files, filtering TE rows, DESeq2, TE class summaries, PCA, heatmaps | Project-specific samples, contrasts, and mouse-focused assumptions |
| `change_name_salmon1.sh` | Salmon output housekeeping reference | Awareness that `quant.sf` files must be mapped cleanly to sample IDs | Renaming `quant.sf` is optional; prefer a sample sheet that points to each output directory |

## Standard Workflow Summary

| Analysis type | Current lab standard |
| --- | --- |
| Human gene-level RNA-seq | Salmon quantification against hg38 transcriptome index, then tximport and DESeq2 |
| Mouse gene-level RNA-seq | Salmon quantification against mm10 transcriptome index, then tximport and DESeq2 |
| Mouse TE-expression analysis | STAR alignment to mm10, TElocal with mm10-compatible gene and TE annotations, then DESeq2 |
| Human TE-expression analysis | Planned future standard; current files are useful references but not yet a complete hg38 TE standard |

## Gene Expression vs TE Expression

| Workflow | Standard path | When to use |
| --- | --- | --- |
| Gene-level expression | FASTQ -> Salmon quantification -> tximport/DESeq2 R Markdown | Routine bulk RNA-seq differential gene expression |
| TE expression | FASTQ -> STAR BAM alignment -> TElocal -> TE downstream analysis | Transposable-element expression projects that require genome-aligned BAM files |

Salmon remains the standard for regular gene-level bulk RNA-seq. STAR is used when the analysis needs aligned BAM files, especially TE-expression analysis.

## Dependencies

| Tool | Purpose |
| --- | --- |
| FastQC | Per-sample FASTQ quality reports |
| MultiQC | Combined QC report across samples |
| Cutadapt | Adapter and fixed-base trimming when needed |
| Salmon | Transcript-level quantification for the gene-level RNA-seq standard |
| tximport | Imports Salmon `quant.sf` files into gene-level matrices for DESeq2 |
| DESeq2 | Differential expression analysis |
| STAR | Splice-aware genome alignment when BAM output is required |
| TElocal | TE-expression quantification from STAR BAM files |
| Samtools | BAM inspection, indexing, and alignment QC |
| R / RStudio / Quarto or R Markdown | Statistical analysis, reports, and plots |
| clusterProfiler / msigdbr / enrichplot | GO, KEGG, Hallmark, and GSEA-style interpretation |

## Example Input Files

Example paired-end FASTQ files:

```text
raw_fastq/
├── celllineA_control_rep1_R1.fastq.gz
├── celllineA_control_rep1_R2.fastq.gz
├── celllineA_control_rep2_R1.fastq.gz
├── celllineA_control_rep2_R2.fastq.gz
├── celllineA_treated_rep1_R1.fastq.gz
├── celllineA_treated_rep1_R2.fastq.gz
├── celllineA_treated_rep2_R1.fastq.gz
└── celllineA_treated_rep2_R2.fastq.gz
```

`R1` and `R2` are read 1 and read 2 from paired-end sequencing. Real sample names should be approved by the project team and should not contain private identifiers. Include condition, replicate, and read number whenever possible.

## Step-by-Step Gene-Level Workflow

### Step 1. Organize project files

**Purpose:** Keep raw data, metadata, references, quantification outputs, and reports separate.

**Inputs:**

- Raw paired-end FASTQ files
- Sample metadata table
- Project-approved reference genome and annotation

**Outputs:**

- Organized project directory

**Important parameters:**

- Species: human or mouse
- Genome build: hg38 for human, mm10 for mouse
- Sample naming and replicate labels
- Project output folder

**Example layout:**

```text
/path/to/project/
  raw_fastq/
  metadata/
  qc/
  trimmed/
  salmon/
  results/
  reports/
```

### Step 2. FASTQ quality control

**Purpose:** Check sequencing quality before trimming or quantification.

**Inputs:**

- Paired FASTQ files

**Outputs:**

- FastQC HTML files
- MultiQC summary report

**Important parameters:**

- Output directory
- Number of threads, if supported

**Example commands:**

```bash
fastqc raw_fastq/*.fastq.gz -o qc/fastqc
multiqc qc/fastqc -o qc/multiqc
```

### Step 3. Adapter or fixed-base trimming

**Purpose:** Remove adapter sequence or low-quality/fixed-position bases when QC indicates trimming is needed.

**Inputs:**

- Raw paired FASTQ files

**Outputs:**

- Trimmed paired FASTQ files
- Cutadapt logs

**Important parameters:**

- Adapter sequence, if known
- Number of leading bases to remove, if justified by QC
- Quality cutoff
- Minimum read length

**Example command:**

```bash
cutadapt -q 20 -m 20 \
  -o trimmed/celllineA_control_rep1_R1.trimmed.fastq.gz \
  -p trimmed/celllineA_control_rep1_R2.trimmed.fastq.gz \
  raw_fastq/celllineA_control_rep1_R1.fastq.gz \
  raw_fastq/celllineA_control_rep1_R2.fastq.gz
```

### Step 4. Salmon quantification

**Purpose:** Quantify transcript abundance quickly and consistently without requiring genome-aligned BAM files.

**Inputs:**

- Trimmed or raw paired FASTQ files
- Salmon transcriptome index matching the project genome build

**Outputs:**

- One Salmon output directory per sample
- `quant.sf`
- Salmon logs and auxiliary QC files

**Important parameters:**

- Salmon index path
- Library type, usually `-l A` for automatic detection
- Number of threads
- `--validateMappings`
- Species/build: hg38 for human, mm10 for mouse

**Example command:**

```bash
salmon quant \
  -i /path/to/reference/hg38/salmon_index \
  -l A \
  -1 trimmed/celllineA_control_rep1_R1.trimmed.fastq.gz \
  -2 trimmed/celllineA_control_rep1_R2.trimmed.fastq.gz \
  -p 8 \
  --validateMappings \
  -o salmon/celllineA_control_rep1
```

Salmon is the standard for gene-level bulk RNA-seq in this repository because it produces robust transcript quantification efficiently and integrates well with `tximport` for DESeq2 gene-level analysis.

### Step 5. Import Salmon results into R

**Purpose:** Convert sample-level Salmon `quant.sf` files into a gene-level count matrix for DESeq2.

**Inputs:**

- Salmon `quant.sf` files
- Sample metadata table
- GTF file matching the Salmon index genome build

**Outputs:**

- `tximport` object
- Gene-level count matrix
- DESeq2 input object

**Important parameters:**

- Correct paths to `quant.sf`
- `tx2gene` table from matching GTF
- Sample metadata row names matching sample IDs
- Design formula

**Example R pattern:**

```r
library(tximport)
library(rtracklayer)
library(DESeq2)

gtf <- import("/path/to/reference/gencode.annotation.gtf")
tx2gene <- unique(na.omit(data.frame(
  tx_id = mcols(gtf)$transcript_id,
  gene_id = mcols(gtf)$gene_id
)))

sample_table$files <- file.path("/path/to/project/salmon", sample_table$sample_id, "quant.sf")
names(sample_table$files) <- sample_table$sample_id

txi <- tximport(sample_table$files, type = "salmon", tx2gene = tx2gene, ignoreAfterBar = TRUE)
dds <- DESeqDataSetFromTximport(txi, sample_table, design = ~ condition)
```

This pattern comes from the Salmon-based notebook reference. It should replace project-specific sample vectors with a reusable sample metadata table.

### Step 6. Differential expression analysis

**Purpose:** Test planned biological contrasts using DESeq2.

**Inputs:**

- DESeq2 object
- Sample metadata
- Approved contrasts

**Outputs:**

- Differential expression result tables
- Significant gene lists
- Normalized or transformed expression matrices

**Important parameters:**

- Design formula, such as `~ condition` or `~ batch + condition`
- Minimum count filter
- Contrast direction
- Adjusted p-value threshold
- Log2 fold-change threshold

**Example R pattern:**

```r
keep <- rowSums(counts(dds) >= 10) >= 2
dds <- dds[keep, ]
dds <- DESeq(dds)

res <- results(dds, contrast = c("condition", "treated", "control"), alpha = 0.05)
res_sig <- res[which(res$padj < 0.05 & abs(res$log2FoldChange) > 1), ]
```

### Step 7. QC plots and expression summaries

**Purpose:** Check whether samples behave as expected and identify outliers or batch effects.

**Inputs:**

- DESeq2 object
- Transformed expression matrix
- Sample metadata

**Outputs:**

- PCA plots
- Sample distance heatmaps
- Top variable gene heatmaps
- Heatmaps of significant genes

**Important parameters:**

- Blind versus design-aware transformation
- Metadata variables used for plotting
- Number of top variable genes

### Step 8. Biological interpretation

**Purpose:** Summarize differential expression results in pathway and gene-set terms.

**Inputs:**

- Ranked gene lists
- Significant up/down gene lists
- Organism-specific annotation package
- Gene set database

**Outputs:**

- GO enrichment tables and plots
- KEGG enrichment tables and plots
- Hallmark enrichment or GSEA outputs
- Exported pathway summaries

**Important parameters:**

- Species-specific annotation: `org.Hs.eg.db` for human, `org.Mm.eg.db` for mouse
- Gene identifier type
- Background universe
- Ranking statistic for GSEA
- Multiple-testing threshold

## STAR And TE-Expression Workflow

STAR is not the default for regular gene-level RNA-seq in this repository. Use STAR when the project needs genome-aligned BAM files.

Common reasons to use STAR:

- TE-expression analysis with TElocal
- Manual inspection of alignments
- Splice-aware alignment outputs
- Special collaborator-requested methods

For TE-expression analysis, the current documented standard is mouse/mm10. A human/hg38 TE-expression standard will be added later.

High-level TE workflow:

1. QC and trim FASTQs.
2. Align reads to mm10 with STAR.
3. Keep sorted coordinate BAMs.
4. Run TElocal with matching gene GTF and TE annotation.
5. Load `.cntTable` files into R.
6. Run DESeq2 and TE-focused QC/plots.

## How This Repository Summarizes the Workflow

The detailed workflow above is summarized into small, editable shell scripts plus one downstream R Markdown template. These are lab templates, not a full workflow manager.

### Gene-Level Expression Scripts

Use one of these scripts to produce Salmon output folders with one `quant.sf` file per sample:

- `scripts/gene_expression/01_salmon_quant_human_hg38.sh`
- `scripts/gene_expression/01_salmon_quant_mouse_mm10.sh`

Before running, edit the variables near the top of the script:

- FASTQ input directory
- Salmon output directory
- Salmon index path
- Read suffix pattern, such as `_1.fastq.gz` and `_2.fastq.gz`
- Number of threads
- Salmon library type

After Salmon finishes, use:

- `scripts/gene_expression/02_collect_salmon_quant.sh`

This checks that Salmon output folders contain `quant.sf` and creates simple metadata helper files for downstream R analysis. It does not run DESeq2.

Then run:

- `rmarkdown/bulk_rna_seq_salmon_deseq2_standard.Rmd`

The R Markdown template imports Salmon `quant.sf` files with `tximport`, creates the DESeq2 object, runs differential expression, and generates QC plots, heatmaps, volcano plots, gene expression boxplots, and enrichment outputs.

### TE-Expression Scripts

For mouse/mm10 TE-expression analysis, use:

- `scripts/te_expression/01_star_align_for_telocal_mouse_mm10.sh`
- `scripts/te_expression/02_telocal_mouse_mm10.sh`

The STAR script creates sorted BAM files because TElocal requires aligned reads. The TElocal script uses mouse/mm10 gene and TE annotation placeholders and produces TE count tables. Human/hg38 TE scripts will be added later.

## Reference Genome And Annotation Choices

- Use hg38 for current human bulk RNA-seq standards.
- Use mm10 for current mouse bulk RNA-seq standards.
- Salmon index, STAR index, GTF, TE annotation, chromosome naming, and genome build must match.
- Do not mix hg38 Salmon quantification with hg19 annotation.
- Do not mix mm10 STAR BAM files with mm39 or human TE annotations.
- GENCODE annotations are preferred when available and appropriate for the project.

## Expected Final Outputs

| Output | Description |
| --- | --- |
| FastQC reports | Per-sample sequencing QC |
| MultiQC report | Combined QC summary |
| Trimmed FASTQs | Optional trimmed reads used for quantification/alignment |
| Salmon output directories | Per-sample transcript quantification results |
| `quant.sf` files | Main Salmon quantification output imported by tximport |
| Gene-level count matrix | Matrix used for DESeq2 |
| DESeq2 result tables | Differential expression statistics for planned contrasts |
| PCA plots | Sample-level QC and clustering |
| Heatmaps | Expression patterns for variable or significant genes |
| Enrichment tables and plots | GO, KEGG, Hallmark, or GSEA interpretation |
| STAR BAM files | Alignment outputs for TE or special workflows |
| TElocal `.cntTable` files | TE count tables for TE-expression analysis |
| TE DESeq2 results | Differential TE-expression tables and plots |

## Data Policy

Do not commit raw FASTQ, BAM, Salmon output directories, `quant.sf` files, count matrices, TE count tables, private sample names, patient information, unpublished project results, credentials, or hardcoded project-specific paths to this repository. This repository should contain reusable documentation, fake examples, and standardization plans only.
