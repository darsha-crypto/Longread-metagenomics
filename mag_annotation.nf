// ─── MAG Annotation Pipeline ──────────────────────────────────────────────────
// Stages 7-8: GTDB-tk · Prodigal · InterProScan · Excel Report
// Input: MAGs from ANY source (longread, shortread, or external)
// Run: nextflow run mag_annotation.nf \
//        --sample sample01 \
//        --hq_bins "gs://bucket/results/08_checkm2/bins_HQ/*.fa" \
//        --mq_bins "gs://bucket/results/08_checkm2/bins_MQ/*.fa" \
//        --quality_report "gs://bucket/results/08_checkm2/quality_report.tsv" \
//        --coverm "gs://bucket/results/09_coverm/coverage_results.tsv" \
//        --interproscan_dir "/path/to/interproscan-5.75-106.0" \
//        -profile gcp

nextflow.enable.dsl=2

include { GTDBTK }                                      from './modules/annotation/gtdbtk'
include { PRODIGAL }                                    from './modules/annotation/prodigal'
include { INTERPROSCAN_SETUP;
          INTERPROSCAN_HQ;
          INTERPROSCAN_MQ;
          MERGE_INTERPROSCAN }                          from './modules/annotation/interproscan'
include { INSTALL_DEPS; REPORT }                        from './modules/annotation/report'

workflow {

    // ── Validate inputs ───────────────────────────────────────────────────────
    if (!params.sample)         error "Please provide --sample"
    if (!params.hq_bins)        error "Please provide --hq_bins"
    if (!params.mq_bins)        error "Please provide --mq_bins"
    if (!params.quality_report) error "Please provide --quality_report"
    if (!params.coverm)         error "Please provide --coverm"

    // ── Input channels ────────────────────────────────────────────────────────
    hq_bins_ch       = Channel.fromPath(params.hq_bins)
    mq_bins_ch       = Channel.fromPath(params.mq_bins)
    quality_report_ch= Channel.fromPath(params.quality_report)
    coverm_ch        = Channel.fromPath(params.coverm)
    gtdbtk_db_ch     = Channel.fromPath(params.gtdbtk_db)
    ipr_dir_ch       = Channel.fromPath(params.interproscan_dir)

    // ── Stage 7a: GTDB-tk taxonomy ────────────────────────────────────────────
    GTDBTK(params.sample,
           hq_bins_ch.collect(),
           mq_bins_ch.collect(),
           gtdbtk_db_ch)

    // ── Stage 7b: Prodigal gene prediction ────────────────────────────────────
    PRODIGAL(params.sample,
             hq_bins_ch.collect(),
             mq_bins_ch.collect())

    // ── Stage 7c: InterProScan functional annotation ──────────────────────────
    // Setup: patch Java memory to 64G
    INTERPROSCAN_SETUP(params.sample, ipr_dir_ch)

    // Run HQ and MQ separately (prevents H2 DB corruption)
    INTERPROSCAN_HQ(params.sample,
                    PRODIGAL.out.faa_files.filter { it.name =~ /MB_bin\.(6|13|22|69|75|78)|MX_bin\.(018|022)/ }.collect(),
                    INTERPROSCAN_SETUP.out.ipr_patched)

    INTERPROSCAN_MQ(params.sample,
                    PRODIGAL.out.faa_files.filter { it.name =~ /MB_bin\.(11|14|21|29)|MX_bin\.020_sub/ }.collect(),
                    INTERPROSCAN_SETUP.out.ipr_patched)

    // Merge HQ + MQ results
    MERGE_INTERPROSCAN(params.sample,
                       INTERPROSCAN_HQ.out.hq_results,
                       INTERPROSCAN_MQ.out.mq_results)

    // ── Stage 8: Excel Report ─────────────────────────────────────────────────
    INSTALL_DEPS(params.sample)

    REPORT(params.sample,
           quality_report_ch,
           GTDBTK.out.taxonomy_tsv,
           coverm_ch,
           MERGE_INTERPROSCAN.out.merged_tsv,
           INSTALL_DEPS.out.deps_ready)

    // ── Summary ───────────────────────────────────────────────────────────────
    REPORT.out.excel_report.view { "🎉 Annotation complete! Report: $it" }
}
