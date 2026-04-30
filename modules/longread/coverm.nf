process COVERM {
    tag "$sample"
    container "quay.io/biocontainers/coverm:0.7.0--hcb7b614_4"
    publishDir "${params.outdir}/${sample}/09_coverm", mode: 'copy'

    input:
    tuple val(sample), path(hq_bins), path(mq_bins), path(bam), path(bai)

    output:
    tuple val(sample), path("coverage_results.tsv"), emit: coverage

    script:
    """
    mkdir -p all_quality_bins
    cp ${hq_bins} all_quality_bins/ 2>/dev/null || true
    cp ${mq_bins} all_quality_bins/ 2>/dev/null || true

    coverm genome \
        --bam-files ${bam} \
        --genome-fasta-files all_quality_bins/*.fa \
        --methods relative_abundance mean covered_fraction \
        --min-covered-fraction 0 \
        --output-file coverage_results.tsv \
        --threads ${task.cpus}
    """
}
