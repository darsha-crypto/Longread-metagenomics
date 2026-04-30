process KRAKEN2 {
    tag "$sample"
    container "quay.io/biocontainers/kraken2:2.17.1--pl5321h077b44d_0"
    publishDir "${params.outdir}/${sample}/06_taxonomy", mode: 'copy'

    input:
    tuple val(sample), path(assembly)
    path kraken2_db

    output:
    tuple val(sample), path("${sample}.kraken2.output"), emit: kraken_output
    tuple val(sample), path("${sample}.kraken2.report"), emit: kraken_report

    script:
    """
    kraken2 \
        --db ${kraken2_db} \
        --threads ${task.cpus} \
        --output ${sample}.kraken2.output \
        --report ${sample}.kraken2.report \
        ${assembly}
    """
}

process EXTRACT_PROKARYOTES {
    tag "$sample"
    container "quay.io/biocontainers/seqkit:2.13.0--he881be0_0"
    publishDir "${params.outdir}/${sample}/06_taxonomy/prok_only", mode: 'copy'

    input:
    tuple val(sample), path(assembly), path(kraken_output)

    output:
    tuple val(sample), path("assembly_prok_only.fasta"), emit: prok_assembly

    script:
    """
    awk '\$1=="C" && (\$3==2 || \$3==2157) {print \$2}' \
        ${kraken_output} > prok_contig_ids.txt

    seqkit grep \
        --pattern-file prok_contig_ids.txt \
        ${assembly} > assembly_prok_only.fasta

    echo "Prokaryotic contigs: \$(grep -c '^>' assembly_prok_only.fasta)"
    """
}
