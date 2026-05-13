# TE-Expression Scripts

These scripts are transparent templates for TE-expression analysis.

The current Nacev Lab TE-expression standard is mouse/mm10:

```text
paired FASTQ files -> STAR sorted BAM -> TElocal -> TE downstream analysis
```

STAR is used here because TElocal requires genome-aligned BAM files. For regular gene-level bulk RNA-seq, use Salmon instead.

## Scripts

| Script | Standard reference | Purpose |
| --- | --- | --- |
| `01_star_align_for_telocal_mouse_mm10.sh` | Mouse mm10 | Align paired-end FASTQs with STAR and write sorted BAM files |
| `02_telocal_mouse_mm10.sh` | Mouse mm10 | Run TElocal on STAR BAM files to produce TE count tables |

## Before Running STAR

Edit:

- `FASTQ_DIR`
- `OUTPUT_DIR`
- `STAR_INDEX`
- `THREADS`
- `READ1_SUFFIX`
- `READ2_SUFFIX`
- `READ_FILES_COMMAND`

The example FASTQ pattern is:

```text
sample1_1.fastq.gz
sample1_2.fastq.gz
sample2_1.fastq.gz
sample2_2.fastq.gz
```

## Before Running TElocal

Edit:

- `STAR_OUTPUT_DIR`
- `OUTPUT_DIR`
- `GENE_GTF`
- `TE_ANNOTATION`
- `BAM_SUFFIX`

The STAR index, gene GTF, TE annotation, and downstream interpretation files must all match mouse mm10.

## Human TE-Expression Note

Human/hg38 TE-expression scripts will be added later after reference annotations and expected outputs are standardized.

Do not commit STAR BAM files, TElocal count tables, private sample metadata, or project-specific outputs to this repository.
