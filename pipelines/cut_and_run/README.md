# Cut&Run / CUT&Tag Analysis Workflow

## Purpose

This folder documents the Nacev Lab standard workflow for Cut&Run and CUT&Tag analysis, from paired-end FASTQ files to filtered BAMs, normalized signal tracks, peak calls, and QC summaries.

The first part of this README walks through the workflow step by step using fake teaching examples. The last section explains how the workflow is summarized into three shell scripts:

- `scripts/01_align_filter.sh`
- `scripts/02_generate_tracks.sh`
- `scripts/03_call_peaks.sh`

The example names and paths below are fake. Do not use real private sample names, patient identifiers, unpublished project details, or hardcoded project-specific directories in this repository.

## Dependencies

| Tool | What it does |
| --- | --- |
| FastQC | Creates per-FASTQ quality reports before trimming or alignment |
| MultiQC | Combines FastQC and other logs into one summary report |
| Cutadapt | Removes adapter sequence, low-quality bases, and short reads |
| Bowtie2 | Aligns paired-end reads to a reference genome |
| Samtools | Converts, sorts, indexes, filters, and counts BAM files |
| Picard or MarkDuplicates | Marks or removes PCR/optical duplicate reads |
| BEDTools | Filters blacklist regions, makes bedGraph coverage, and counts reads in peaks |
| deepTools / bamCoverage | Generates normalized BigWig signal tracks from BAM files |
| bedGraphToBigWig | Converts bedGraph files to BigWig format for genome browsers |
| SEACR | Calls Cut&Run/CUT&Tag peaks from bedGraph signal tracks |
| MACS3 | Calls narrow or broad peaks from BAM files |
| yq | Reads values from YAML config files used by the helper scripts |
| R | Sometimes needed by SEACR or downstream plotting and annotation steps |

## Example Input Files

Example paired-end FASTQ files:

```text
raw_fastq/
├── sample1_H3K4me3_1.fastq.gz
├── sample1_H3K4me3_2.fastq.gz
├── sample1_IgG_1.fastq.gz
├── sample1_IgG_2.fastq.gz
├── sample2_H3K4me3_1.fastq.gz
├── sample2_H3K4me3_2.fastq.gz
├── sample2_IgG_1.fastq.gz
└── sample2_IgG_2.fastq.gz
```

Here, `_1.fastq.gz` and `_2.fastq.gz` mean read 1 and read 2 from paired-end sequencing. In real projects, file names should include condition, target or antibody, replicate, and read number when possible.

Example:

```text
WT_H3K4me3_rep1_R1.fastq.gz
WT_H3K4me3_rep1_R2.fastq.gz
```

## Step-by-Step Workflow

### Step 1. Organize FASTQ files

**Purpose:** Put raw data, references, logs, and results in predictable locations before analysis begins.

**Inputs:**

- Raw paired-end FASTQ files

**Outputs:**

- Organized project directory

**Important parameters:**

- Sample naming
- Paired-end read matching
- Project output folder

**Example project layout:**

```text
/path/to/project/
  raw_fastq/
  trimmed/
  qc/
  logs/
  bam/
  tracks/
  peaks/
  summaries/
```

This organization keeps raw input files separate from processed outputs and makes the analysis easier to review later.

### Step 2. FASTQ quality control

**Purpose:** Check sequencing quality before alignment.

**Inputs:**

- Paired FASTQ files

**Outputs:**

- FastQC HTML reports
- MultiQC summary report

**Important parameters:**

- Number of threads, if supported by the installation
- Output directory

**Example commands:**

```bash
fastqc raw_fastq/*.fastq.gz -o qc/fastqc
multiqc qc/fastqc -o qc/multiqc
```

FastQC checks base quality, adapter content, sequence duplication, GC content, and other basic sequencing metrics. MultiQC collects these reports into a single overview that is easier to review across samples.

### Step 3. Adapter and quality trimming

**Purpose:** Remove adapter sequence, low-quality bases, and reads that are too short to align reliably.

**Inputs:**

- Raw paired FASTQ files

**Outputs:**

- Trimmed paired FASTQ files
- Trimming logs

**Important parameters:**

- Adapter sequence
- Quality cutoff
- Minimum read length

**Example command:**

```bash
cutadapt -a ADAPTER_FWD -A ADAPTER_REV \
  -q 20 -m 20 \
  -o trimmed/sample1_H3K4me3_1.trimmed.fastq.gz \
  -p trimmed/sample1_H3K4me3_2.trimmed.fastq.gz \
  raw_fastq/sample1_H3K4me3_1.fastq.gz \
  raw_fastq/sample1_H3K4me3_2.fastq.gz
```

This trims adapter sequence from both reads in the pair, removes low-quality ends using a quality cutoff of 20, and discards reads shorter than 20 bases after trimming.

### Step 4. Align reads to the reference genome

**Purpose:** Map trimmed reads to the selected reference genome.

**Inputs:**

- Trimmed FASTQ pair
- Bowtie2 genome index

**Outputs:**

- SAM/BAM alignment file
- Alignment log

**Important parameters:**

- Genome build, such as hg38 for human or mm10/mm39 for mouse
- Bowtie2 index path
- Number of threads
- Paired-end mode
- Local sensitive alignment, if used

**Example command:**

```bash
bowtie2 --very-sensitive-local -p 8 \
  -x /path/to/bowtie2_index/hg38 \
  -1 trimmed/sample1_H3K4me3_1.trimmed.fastq.gz \
  -2 trimmed/sample1_H3K4me3_2.trimmed.fastq.gz \
  2> logs/sample1_H3K4me3.bowtie2.log | \
  samtools view -bS - > bam/sample1_H3K4me3.raw.bam
```

Bowtie2 maps reads to the selected genome, and Samtools converts the alignment stream into BAM format. The genome build must match all downstream reference files, including chromosome sizes, blacklist regions, effective genome size, and annotation.

### Step 5. Sort, index, and filter BAM files

**Purpose:** Prepare alignments for downstream tools and remove low-confidence alignments.

**Inputs:**

- Raw BAM

**Outputs:**

- Sorted BAM
- Indexed BAM
- Filtered BAM

**Important parameters:**

- MAPQ threshold
- Properly paired reads
- Removal of unmapped reads
- Optional chromosome filtering

**Example commands:**

```bash
samtools sort -@ 8 -o bam/sample1_H3K4me3.sorted.bam bam/sample1_H3K4me3.raw.bam
samtools index bam/sample1_H3K4me3.sorted.bam

samtools view -b -q 30 -f 2 \
  bam/sample1_H3K4me3.sorted.bam \
  > bam/sample1_H3K4me3.filtered.bam
```

Sorting organizes alignments by genomic coordinate. Indexing allows fast access to the BAM file. The filter shown keeps reads with MAPQ at least 30 and requires properly paired reads.

### Step 6. Duplicate handling

**Purpose:** Mark or remove duplicate reads so PCR or optical duplicates do not inflate signal.

**Inputs:**

- Sorted or filtered BAM

**Outputs:**

- Duplicate-marked or duplicate-removed BAM
- Duplicate metrics

**Important parameters:**

- Mark duplicates versus remove duplicates
- Duplicate metrics file
- Consistent duplicate handling across all samples

**Example command:**

```bash
picard MarkDuplicates \
  I=bam/sample1_H3K4me3.filtered.bam \
  O=bam/sample1_H3K4me3.dedup.bam \
  M=qc/sample1_H3K4me3.duplication_metrics.txt \
  REMOVE_DUPLICATES=true
```

Duplicate handling should be documented because the choice can affect signal tracks, peak calling, and comparisons across samples.

### Step 7. Blacklist filtering

**Purpose:** Remove reads overlapping genomic regions known to produce artifactual signal.

**Inputs:**

- Filtered/deduplicated BAM
- Blacklist BED file matching the genome build

**Outputs:**

- Blacklist-filtered BAM

**Important parameters:**

- Blacklist BED path
- Genome build compatibility

**Example command:**

```bash
bedtools intersect -v \
  -abam bam/sample1_H3K4me3.dedup.bam \
  -b /path/to/hg38-blacklist.bed \
  > bam/sample1_H3K4me3.final.bam
```

The blacklist file must match the genome build. For example, use an hg38 blacklist with hg38 BAMs, not hg19 or mouse blacklist files.

### Step 8. Generate signal tracks

**Purpose:** Create genome browser tracks that show enrichment signal across the genome.

**Inputs:**

- Final BAM
- Chromosome sizes file or effective genome size if needed

**Outputs:**

- BigWig files
- bedGraph files when needed for SEACR

**Important parameters:**

- Bin size
- CPM normalization
- Spike-in scale factor, if used
- BigWig for IGV/UCSC visualization
- bedGraph for SEACR

**Example commands:**

```bash
bamCoverage \
  -b bam/sample1_H3K4me3.final.bam \
  -o tracks/sample1_H3K4me3.CPM.bw \
  --normalizeUsing CPM \
  --binSize 10 \
  -p 8

bedtools genomecov -bg \
  -ibam bam/sample1_H3K4me3.final.bam \
  > tracks/sample1_H3K4me3.bedGraph
```

deepTools `bamCoverage` takes BAM input and generates BigWig or bedGraph coverage tracks. BigWig files are convenient for visualization in IGV or UCSC Genome Browser. bedGraph files are often needed for SEACR peak calling.

### Step 9. Normalization choice

**Purpose:** Choose how signal tracks should be scaled before comparing samples.

CPM normalization adjusts for sequencing depth and is useful when no spike-in is available. Spike-in normalization uses reads aligned to a spike-in genome to calculate a scale factor. The normalization method should be chosen and documented before comparing tracks across samples.

**Inputs:**

- Final BAM
- Mapped read counts or spike-in read counts

**Outputs:**

- Normalized BigWig/bedGraph tracks
- Scale-factor table if spike-in is used

**Important parameters:**

- Normalization method
- Scale factor
- Normalization group
- Whether spike-in is available

**Example pseudo-command:**

```bash
# CPM-style normalization
bamCoverage -b bam/sample1_H3K4me3.final.bam --normalizeUsing CPM -o tracks/sample1_H3K4me3.CPM.bw

# Spike-in-style normalization
bedtools genomecov -bg -scale SPIKEIN_SCALE_FACTOR -ibam bam/sample1_H3K4me3.final.bam > tracks/sample1_H3K4me3.spikein.bedGraph
```

Samples should only be compared quantitatively when the normalization strategy is appropriate for the experiment and is applied consistently.

### Step 10. Peak calling

**Purpose:** Identify genomic regions enriched for the target signal compared with a matched control when available.

**Inputs:**

- Target bedGraph or BAM
- Matched IgG/control bedGraph or BAM if available

**Outputs:**

- SEACR peak BED files
- MACS3 narrowPeak or broadPeak files
- Peak summary table

**Important parameters:**

- SEACR stringent versus relaxed
- SEACR `norm` versus `non`
- MACS3 narrow versus broad
- q-value or p-value cutoff
- Matched IgG/control choice

**Example SEACR command:**

```bash
bash SEACR_1.3.sh \
  tracks/sample1_H3K4me3.bedGraph \
  tracks/sample1_IgG.bedGraph \
  norm stringent \
  peaks/sample1_H3K4me3.SEACR.stringent
```

**Example MACS3 command:**

```bash
macs3 callpeak \
  -t bam/sample1_H3K4me3.final.bam \
  -c bam/sample1_IgG.final.bam \
  -f BAMPE \
  -g hs \
  -n sample1_H3K4me3 \
  --outdir peaks/macs3 \
  -q 0.05
```

SEACR is commonly used for sparse CUT&RUN and chromatin-profiling data and expects bedGraph input. MACS3 can be used as an additional or alternative peak caller depending on the target and signal pattern. Narrow marks or transcription factors often use narrow peak calling; broad histone marks often use broad peak calling.

### Step 11. QC summary and FRiP

**Purpose:** Summarize read counts, peak counts, enrichment quality, and other metrics needed to review the analysis.

**Inputs:**

- Final BAM
- Called peak BED file

**Outputs:**

- Read-count summaries
- Peak-count summaries
- FRiP table
- Final QC summary

**Important parameters:**

- Peak file used for FRiP
- Final filtered BAM
- Target/control comparison

FRiP means fraction of reads in peaks. Higher FRiP often suggests stronger enrichment, but interpretation depends on antibody, target type, assay quality, and biological context. A broad mark, a narrow transcription factor, and an IgG control should not be judged with exactly the same expectations.

## How This Repository Summarizes the Workflow

The detailed workflow above is summarized into three helper scripts. The sample sheet and config files in `examples/` are optional templates that help the scripts avoid hardcoded paths and sample names. They are not the main concept of the workflow; they are editable helpers for running the workflow consistently.

### `scripts/01_align_filter.sh`

This script performs:

- Trimming
- Alignment
- Sorting/indexing
- Duplicate handling
- MAPQ/proper-pair filtering
- Optional blacklist removal
- Alignment QC

Users need to edit or check:

- FASTQ input folder or FASTQ file paths
- Sample names
- Output directory
- Bowtie2 index path
- Blacklist BED path
- Number of threads
- MAPQ cutoff
- Duplicate handling choice

### `scripts/02_generate_tracks.sh`

This script performs:

- bedGraph generation
- BigWig generation
- CPM normalization
- Optional spike-in normalization
- Signal-track organization for IGV/UCSC visualization

Users need to edit or check:

- Final BAM input folder
- Chromosome sizes file
- Normalization method
- Spike-in settings, if used
- Bin size
- Scale factors
- Output directory

### `scripts/03_call_peaks.sh`

This script performs:

- SEACR peak calling
- MACS3 peak calling
- Matched IgG/control handling
- Peak summaries
- FRiP calculation

Users need to edit or check:

- Target-control matching
- SEACR path
- MACS3 peak type
- q-value cutoff
- Genome size option
- Peak output directory
- FRiP settings

## Reference Genome and Annotation Choices

Use hg38 for most modern human data unless a project specifically requires hg19. Use mm10 or mm39 for mouse depending on the reference chosen by the project and collaborators.

The Bowtie2 index, chromosome sizes, blacklist BED, effective genome size, and downstream annotation must all match the same genome build. GENCODE GTF is mainly used for downstream peak annotation, promoter/gene assignment, and biological interpretation. It is not always required for the core alignment or peak-calling steps.

Never mix hg38 BAMs with hg19 annotation, or mm10 BAMs with mm39 annotation.

## Expected Final Outputs

| Output | What it means |
| --- | --- |
| Trimmed FASTQ files | Reads after adapter and quality trimming |
| Alignment logs | Bowtie2 mapping summaries and warnings |
| Sorted BAM files | Coordinate-sorted alignment files |
| Filtered/final BAM files and BAM indexes | Main alignment files used for tracks, peaks, and QC |
| Duplicate metrics | Summary of duplicate read levels |
| Blacklist-filtered BAMs | BAMs with problematic genomic regions removed |
| BigWig signal tracks | Browser-ready coverage tracks for IGV/UCSC |
| bedGraph files | Coverage tracks often used as SEACR input |
| SEACR peak BED files | Peak calls from bedGraph signal |
| MACS3 narrowPeak/broadPeak files | Peak calls from BAM alignments |
| Peak summary tables | Counts and settings for peak-calling outputs |
| FRiP summaries | Fraction of reads in peaks and supporting counts |
| FastQC/MultiQC reports | Sequencing and workflow QC summaries |

## Data Policy

Do not commit raw FASTQ, BAM, BigWig, bedGraph, peak output files, private sample names, patient information, unpublished project results, credentials, or hardcoded project-specific paths to this repository. This repository should contain reusable scripts, documentation, and fake examples only.
