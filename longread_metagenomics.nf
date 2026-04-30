nextflow.enable.dsl=2

include { QC_RAW; FILTER_READS; QC_FILTERED }             from './modules/longread/qc'
include { ASSEMBLY; FILTER_CONTIGS; QUAST }                from './modules/longread/assembly'
include { KRAKEN2; EXTRACT_PROKARYOTES }                   from './modules/longread/taxonomy'
include { MINIMAP2; METABAT2; MAXBIN2; CONCOCT; DASTOOL }  from './modules/longread/binning'
include { CHECKM2 }                                        from './modules/longread/checkm2'
include { COVERM }                                         from './modules/longread/coverm'

workflow {

    // ── Input channels ────────────────────────────────────────────────────────
    if (params.samplesheet) {
        samples_ch = Channel
            .fromPath(params.samplesheet)
            .splitCsv(header: true)
            .map { row -> tuple(row.sample, file(row.reads)) }
    } else {
        if (!params.reads)  error "Please provide --reads or --samplesheet"
        if (!params.sample) error "Please provide --sample"
        samples_ch = Channel.of(tuple(params.sample, file(params.reads)))
    }

    kraken2_db_ch = Channel.fromPath(params.kraken2_db)
    checkm2_db_ch = Channel.fromPath(params.checkm2_db)

    // ── Stage 1: QC ───────────────────────────────────────────────────────────
    QC_RAW(samples_ch)
    FILTER_READS(samples_ch)
    QC_FILTERED(FILTER_READS.out.filtered_reads)

    // ── Stage 2: Assembly ─────────────────────────────────────────────────────
    ASSEMBLY(FILTER_READS.out.filtered_reads)
    FILTER_CONTIGS(ASSEMBLY.out.assembly)
    QUAST(FILTER_CONTIGS.out.filtered_assembly)

    // ── Stage 3: Taxonomy ─────────────────────────────────────────────────────
    KRAKEN2(FILTER_CONTIGS.out.filtered_assembly, kraken2_db_ch)
    EXTRACT_PROKARYOTES(
        FILTER_CONTIGS.out.filtered_assembly.join(KRAKEN2.out.kraken_output))

    // ── Stage 4: Binning ──────────────────────────────────────────────────────
    MINIMAP2(
        FILTER_READS.out.filtered_reads.join(
            EXTRACT_PROKARYOTES.out.prok_assembly))

    METABAT2(
        EXTRACT_PROKARYOTES.out.prok_assembly.join(MINIMAP2.out.bam))

    MAXBIN2(
        EXTRACT_PROKARYOTES.out.prok_assembly.join(MINIMAP2.out.bam))

    CONCOCT(
        EXTRACT_PROKARYOTES.out.prok_assembly.join(MINIMAP2.out.bam))

    DASTOOL(
        EXTRACT_PROKARYOTES.out.prok_assembly
            .join(METABAT2.out.bins)
            .join(MAXBIN2.out.bins)
            .join(CONCOCT.out.bins))

    // ── Stage 5: CheckM2 ──────────────────────────────────────────────────────
    CHECKM2(DASTOOL.out.refined_bins, checkm2_db_ch)

    // ── Stage 6: CoverM ───────────────────────────────────────────────────────
    COVERM(
        CHECKM2.out.hq_bins
            .join(CHECKM2.out.mq_bins)
            .join(MINIMAP2.out.bam)
            .join(MINIMAP2.out.bai))

    COVERM.out.coverage.view { "✅ Pipeline complete! Sample: ${it[0]}" }
}
