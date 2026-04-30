process MINIMAP2 {
    tag "$sample"
    container "quay.io/biocontainers/minimap2:2.30--h577a1d6_0"
    publishDir "${params.outdir}/${sample}/07_binning", mode: 'copy'

    input:
    tuple val(sample), path(filtered_reads), path(prok_assembly)

    output:
    tuple val(sample), path("${sample}.sorted.bam"),     emit: bam
    tuple val(sample), path("${sample}.sorted.bam.bai"), emit: bai

    script:
    """
    minimap2 \
        -ax map-hifi \
        -t ${task.cpus} \
        ${prok_assembly} \
        ${filtered_reads} \
        | samtools sort \
            -@ ${task.cpus} \
            -o ${sample}.sorted.bam
    samtools index ${sample}.sorted.bam
    """
}

process METABAT2 {
    tag "$sample"
    container "quay.io/biocontainers/metabat2:2.18--h38e344b_2"
    publishDir "${params.outdir}/${sample}/07_binning/metabat2_bins", mode: 'copy'

    input:
    tuple val(sample), path(prok_assembly), path(bam)

    output:
    tuple val(sample), path("MB_bin.*.fa"), emit: bins
    tuple val(sample), path("depth.txt"),   emit: depth

    script:
    """
    jgi_summarize_bam_contig_depths --outputDepth depth.txt ${bam}
    metabat2 -i ${prok_assembly} -a depth.txt -o MB_bin \
        -t ${task.cpus} -m 1500 --seed 42
    """
}

process MAXBIN2 {
    tag "$sample"
    container "quay.io/biocontainers/maxbin2:2.2.7--h503566f_8"
    publishDir "${params.outdir}/${sample}/07_binning/maxbin2_bins", mode: 'copy'

    input:
    tuple val(sample), path(prok_assembly), path(bam)

    output:
    tuple val(sample), path("MX_bin.*.fasta"), emit: bins

    script:
    """
    jgi_summarize_bam_contig_depths --outputDepth depth.txt ${bam}
    awk 'NR>1 {print \$1"\\t"\$3}' depth.txt > coverage.txt
    run_MaxBin.pl -contig ${prok_assembly} -abund coverage.txt \
        -out MX_bin -thread ${task.cpus}
    """
}

process CONCOCT {
    tag "$sample"
    container "quay.io/biocontainers/concoct:1.1.0--py312hb1d17a5_9"
    publishDir "${params.outdir}/${sample}/07_binning/concoct_bins", mode: 'copy'

    input:
    tuple val(sample), path(prok_assembly), path(bam)

    output:
    tuple val(sample), path("concoct_bins/*.fa"), emit: bins

    script:
    """
    cut_up_fasta.py ${prok_assembly} -c 10000 -o 0 --merge_last \
        -b contigs_10k.bed > contigs_10k.fa
    concoct_coverage_table.py contigs_10k.bed ${bam} > coverage_table.tsv
    concoct --composition_file contigs_10k.fa \
        --coverage_file coverage_table.tsv \
        -b concoct_out/ -t ${task.cpus}
    merge_cutup_clustering.py concoct_out/clustering_gt1000.csv > clustering_merged.csv
    mkdir -p concoct_bins
    extract_fasta_bins.py ${prok_assembly} clustering_merged.csv \
        --output_path concoct_bins/
    """
}

process DASTOOL {
    tag "$sample"
    container "quay.io/biocontainers/das_tool:1.1.7--r44hdfd78af_1"
    publishDir "${params.outdir}/${sample}/07_binning/dastool_out", mode: 'copy'

    input:
    tuple val(sample), path(prok_assembly), path(metabat2_bins), path(maxbin2_bins), path(concoct_bins)

    output:
    tuple val(sample), path("dastool_DASTool_bins/*.fa"),   emit: refined_bins
    tuple val(sample), path("dastool_DASTool_summary.tsv"), emit: summary

    script:
    """
    Fasta_to_Contig2Bin.sh -i metabat2_bins/ -e fa    > metabat2.c2b
    Fasta_to_Contig2Bin.sh -i maxbin2_bins/  -e fasta > maxbin2.c2b
    Fasta_to_Contig2Bin.sh -i concoct_bins/  -e fa    > concoct.c2b
    DAS_Tool \
        -i metabat2.c2b,maxbin2.c2b,concoct.c2b \
        -l MetaBAT2,MaxBin2,CONCOCT \
        -c ${prok_assembly} \
        -o dastool \
        --threads ${task.cpus} \
        --score_threshold 0.5 \
        --write_bins \
        --write_unbinned
    """
}
