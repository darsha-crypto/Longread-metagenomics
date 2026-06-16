# Long-Read Metagenomics Pipeline (PacBio HiFi / ONT)

An end-to-end metagenomics pipeline for long-read sequencing data (PacBio HiFi / Oxford Nanopore). Demonstrated on a bioethanol fermentation metagenome, taking raw reads through assembly, binning, and genome-resolved functional annotation.

---

## Overview

This pipeline integrates 11 stages of analysis to produce taxonomically classified, quality-assessed, and functionally annotated Metagenome-Assembled Genomes (MAGs):

1. Quality control of raw reads
2. De novo metagenomic assembly
3. Assembly quality assessment
4. Taxonomic classification and prokaryote/eukaryote splitting
5. Read mapping and genome binning
6. Bin refinement
7. Genome quality assessment
8. Relative abundance estimation
9. Taxonomic annotation of MAGs
10. Functional annotation
11. Integration of taxonomy, abundance, and function into a single summary table

---

## Pipeline Diagram

```
Raw Reads (PacBio HiFi)
        │
        ▼
1. QC                    →  FastQC, Trimmomatic
        ▼
2. Assembly               →  MetaFlye (meta mode)
        ▼
3. Assembly QC             →  QUAST
        ▼
4. Taxonomy                →  Kraken2
        │
        ├── Prokaryotic contigs
        └── Eukaryotic contigs (manual binning)
        ▼
5. Mapping + Binning        →  Minimap2, MetaBAT2, MaxBin2, CONCOCT
        ▼
6. Bin Refinement           →  DAS Tool
        ▼
7. Genome Quality           →  CheckM2
        ▼
8. Relative Abundance       →  CoverM
        ▼
9. Taxonomy Annotation      →  GTDBtk
        ▼
10. Functional Annotation   →  Prodigal, InterProScan
        ▼
11. Integration             →  MAG × Taxonomy × Abundance × Function
```

---

## Example Results

| Metric | Value |
|---|---|
| Assembly size | 104.2 Mb |
| Contigs | 3,343 |
| N50 | 83.7 kb |
| Largest contig | ~3.0 Mb |
| GC content | 41% |
| Bins assessed (CheckM2) | 22 |
| High-quality MAGs (≥90% complete, ≤5% contam.) | 4 |
| Medium-quality MAGs (≥50% complete, ≤10% contam.) | 10 |

*Results shown are from a bioethanol fermentation sample (PacBio HiFi, single-end).*

---

## Tools Used

| Stage | Tool |
|---|---|
| QC | FastQC, Trimmomatic |
| Assembly | MetaFlye |
| Assembly QC | QUAST |
| Taxonomy | Kraken2 (PlusPF-8GB) |
| Read mapping | Minimap2 |
| Binning | MetaBAT2, MaxBin2, CONCOCT |
| Bin refinement | DAS Tool |
| Genome quality | CheckM2 |
| Abundance | CoverM |
| Taxonomy annotation | GTDBtk |
| Functional annotation | Prodigal, InterProScan |

---

## Requirements

- **Platform:** Google Colab (uses Google Drive for storage)
- **Python:** pandas, numpy, matplotlib
- **System tools:** fastqc, trimmomatic, kraken2, minimap2, prodigal, seqkit
- **Conda/micromamba environments:** flye, quast, metabat2, maxbin2, concoct, das_tool, checkm2, coverm

---

## Usage

1. Edit the configuration cell at the top of the notebook:
   ```python
   SAMPLE = "your_sample_name"
   READS  = "/path/to/reads.fastq.gz"
   WORK   = "/path/to/working_directory"
   THREADS = 8
   ```
2. Download the required databases (Kraken2 PlusPF, CheckM2 DB) and update their paths.
3. Run cells sequentially — each pipeline stage is self-contained with install, run, and summary cells.

---

## Notes

- Trimming was found unnecessary for HiFi reads in this dataset (raw vs. trimmed QC showed no meaningful difference), so assembly was run on raw reads.
- Eukaryotic contigs (4 total, *Saccharomyces* spp.) were too few for standard binning tools and were extracted and binned manually.
- GTDBtk was run externally via KBase due to its large database size (~128 GB); results were merged back into the pipeline.

---

## Repository Structure

```
.
├── Long_reads_Metagenomics_Pipeline_Template.ipynb
└── README.md
```

---

## License

Shared for educational and research purposes.
