// Stage 7a — GTDB-tk Taxonomy
// Validated: April 27, 2026
// Tools: GTDB-tk v2.7.1 + r232 database
// Exact params from Stage7_8_Annotation_Report_Runbook_FINAL.md
// ⚠️ CRITICAL: Requires n2-highmem-32 (256GB RAM) — pplacer needs ~135GB
// ⚠️ r232 DB is permanent in bucket — never re-download

process GTDBTK {
    container "quay.io/biocontainers/gtdbtk:2.7.1--pyhdfd78af_1"
    tag "$sample"/${task.ext.sample ?: params.sample}/"10_gtdb" }, mode: "copy"

    input:
    val  sample
    path hq_bins
    path mq_bins
    path gtdbtk_db

    output:
    path "gtdb_out/*",                              emit: gtdb_results
    path "gtdb_out/classify/gtdbtk.bac120.summary.tsv", emit: taxonomy_tsv

    script:
    """
    mkdir -p all_bins gtdb_out

    # Combine HQ + MQ bins
    cp ${hq_bins} all_bins/ 2>/dev/null || true
    cp ${mq_bins} all_bins/ 2>/dev/null || true

    echo "Bins for GTDB-tk: \$(ls all_bins/ | wc -l)"

    # Set DB path
    export GTDBTK_DATA_PATH=${gtdbtk_db}

    # Run GTDB-tk classify
    gtdbtk classify_wf \
        --genome_dir all_bins \
        --out_dir gtdb_out \
        --extension fa \
        --cpus ${task.cpus}
    """
}
