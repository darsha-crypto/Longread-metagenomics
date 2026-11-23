# Long-Read Metagenomics Pipeline (PacBio HiFi / ONT)

A Nextflow (DSL2) pipeline that takes long-read metagenomic data from raw reads to quality-checked, taxonomically classified and functionally annotated metagenome-assembled genomes (MAGs). Every step runs in a pinned BioContainers image, and the pipeline runs on Google Cloud Batch or on a local machine.

It is split into two workflows:

- **`main.nf`** (stages 1–6): read QC → assembly → contig taxonomy → binning and refinement → MAG quality → MAG abundance
- **`mag_annotation.nf`** (stages 7–8): MAG taxonomy → gene prediction → functional annotation → Excel report. It accepts MAGs from this pipeline or from any other source.

---

## Pipeline overview

```
Raw long reads (PacBio HiFi / ONT)
        │
1. Read QC and filtering        NanoPlot (before and after), Filtlong
        │
2. Assembly                     metaFlye; contigs ≥ 1,500 bp kept with SeqKit; QUAST
        │
3. Contig taxonomy              Kraken2; prokaryotic contigs extracted with SeqKit
        │
4. Read mapping and binning     Minimap2 → MetaBAT2, MaxBin2, CONCOCT → DAS Tool
        │
5. MAG quality                  CheckM2 → high-quality (≥90% complete, <5% contamination)
                                and medium-quality (≥50%, <10%) MAG sets
        │
6. MAG abundance                CoverM
        │                                         ── end of main.nf
7. MAG annotation               GTDB-Tk (r232), Prodigal, InterProScan
        │
8. Report                       Excel workbook joining quality, taxonomy, abundance and function
                                          ── end of mag_annotation.nf
```

---

## Tools and container versions

| Stage | Tool | Version |
|---|---|---|
| Read QC | NanoPlot | 1.46.2 |
| Read filtering | Filtlong | 0.2.1 |
| Assembly | Flye (meta mode) | 2.9.6 |
| Contig filtering | SeqKit | 2.13.0 |
| Assembly QC | QUAST | 5.3.0 |
| Contig taxonomy | Kraken2 | 2.17.1 |
| Read mapping | Minimap2 | 2.30 |
| Binning | MetaBAT2, MaxBin2, CONCOCT | 2.18, 2.2.7, 1.1.0 |
| Bin refinement | DAS Tool | 1.1.7 |
| MAG quality | CheckM2 | 1.1.0 |
| MAG abundance | CoverM | 0.7.0 |
| MAG taxonomy | GTDB-Tk | 2.7.1, database r232 |
| Gene prediction | Prodigal | 2.6.3 |
| Functional annotation | InterProScan | 5.59-91.0 |
| Report | Python, pandas, openpyxl | 3.11 |

---

## Requirements

- Nextflow ≥ 25.0
- For the `gcp` profile: a Google Cloud project with the Batch API enabled and a Cloud Storage bucket
- For the `local` profile: the tools above installed on your machine
- Databases: Kraken2 (for example PlusPF), CheckM2 and GTDB-Tk r232, plus a local InterProScan installation for `mag_annotation.nf`

Before running on Google Cloud, set `google.project` and `google.location` in `nextflow.config` to your own project and region, and point `--outdir` and the database paths to your own bucket.

---

## Usage

**Stages 1–6, one sample:**

```bash
nextflow run main.nf -profile gcp \
    --sample my_sample \
    --reads gs://my-bucket/reads/my_sample.fastq.gz \
    --outdir gs://my-bucket/results \
    --kraken2_db gs://my-bucket/databases/kraken2_db \
    --checkm2_db gs://my-bucket/databases/checkm2_db/uniref100.KO.1.dmnd
```

**Stages 1–6, several samples:** list them in a sample sheet with the columns `sample,reads` (see `samplesheet.csv`) and pass `--samplesheet samplesheet.csv` instead of `--sample` and `--reads`.

**Stages 7–8:**

```bash
nextflow run mag_annotation.nf -profile gcp \
    --sample my_sample \
    --hq_bins "gs://my-bucket/results/my_sample/08_checkm2/bins_HQ/*.fa" \
    --mq_bins "gs://my-bucket/results/my_sample/08_checkm2/bins_MQ/*.fa" \
    --quality_report gs://my-bucket/results/my_sample/08_checkm2/quality_report.tsv \
    --coverm gs://my-bucket/results/my_sample/09_coverm/coverage_results.tsv \
    --gtdbtk_db gs://my-bucket/databases/gtdbtk_r232_db/release232 \
    --interproscan_dir /path/to/interproscan
```

Key parameters, with defaults in `nextflow.config`: `min_read_length` 1,000 bp, `min_contig_len` 1,500 bp, and the InterProScan applications in `ipr_appl`. Filtlong also keeps only reads with a mean quality of at least 90 on its 0–100 scale; change `--min_mean_q` in `modules/longread/qc.nf` to adjust this.

---

## Outputs

Results are written to `<outdir>/<sample>/`:

| Folder | Contents |
|---|---|
| `01_qc_raw`, `03_qc_filtered` | NanoPlot reports before and after filtering |
| `02_filtered` | Filtered reads |
| `04_assembly`, `05_quast` | Assembly, filtered contigs and QUAST report |
| `06_taxonomy` | Kraken2 output and prokaryotic contigs |
| `07_binning` | MetaBAT2, MaxBin2, CONCOCT and DAS Tool bins |
| `08_checkm2` | CheckM2 report and high- and medium-quality MAGs |
| `09_coverm` | MAG relative abundance and coverage |
| `10_gtdb`, `11_prodigal`, `12_interproscan` | MAG taxonomy, predicted genes and functional annotation |
| `Stage8_Excel` | Excel report combining all results per MAG |

Run reports (timeline, resource report and trace) are written to `<outdir>/pipeline_info/`.

---

## Example results

From a bioethanol fermentation metagenome sequenced with PacBio HiFi:

| Metric | Value |
|---|---|
| Assembly size | 104.2 Mb |
| Contigs | 3,343 |
| N50 | 83.7 kb |
| Largest contig | ~3.0 Mb |
| GC content | 41% |
| Bins assessed by CheckM2 | 22 |
| High-quality MAGs (≥90% complete, ≤5% contamination) | 4 |
| Medium-quality MAGs (≥50% complete, ≤10% contamination) | 10 |

---

## Notes

- Kraken2 is used to keep prokaryotic contigs for binning. In the example dataset, the few eukaryotic contigs (*Saccharomyces*) were too few for the binning tools and were binned manually.
- Prodigal prefixes every protein with its MAG name (`MAG__contig`), so proteins can be traced back to their MAG after merging.
- InterProScan runs high- and medium-quality MAGs separately, and CDD is left out of the applications, because both caused database errors in testing.
- GTDB-Tk needs about 256 GB of memory for pplacer; the `gcp` profile requests an `n2-highmem-32` machine for this step.

---

## Repository structure

```
.
├── main.nf                    # stages 1–6
├── mag_annotation.nf          # stages 7–8
├── nextflow.config            # parameters, profiles and resources
├── samplesheet.csv            # example sample sheet
├── LICENSE                    # MIT license
└── modules/
    ├── longread/              # qc, assembly, taxonomy, binning, checkm2, coverm
    └── annotation/            # gtdbtk, prodigal, interproscan, report
```

---

## Author

Darsha Prabhaharan, Hanyang University, Seoul, Republic of Korea

## License

MIT. See [`LICENSE`](LICENSE).
