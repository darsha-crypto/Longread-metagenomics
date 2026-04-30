process QC_RAW {
    tag "$sample"
    container "quay.io/biocontainers/nanoplot:1.46.2--pyhdfd78af_1"
    publishDir "${params.outdir}/${sample}/01_qc_raw", mode: 'copy'

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("qc_raw/*"), emit: reports

    script:
    """
    NanoPlot \
        --fastq ${reads} \
        --outdir qc_raw \
        --threads ${task.cpus} \
        --title "${sample}_Raw_PacBio_HiFi" \
        --plots dot kde \
        --format png
    """
}

process FILTER_READS {
    tag "$sample"
    container "quay.io/biocontainers/filtlong:0.2.1--hdcf5f25_4"
    publishDir "${params.outdir}/${sample}/02_filtered", mode: 'copy'

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("${sample}.filtered.fastq.gz"), emit: filtered_reads

    script:
    """
    filtlong \
        --min_length 1000 \
        --min_mean_q 90 \
        --target_bases 14000000000 \
        ${reads} | gzip > ${sample}.filtered.fastq.gz
    """
}

process QC_FILTERED {
    tag "$sample"
    container "quay.io/biocontainers/nanoplot:1.46.2--pyhdfd78af_1"
    publishDir "${params.outdir}/${sample}/03_qc_filtered", mode: 'copy'

    input:
    tuple val(sample), path(filtered_reads)

    output:
    tuple val(sample), path("qc_filtered/*"), emit: reports

    script:
    """
    NanoPlot \
        --fastq ${filtered_reads} \
        --outdir qc_filtered \
        --threads ${task.cpus} \
        --title "${sample}_Filtered_PacBio_HiFi" \
        --plots dot kde \
        --format png
    """
}
