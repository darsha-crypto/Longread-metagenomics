// Stage 8 — Excel Report Generation
// Validated: April 28, 2026
// Tools: Python + openpyxl + pandas
// Exact params from Stage7_8_Annotation_Report_Runbook_FINAL.md
// Output: 21-sheet Excel (7 summary + 13 per-MAG annotation sheets)
// Professional deep navy/teal/slate color palette + auto-fit columns

process INSTALL_DEPS {
    tag "$sample"

    output:
    val true, emit: deps_ready

    script:
    """
    pip install openpyxl pandas -q
    python3 -c "import openpyxl, pandas; print('deps OK')"
    """
}

process REPORT {
    container "quay.io/biocontainers/python:3.11--1"
    tag "$sample"/${task.ext.sample ?: params.sample}/"Stage8_Excel" }, mode: "copy"

    input:
    val  sample
    path quality_report      // CheckM2 quality_report.tsv
    path taxonomy_tsv        // GTDB-tk gtdbtk.bac120.summary.tsv
    path coverage_tsv        // CoverM coverage_results.tsv
    path interproscan_tsv    // merged all_bins_interproscan.tsv
    val  deps_ready

    output:
    path "${sample}_MAG_report_FINAL.xlsx", emit: excel_report

    script:
    """
    python3 << 'PYEOF'
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

# ─── COLORS ───────────────────────────────────────────────────────────────────
C = {
    "README":     "1B2631",
    "QUALITY":    "0E6655",
    "TAXONOMY":   "154360",
    "ABUNDANCE":  "1A5276",
    "FUNCTIONAL": "512E5F",
    "SUMMARY":    "2E4057",
    "HQ_ONLY":    "145A32",
    "WHITE":      "FFFFFF",
    "LIGHT_GREY": "F2F3F4",
    "ALT_GREEN":  "E8F8F5",
    "ALT_BLUE":   "EAF2FF",
    "ALT_PURPLE": "F5EEF8",
    "ALT_TEAL":   "E8F6F3",
}

def fill(h): return PatternFill("solid", start_color=h, fgColor=h)
def hfont(): return Font(name="Calibri", bold=True, color="FFFFFF", size=11)
def tfont(): return Font(name="Calibri", bold=True, color="FFFFFF", size=13)
def dfont(bold=False): return Font(name="Calibri", size=10, bold=bold)
def ctr(): return Alignment(horizontal="center", vertical="center", wrap_text=True)
def lft(): return Alignment(horizontal="left", vertical="center", wrap_text=False)
def bdr():
    s = Side(style="thin", color="BDC3C7")
    return Border(left=s, right=s, top=s, bottom=s)

def auto_width(ws, min_w=8, max_w=60):
    for col in ws.columns:
        max_len = max((len(str(c.value)) for c in col if c.value), default=8)
        ws.column_dimensions[get_column_letter(col[0].column)].width = min(max_w, max(min_w, max_len + 2))

def title_row(ws, text, color, ncols):
    ws.row_dimensions[1].height = 36
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=ncols)
    c = ws.cell(1, 1, text)
    c.font = tfont(); c.fill = fill(color); c.alignment = ctr()

def header_row(ws, hdrs, row, color):
    ws.row_dimensions[row].height = 40
    for col, h in enumerate(hdrs, 1):
        c = ws.cell(row, col, h)
        c.font = hfont(); c.fill = fill(color)
        c.alignment = ctr(); c.border = bdr()

def data_row(ws, row, vals, alt=False, bg=None):
    ws.row_dimensions[row].height = 22
    bg_c = bg if bg else (C["ALT_GREEN"] if alt else C["WHITE"])
    for col, v in enumerate(vals, 1):
        c = ws.cell(row, col, v)
        c.font = dfont(); c.fill = fill(bg_c)
        c.alignment = lft(); c.border = bdr()

# ─── LOAD DATA ────────────────────────────────────────────────────────────────
print("Loading pipeline results...")

# CheckM2
checkm2 = pd.read_csv("${quality_report}", sep="\\t")
checkm2.columns = checkm2.columns.str.strip()

# GTDB-tk
gtdb = pd.read_csv("${taxonomy_tsv}", sep="\\t")
gtdb.columns = gtdb.columns.str.strip()

# CoverM
coverm = pd.read_csv("${coverage_tsv}", sep="\\t")
coverm.columns = coverm.columns.str.strip()

# InterProScan
print("Loading InterProScan...")
IPR_COLS = ["protein_id","md5","length","database","accession","description",
            "start","end","evalue","status","date","ipr_acc","ipr_desc","go_terms","pathways"]
ipr = pd.read_csv("${interproscan_tsv}", sep="\\t",
                  header=None, names=IPR_COLS, low_memory=False)
ipr["MAG"] = ipr["protein_id"].apply(
    lambda x: x.split("__")[0] if "__" in str(x) else "unknown")

print(f"CheckM2: {len(checkm2)} MAGs")
print(f"GTDB-tk: {len(gtdb)} MAGs")
print(f"CoverM: {len(coverm)} entries")
print(f"InterProScan: {len(ipr):,} annotations")

# ─── PARSE TAXONOMY ───────────────────────────────────────────────────────────
def parse_gtdb(classification):
    parts = {"p":"","c":"","o":"","f":"","g":"","s":""}
    if pd.isna(classification):
        return parts
    for item in str(classification).split(";"):
        item = item.strip()
        for key in parts:
            if item.startswith(key+"__"):
                parts[key] = item[3:]
    return parts

gtdb["phylum"]  = gtdb["classification"].apply(lambda x: parse_gtdb(x)["p"])
gtdb["class_"]  = gtdb["classification"].apply(lambda x: parse_gtdb(x)["c"])
gtdb["order"]   = gtdb["classification"].apply(lambda x: parse_gtdb(x)["o"])
gtdb["family"]  = gtdb["classification"].apply(lambda x: parse_gtdb(x)["f"])
gtdb["genus"]   = gtdb["classification"].apply(lambda x: parse_gtdb(x)["g"])
gtdb["species"] = gtdb["classification"].apply(lambda x: parse_gtdb(x)["s"])

# ─── PARSE COVERM ─────────────────────────────────────────────────────────────
# CoverM columns: Genome, RA, Mean, CovFrac
cov_cols = coverm.columns.tolist()
genome_col = cov_cols[0]
ra_col    = [c for c in cov_cols if "Relative" in c][0]   if any("Relative" in c for c in cov_cols) else cov_cols[1]
mean_col  = [c for c in cov_cols if "Mean"     in c][0]   if any("Mean"     in c for c in cov_cols) else cov_cols[2]
frac_col  = [c for c in cov_cols if "Covered"  in c][0]   if any("Covered"  in c for c in cov_cols) else cov_cols[3]

coverm_dict = {}
for _, row in coverm.iterrows():
    mag = str(row[genome_col]).replace(".fa","").replace(".fasta","")
    coverm_dict[mag] = (row[ra_col], row[mean_col], row[frac_col])

# ─── QUALITY TIERS ────────────────────────────────────────────────────────────
comp_col   = [c for c in checkm2.columns if "Completeness" in c][0]
contam_col = [c for c in checkm2.columns if "Contamination" in c][0]
name_col   = checkm2.columns[0]

checkm2["Quality"] = checkm2.apply(
    lambda r: "HQ" if r[comp_col]>=90 and r[contam_col]<5
              else ("MQ" if r[comp_col]>=50 and r[contam_col]<10
              else "LQ"), axis=1)

quality_mags = checkm2[checkm2["Quality"].isin(["HQ","MQ"])]

# ─── IPR STATS PER MAG ────────────────────────────────────────────────────────
def mag_ipr_stats(mag):
    d = ipr[ipr["MAG"]==mag]
    n_prot = d["protein_id"].nunique()
    n_ann  = len(d)
    n_pfam = len(d[d["database"]=="Pfam"])
    n_pan  = len(d[d["database"]=="PANTHER"])
    n_ipr  = d[d["ipr_acc"].notna() & (d["ipr_acc"]!="-")]["ipr_acc"].nunique()
    n_go   = d[d["go_terms"].notna() & (d["go_terms"]!="-")]["protein_id"].nunique()
    top3   = " | ".join(d[d["database"]=="Pfam"]["description"].value_counts().head(3).index.tolist()) or "N/A"
    return n_prot, n_ann, n_pfam, n_pan, n_ipr, n_go, top3

ipr_stats = {row[name_col]: mag_ipr_stats(row[name_col])
             for _, row in quality_mags.iterrows()}

# Top 30 IPR domains
top_domains = (ipr[ipr["ipr_acc"].notna() & (ipr["ipr_acc"]!="-")]
               .groupby(["ipr_acc","ipr_desc"])
               .agg(total_hits=("protein_id","count"), n_mags=("MAG","nunique"))
               .reset_index().sort_values("total_hits", ascending=False).head(30))

# ─── BUILD WORKBOOK ───────────────────────────────────────────────────────────
print("Building Excel workbook...")
wb = Workbook()

# ── README ────────────────────────────────────────────────────────────────────
ws0 = wb.active; ws0.title = "README"
ws0.sheet_view.showGridLines = False
title_row(ws0, f"PacBio HiFi Metagenomics — ${sample} | Complete Results | $(date +%B\\ %Y)", C["README"], 3)
readme_items = [
    ("PIPELINE","",""),
    ("Sample ID","${sample}",""),
    ("Quality MAGs", f"{len(quality_mags)} ({len(checkm2[checkm2['Quality']=='HQ'])} HQ + {len(checkm2[checkm2['Quality']=='MQ'])} MQ)", "CheckM2 v1.1.0"),
    ("Taxonomy","GTDB-tk v2.7.1","Reference: r232"),
    ("Functional","InterProScan 5.75", f"{len(ipr):,} annotations"),
    ("Abundance","CoverM v0.7.0",""),
    ("SHEETS","",""),
    ("1_MAG_Quality","CheckM2 quality — all MAGs",""),
    ("2_Taxonomy","GTDB-tk taxonomy",""),
    ("3_Abundance","CoverM relative abundance",""),
    ("4_Functional","InterProScan summary per MAG",""),
    ("5_TopDomains","Top 30 InterPro domains",""),
    ("6_MAG_Summary","Master integrated table",""),
    ("7_HQ_only","High-quality MAGs only",""),
    ("MAG sheets","One sheet per MAG — full annotations",""),
]
for i,(k,v,n) in enumerate(readme_items):
    r=i+3; ws0.row_dimensions[r].height=22
    is_sec = v=="" and n=="" and k not in ("","PIPELINE","SHEETS")
    for col,val in enumerate([k,v,n],1):
        c=ws0.cell(r,col,val)
        if k in ("PIPELINE","SHEETS"):
            c.font=Font(name="Calibri",bold=True,size=10,color="FFFFFF")
            c.fill=fill(C["SUMMARY"])
        else:
            c.font=dfont(bold=(col==1))
            c.fill=fill(C["LIGHT_GREY"] if i%2==0 else C["WHITE"])
        c.alignment=lft(); c.border=bdr()
auto_width(ws0, min_w=20, max_w=70)

# ── 1_MAG_Quality ─────────────────────────────────────────────────────────────
ws1=wb.create_sheet("1_MAG_Quality"); ws1.sheet_view.showGridLines=False
H=["MAG ID","Completeness (%)","Contamination (%)","Quality","Genome Size (Mb)","No. Contigs","GC (%)"]
title_row(ws1,"GENOME QUALITY  ·  CheckM2 v1.1.0  ·  HQ: ≥90% complete <5% contam  ·  MQ: ≥50% <10%",C["QUALITY"],len(H))
header_row(ws1,H,3,C["QUALITY"])
for i,row in enumerate(checkm2.itertuples()):
    mag = getattr(row, name_col.replace(" ","_"), row[1])
    comp = getattr(row, comp_col.replace(" ","_").replace("(","").replace(")","").replace("%",""), 0)
    contam = getattr(row, contam_col.replace(" ","_").replace("(","").replace(")","").replace("%",""), 0)
    qual = row.Quality
    size = round(getattr(row,"Genome_Size__Mbp_",0), 2) if hasattr(row,"Genome_Size__Mbp_") else "N/A"
    ctg  = getattr(row,"Contigs",0) if hasattr(row,"Contigs") else "N/A"
    gc   = round(getattr(row,"GC_Content",0),1) if hasattr(row,"GC_Content") else "N/A"
    data_row(ws1,i+4,[mag,round(comp,2),round(contam,2),qual,size,ctg,gc],
             alt=i%2==1, bg=C["ALT_GREEN"] if i%2==1 else None)
ws1.freeze_panes="A4"; auto_width(ws1,min_w=12,max_w=30)

# ── 2_Taxonomy ────────────────────────────────────────────────────────────────
ws2=wb.create_sheet("2_Taxonomy"); ws2.sheet_view.showGridLines=False
H=["MAG ID","Quality","Phylum","Class","Order","Family","Genus","Species","Method"]
title_row(ws2,"TAXONOMY  ·  GTDB-tk v2.7.1  ·  Reference: r232",C["TAXONOMY"],len(H))
header_row(ws2,H,3,C["TAXONOMY"])
gtdb_dict = {str(r["user_genome"]): r for _,r in gtdb.iterrows()}
for i,row in enumerate(quality_mags.itertuples()):
    mag = str(getattr(row,name_col.replace(" ","_"),row[1]))
    qual = row.Quality
    t = gtdb_dict.get(mag, {})
    data_row(ws2,i+4,[mag,qual,
        t.get("phylum","N/A") if isinstance(t,dict) else getattr(t,"phylum","N/A"),
        t.get("class_","N/A") if isinstance(t,dict) else getattr(t,"class_","N/A"),
        t.get("order","N/A")  if isinstance(t,dict) else getattr(t,"order","N/A"),
        t.get("family","N/A") if isinstance(t,dict) else getattr(t,"family","N/A"),
        t.get("genus","N/A")  if isinstance(t,dict) else getattr(t,"genus","N/A"),
        t.get("species","N/A")if isinstance(t,dict) else getattr(t,"species","N/A"),
        t.get("classification_method","N/A") if isinstance(t,dict) else getattr(t,"classification_method","N/A")],
        alt=i%2==1, bg=C["ALT_BLUE"] if i%2==1 else None)
ws2.freeze_panes="A4"; auto_width(ws2,min_w=12,max_w=35)

# ── 3_Abundance ───────────────────────────────────────────────────────────────
ws3=wb.create_sheet("3_Abundance"); ws3.sheet_view.showGridLines=False
H=["Rank","MAG ID","Quality","Species","Relative Abundance (%)","Mean Coverage (×)","Covered Fraction (%)"]
title_row(ws3,"RELATIVE ABUNDANCE  ·  CoverM v0.7.0  ·  Sorted by abundance",C["ABUNDANCE"],len(H))
header_row(ws3,H,3,C["ABUNDANCE"])
sorted_mags = sorted(quality_mags.itertuples(),
                     key=lambda r: -coverm_dict.get(str(getattr(r,name_col.replace(" ","_"),r[1])),("0",0,0))[1])
for i,row in enumerate(sorted_mags):
    mag = str(getattr(row,name_col.replace(" ","_"),row[1]))
    qual = row.Quality
    ra,cov,frac = coverm_dict.get(mag,(0,0,0))
    t = gtdb_dict.get(mag,{})
    sp = getattr(t,"species","N/A") if not isinstance(t,dict) else t.get("species","N/A")
    data_row(ws3,i+4,[i+1,mag,qual,sp,round(float(ra),4),round(float(cov),1),round(float(frac),1)],
             alt=i%2==1, bg=C["ALT_TEAL"] if i%2==1 else None)
ws3.freeze_panes="A4"; auto_width(ws3,min_w=10,max_w=35)

# ── 4_Functional ──────────────────────────────────────────────────────────────
ws4=wb.create_sheet("4_Functional"); ws4.sheet_view.showGridLines=False
H=["MAG ID","Quality","Species","Annotated Proteins","Total Annotations",
   "Pfam Hits","PANTHER Hits","Unique IPR Acc.","GO-annotated Proteins","Top 3 Pfam Domains"]
title_row(ws4,"FUNCTIONAL ANNOTATION  ·  InterProScan 5.75  ·  7 databases",C["FUNCTIONAL"],len(H))
header_row(ws4,H,3,C["FUNCTIONAL"])
for i,row in enumerate(quality_mags.itertuples()):
    mag = str(getattr(row,name_col.replace(" ","_"),row[1]))
    qual = row.Quality
    t = gtdb_dict.get(mag,{})
    sp = getattr(t,"species","N/A") if not isinstance(t,dict) else t.get("species","N/A")
    s = ipr_stats.get(mag,(0,0,0,0,0,0,"N/A"))
    data_row(ws4,i+4,[mag,qual,sp,s[0],s[1],s[2],s[3],s[4],s[5],s[6]],
             alt=i%2==1, bg=C["ALT_PURPLE"] if i%2==1 else None)
ws4.freeze_panes="A4"; auto_width(ws4,min_w=10,max_w=55)

# ── 5_TopDomains ──────────────────────────────────────────────────────────────
ws5=wb.create_sheet("5_TopDomains"); ws5.sheet_view.showGridLines=False
H=["Rank","InterPro Accession","InterPro Description","Total Hits","No. MAGs"]
title_row(ws5,"TOP 30 InterPro DOMAINS  ·  All MAGs combined",C["FUNCTIONAL"],len(H))
header_row(ws5,H,3,C["FUNCTIONAL"])
for i,row in enumerate(top_domains.itertuples()):
    data_row(ws5,i+4,[i+1,row.ipr_acc,row.ipr_desc,row.total_hits,row.n_mags],
             alt=i%2==1, bg=C["ALT_PURPLE"] if i%2==1 else None)
ws5.freeze_panes="A4"; auto_width(ws5,min_w=10,max_w=60)

# ── 6_MAG_Summary ─────────────────────────────────────────────────────────────
ws6=wb.create_sheet("6_MAG_Summary"); ws6.sheet_view.showGridLines=False
H=["MAG ID","Quality","Completeness (%)","Contamination (%)","Phylum","Genus","Species",
   "Rel. Abundance (%)","Mean Coverage (×)","Total IPR Ann.","Unique IPR Acc."]
title_row(ws6,"MASTER SUMMARY  ·  CheckM2 · GTDB-tk · CoverM · InterProScan",C["SUMMARY"],len(H))
header_row(ws6,H,3,C["SUMMARY"])
sorted_all = sorted(quality_mags.itertuples(),
                    key=lambda r: (0 if r.Quality=="HQ" else 1,
                                   -coverm_dict.get(str(getattr(r,name_col.replace(" ","_"),r[1])),("0",0,0))[1]))
for i,row in enumerate(sorted_all):
    mag = str(getattr(row,name_col.replace(" ","_"),row[1]))
    qual = row.Quality
    comp = round(float(getattr(row,comp_col.replace(" ","_").replace("(","").replace(")","").replace("%",""),0)),2)
    contam = round(float(getattr(row,contam_col.replace(" ","_").replace("(","").replace(")","").replace("%",""),0)),2)
    t = gtdb_dict.get(mag,{})
    ph = getattr(t,"phylum","N/A") if not isinstance(t,dict) else t.get("phylum","N/A")
    ge = getattr(t,"genus","N/A")  if not isinstance(t,dict) else t.get("genus","N/A")
    sp = getattr(t,"species","N/A")if not isinstance(t,dict) else t.get("species","N/A")
    ra,cov,_ = coverm_dict.get(mag,(0,0,0))
    s = ipr_stats.get(mag,(0,0,0,0,0,0,"N/A"))
    data_row(ws6,i+4,[mag,qual,comp,contam,ph,ge,sp,
                      round(float(ra),4),round(float(cov),1),s[1],s[4]],
             alt=i%2==1, bg=C["ALT_BLUE"] if i%2==1 else None)
ws6.freeze_panes="A4"; auto_width(ws6,min_w=10,max_w=35)

# ── 7_HQ_only ─────────────────────────────────────────────────────────────────
ws7=wb.create_sheet("7_HQ_only"); ws7.sheet_view.showGridLines=False
H=["MAG ID","Completeness (%)","Contamination (%)","Phylum","Genus","Species",
   "Rel. Abundance (%)","Mean Coverage (×)","Total IPR Ann.","Top 3 Pfam Domains"]
title_row(ws7,"HIGH-QUALITY MAGs  ·  ≥90% complete  ·  <5% contamination",C["HQ_ONLY"],len(H))
header_row(ws7,H,3,C["HQ_ONLY"])
hq_mags = sorted(quality_mags[quality_mags["Quality"]=="HQ"].itertuples(),
                 key=lambda r: -coverm_dict.get(str(getattr(r,name_col.replace(" ","_"),r[1])),("0",0,0))[1])
for i,row in enumerate(hq_mags):
    mag = str(getattr(row,name_col.replace(" ","_"),row[1]))
    comp = round(float(getattr(row,comp_col.replace(" ","_").replace("(","").replace(")","").replace("%",""),0)),2)
    contam = round(float(getattr(row,contam_col.replace(" ","_").replace("(","").replace(")","").replace("%",""),0)),2)
    t = gtdb_dict.get(mag,{})
    ph = getattr(t,"phylum","N/A") if not isinstance(t,dict) else t.get("phylum","N/A")
    ge = getattr(t,"genus","N/A")  if not isinstance(t,dict) else t.get("genus","N/A")
    sp = getattr(t,"species","N/A")if not isinstance(t,dict) else t.get("species","N/A")
    ra,cov,_ = coverm_dict.get(mag,(0,0,0))
    s = ipr_stats.get(mag,(0,0,0,0,0,0,"N/A"))
    data_row(ws7,i+4,[mag,comp,contam,ph,ge,sp,
                      round(float(ra),4),round(float(cov),1),s[1],s[6]],
             alt=i%2==1, bg=C["ALT_GREEN"] if i%2==1 else None)
ws7.freeze_panes="A4"; auto_width(ws7,min_w=10,max_w=55)

# ── Per-MAG sheets ─────────────────────────────────────────────────────────────
MAG_COLORS = {
    "MB_bin.6":"0E6655","MB_bin.11":"117A65","MB_bin.13":"148F77",
    "MB_bin.14":"17A589","MB_bin.21":"1ABC9C","MB_bin.22":"45B39D",
    "MB_bin.29":"76D7C4","MB_bin.69":"154360","MB_bin.75":"1A5276",
    "MB_bin.78":"1F618D","MX_bin.018":"2471A3","MX_bin.020_sub":"2980B9",
    "MX_bin.022":"512E5F",
}
IPR_H = ["Protein ID","Database","DB Accession","Description",
         "Start","End","E-value","InterPro Accession","InterPro Description","GO Terms"]

print("Building per-MAG sheets...")
for _, row in quality_mags.iterrows():
    mag = str(row[name_col])
    qual = row["Quality"]
    mag_data = ipr[ipr["MAG"]==mag].sort_values(["database","protein_id"]).copy()
    for col in ["ipr_acc","ipr_desc","go_terms"]:
        mag_data[col] = mag_data[col].apply(lambda x: "" if str(x) in ["-","nan","NaN"] else str(x))

    sname = mag.replace("MX_bin.020_sub","MX020_sub")[:31]
    wm = wb.create_sheet(sname)
    wm.sheet_view.showGridLines = False

    color = MAG_COLORS.get(mag, C["SUMMARY"])
    t = gtdb_dict.get(mag,{})
    sp = getattr(t,"species","N/A") if not isinstance(t,dict) else t.get("species","N/A")
    ra,cov,_ = coverm_dict.get(mag,(0,0,0))
    s = ipr_stats.get(mag,(0,0,0,0,0,0,"N/A"))
    comp = round(float(row[comp_col]),2)
    contam = round(float(row[contam_col]),2)

    title_row(wm, f"{mag}  ·  {sp}  ·  {qual}  ·  {comp}% complete  ·  RA: {round(float(ra),2)}%  ·  Coverage: {round(float(cov),1)}×", color, len(IPR_H))

    wm.row_dimensions[2].height = 22
    wm.merge_cells(start_row=2, start_column=1, end_row=2, end_column=len(IPR_H))
    c2 = wm.cell(2,1,f"Annotated proteins: {s[0]:,}  ·  Total: {s[1]:,}  ·  Pfam: {s[2]:,}  ·  PANTHER: {s[3]:,}  ·  Unique IPR: {s[4]:,}  ·  GO proteins: {s[5]:,}")
    c2.font = Font(name="Calibri",size=9,italic=True,color="FFFFFF")
    c2.fill = fill(color); c2.alignment = lft()

    header_row(wm, IPR_H, 3, color)

    for j, r2 in enumerate(mag_data.itertuples()):
        data_row(wm, j+4,
                 [r2.protein_id, r2.database, r2.accession, r2.description,
                  r2.start, r2.end, r2.evalue, r2.ipr_acc, r2.ipr_desc, r2.go_terms],
                 alt=j%2==1, bg="E8F8F5" if j%2==1 else None)

    wm.freeze_panes = "A4"
    auto_width(wm, min_w=8, max_w=50)
    print(f"  ✅ {mag}: {len(mag_data):,} annotations")

# ── SAVE ──────────────────────────────────────────────────────────────────────
out = "${sample}_MAG_report_FINAL.xlsx"
wb.save(out)
print(f"\\n🎉 Report saved: {out}")
print(f"Total sheets: {len(wb.sheetnames)}")
PYEOF
    """
}
