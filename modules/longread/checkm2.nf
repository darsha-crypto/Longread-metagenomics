process CHECKM2 {
    tag "$sample"
    container "quay.io/biocontainers/checkm2:1.1.0--pyh7e72e81_1"
    publishDir "${params.outdir}/${sample}/08_checkm2", mode: 'copy'

    input:
    tuple val(sample), path(bins)
    path checkm2_db

    output:
    tuple val(sample), path("quality_report.tsv"), emit: quality_report
    tuple val(sample), path("bins_HQ/*.fa"),        emit: hq_bins
    tuple val(sample), path("bins_MQ/*.fa"),        emit: mq_bins

    script:
    """
    mkdir -p bins_dir
    cp ${bins} bins_dir/ 2>/dev/null || true

    checkm2 predict \
        --input bins_dir \
        --output-directory checkm2_out \
        --extension fa \
        --threads ${task.cpus} \
        --database_path ${checkm2_db} \
        --force

    cp checkm2_out/quality_report.tsv .
    mkdir -p bins_HQ bins_MQ

    awk -F'\\t' 'NR>1 && \$2>=90 && \$3<5  {print \$1}' quality_report.tsv > hq_list.txt
    awk -F'\\t' 'NR>1 && \$2>=50 && \$3<10 && !(\$2>=90 && \$3<5) {print \$1}' \
        quality_report.tsv > mq_list.txt

    while read bin; do cp bins_dir/\${bin}.fa bins_HQ/ 2>/dev/null || true; done < hq_list.txt
    while read bin; do cp bins_dir/\${bin}.fa bins_MQ/ 2>/dev/null || true; done < mq_list.txt

    echo "HQ: \$(ls bins_HQ/ | wc -l) MQ: \$(ls bins_MQ/ | wc -l)"
    """
}
