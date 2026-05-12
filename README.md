# Nacev Lab Resources

Shared computational standards and reusable bioinformatics pipeline templates for the Nacev Lab.

The goal of this repository is to make cancer biology analyses easier to start, review, reproduce, and hand off between lab members and collaborators. It provides documentation skeletons, example sample sheets, configuration templates, and workflow outlines for common sequencing analyses used in the lab.

This repository is for templates and standards only. Do not commit raw sequencing data, private project data, patient information, credentials, or hardcoded project-specific paths.

## Current Pipelines

| Pipeline | Location | Use Case |
| --- | --- | --- |
| Cut&Run / CUT&Tag analysis | `pipelines/cut_and_run/` | Chromatin profiling workflows for target enrichment, signal track generation, and peak analysis |
| Bulk RNA-seq analysis | `pipelines/bulk_rna_seq/` | Gene expression workflows for QC, quantification, differential expression, and pathway interpretation |

## Repository Goals

- Standardize lab file naming, metadata, and project organization.
- Reduce hardcoded paths and one-off sample-specific scripts.
- Provide reusable starting points for common bioinformatics analyses.
- Improve reproducibility across projects, manuscripts, and handoffs.
- Document expected inputs, outputs, software assumptions, and key parameters.
- Make analysis workflows approachable for new lab members and wet-lab collaborators.

## How To Use These Templates

1. Choose the pipeline directory that matches the assay.
2. Copy the example sample sheet and config file into a project workspace such as `/path/to/project`.
3. Replace placeholders such as `sample_id`, `condition`, `replicate`, `/path/to/project`, and `/path/to/reference`.
4. Confirm metadata, references, and planned comparisons with the project lead.
5. Run the project-specific implementation of the workflow.
6. Save the final sample sheet, config, logs, and QC reports with the project.

## What Belongs Here

| Appropriate | Not Appropriate |
| --- | --- |
| Reusable README files | Raw FASTQ, BAM, count, or peak files |
| Generic sample sheets | Real patient identifiers or private sample names |
| Generic config files | Credentials, tokens, or private keys |
| Lab-wide documentation templates | Hardcoded personal, cluster, or project-specific paths |
| Troubleshooting notes | Unpublished project-specific results |

## Intended Users

This repository is intended for Nacev Lab members, bioinformaticians, wet-lab scientists, students, and collaborators who need to understand, review, or adapt standard lab analysis workflows.

## Before Starting A Project

- [ ] The project workspace is outside this repository.
- [ ] The sample sheet contains only approved sample identifiers.
- [ ] FASTQ and reference paths use project-specific storage locations.
- [ ] Genome build and annotation versions are documented.
- [ ] The planned analysis comparisons are clear.
- [ ] No private data are being added to this template repository.
