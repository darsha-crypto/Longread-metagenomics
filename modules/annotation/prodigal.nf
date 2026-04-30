// Stage 7b — Gene Prediction
// Validated: April 27, 2026
// Tools: Prodigal v2.6.3
// Exact params from Stage7_8_Annotation_Report_Runbook_FINAL.md
// ⚠️ CRITICAL: Always add MAG prefix to contig headers (double underscore __)
// ⚠️ Without prefix, proteins cannot be mapped back to MAGs after merging

process PRODIGAL {
    container "quay.io/biocontainers/prodigal:2.6.3--h577a1d6_11"
    tag "$sample"/${task.ext.sample ?: params.sample}/"11_prodigal" }, mode: "copy"

    input:
    val  sample
    path hq_bins
    path mq_bins

    output:
    path "faa/*.faa",                       emit: faa_files
    path "gff/*.gff",                       emit: gff_files
    path "fna/*.fna",                       emit: fna_files
    path "all_bins_proteins_merged.faa",    emit: merged_proteins

    script:
    """
    mkdir -p faa gff fna all_bins

    # Combine HQ + MQ bins
    cp ${hq_bins} all_bins/ 2>/dev/null || true
    cp ${mq_bins} all_bins/ 2>/dev/null || true

    # Run Prodigal with MAG prefix on each bin
    for fasta in all_bins/*.fa; do
        stem=\$(basename \$fasta .fa)

        # Add MAG name as prefix to contig headers (double underscore separator)
        sed "s/^>/>\${stem}__/" \$fasta > /tmp/\${stem}_prefixed.fa

        prodigal \
            -i /tmp/\${stem}_prefixed.fa \
            -a faa/\${stem}.faa \
            -d fna/\${stem}.fna \
            -f gff \
            -o gff/\${stem}.gff \
            -p meta \
            -q

        rm /tmp/\${stem}_prefixed.fa
        echo "Done: \${stem}"
    done

    # Merge all proteins into one file
    cat faa/*.faa > all_bins_proteins_merged.faa

    # Remove stop codon asterisks
    sed -i 's/\\*//g' all_bins_proteins_merged.faa

    echo "Total proteins: \$(grep -c '^>' all_bins_proteins_merged.faa)"

    # Verify MAG prefix in headers
    echo "Sample headers:"
    grep "^>" all_bins_proteins_merged.faa | head -3
    """
}
