process ASSEMBLY {
    tag "$sample"
    container "quay.io/biocontainers/flye:2.9.6--py313h7fbb527_1"
    publishDir "${params.outdir}/${sample}/04_assembly", mode: 'copy'

    input:
    tuple val(sample), path(filtered_reads)

    output:
    tuple val(sample), path("assembly.fasta"), emit: assembly
    tuple val(sample), path("flye_out/*"),     emit: flye_logs

    script:
    """
    flye \
        --pacbio-hifi ${filtered_reads} \
        --meta \
        --threads ${task.cpus} \
        --out-dir flye_out
    cp flye_out/assembly.fasta .
    """
}

process FILTER_CONTIGS {
    tag "$sample"
    container "quay.io/biocontainers/seqkit:2.13.0--he881be0_0"
    publishDir "${params.outdir}/${sample}/04_assembly", mode: 'copy'

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("${sample}_assembly_min1500.fasta"), emit: filtered_assembly

    script:
    """
    seqkit seq \
        --min-len ${params.min_contig_len} \
        ${assembly} > ${sample}_assembly_min1500.fasta
    """
}

process QUAST {
    tag "$sample"
    container "quay.io/biocontainers/quast:5.3.0--py313pl5321h5ca1c30_2"
    publishDir "${params.outdir}/${sample}/05_quast", mode: 'copy'

    input:
    tuple val(sample), path(assembly)

    output:
    tuple val(sample), path("quast_out/*"), emit: quast_report

    script:
    """
    quast \
        ${assembly} \
        --threads ${task.cpus} \
        --output-dir quast_out \
        --min-contig ${params.min_contig_len}
    """
}
