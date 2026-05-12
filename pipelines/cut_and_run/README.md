# Cut&Run / CUT&Tag Analysis Pipeline

This folder contains the lab-standard template for Cut&Run and CUT&Tag analysis.

## Planned Workflow

1. Input organization and sample sheet preparation
2. FASTQ quality control
3. Adapter trimming
4. Alignment to reference genome
5. BAM filtering and quality control
6. Signal track generation
7. Peak calling
8. Downstream comparison and visualization

## Input Philosophy

This pipeline should use a sample sheet and configuration file instead of hardcoded sample names, private project paths, or dataset-specific folder structures.
