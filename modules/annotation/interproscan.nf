// Stage 7c — Functional Annotation
// Validated: April 27, 2026
// Tools: InterProScan 5.75-106.0
// Exact params from Stage7_8_Annotation_Report_Runbook_FINAL.md
// ⚠️ CRITICAL: Run HQ and MQ separately — all 26k proteins at once causes H2 DB corruption
// ⚠️ CRITICAL: Disable CDD (-appl flag) — RPSblast causes continuous failures
// ⚠️ CRITICAL: Patch Xmx to 64G before running — default 14G is too low
// ⚠️ Clean headers before running — special characters cause failures

process INTERPROSCAN_SETUP {
    tag "$sample"

    input:
    val  sample
    path interproscan_dir

    output:
    path "${interproscan_dir}", emit: ipr_patched

    script:
    """
    # Patch Java memory from 14G to 64G
    sed -i 's/-Xmx14G/-Xmx64G/g' ${interproscan_dir}/interproscan.sh
    echo "Patched Xmx to 64G"
    grep "Xmx" ${interproscan_dir}/interproscan.sh | grep -v "32M"
    """
}

process INTERPROSCAN_HQ {
    container "quay.io/biocontainers/interproscan:5.59_91.0--hec16e2b_1"
    tag "$sample"/${task.ext.sample ?: params.sample}/"12_interproscan" }, mode: "copy"

    input:
    val  sample
    path hq_faa_files
    path interproscan_dir

    output:
    path "HQ_interproscan.tsv", emit: hq_results

    script:
    """
    # Merge HQ proteins
    cat ${hq_faa_files} > HQ_proteins.faa

    # Clean headers
    awk '
      /^>/ {
        split(\$0, parts, " ")
        id=parts[1]
        gsub(/^>/,"",id)
        gsub(/[^A-Za-z0-9_.-]/,"_",id)
        print ">"id
        next
      }
      { gsub(/\\*/,"",\$0); print }
    ' HQ_proteins.faa > HQ_proteins_clean.faa

    echo "HQ proteins: \$(grep -c '^>' HQ_proteins_clean.faa)"

    # Run InterProScan on HQ
    mkdir -p /tmp/ipr_hq

    ${interproscan_dir}/interproscan.sh \
        -i HQ_proteins_clean.faa \
        -f tsv \
        -dp \
        -goterms \
        -pa \
        -cpu ${task.cpus} \
        --tempdir /tmp/ipr_hq \
        --disable-precalc \
        -appl ${params.ipr_appl} \
        -o HQ_interproscan.tsv
    """
}

process INTERPROSCAN_MQ {
    container "quay.io/biocontainers/interproscan:5.59_91.0--hec16e2b_1"
    tag "$sample"/${task.ext.sample ?: params.sample}/"12_interproscan" }, mode: "copy"

    input:
    val  sample
    path mq_faa_files
    path interproscan_dir

    output:
    path "MQ_interproscan.tsv", emit: mq_results

    script:
    """
    # Merge MQ proteins
    cat ${mq_faa_files} > MQ_proteins.faa

    # Clean headers
    awk '
      /^>/ {
        split(\$0, parts, " ")
        id=parts[1]
        gsub(/^>/,"",id)
        gsub(/[^A-Za-z0-9_.-]/,"_",id)
        print ">"id
        next
      }
      { gsub(/\\*/,"",\$0); print }
    ' MQ_proteins.faa > MQ_proteins_clean.faa

    echo "MQ proteins: \$(grep -c '^>' MQ_proteins_clean.faa)"

    # Run InterProScan on MQ
    mkdir -p /tmp/ipr_mq

    ${interproscan_dir}/interproscan.sh \
        -i MQ_proteins_clean.faa \
        -f tsv \
        -dp \
        -goterms \
        -pa \
        -cpu ${task.cpus} \
        --tempdir /tmp/ipr_mq \
        --disable-precalc \
        -appl ${params.ipr_appl} \
        -o MQ_interproscan.tsv
    """
}

process MERGE_INTERPROSCAN {
    tag "$sample"/${task.ext.sample ?: params.sample}/"12_interproscan" }, mode: "copy"

    input:
    val  sample
    path hq_tsv
    path mq_tsv

    output:
    path "all_bins_interproscan.tsv", emit: merged_tsv

    script:
    """
    cat ${mq_tsv} ${hq_tsv} > all_bins_interproscan.tsv

    echo "Total annotations: \$(wc -l < all_bins_interproscan.tsv)"
    echo "Merged size: \$(ls -lh all_bins_interproscan.tsv)"
    """
}
