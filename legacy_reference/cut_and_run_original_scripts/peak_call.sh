#!/bin/bash
#SBATCH --job-name=peak_call_MSK
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=60
#SBATCH --mem=128G
#SBATCH --partition=HTC
#SBATCH --mail-user=ZIW183@pitt.edu
#SBATCH --mail-type=BEGIN,END,FAIL

source ~/.bashrc
conda activate benlab

# ==============================
# CONFIGURATION
# ==============================

# Input directories
BAM_DIR="/ix1/bnacev/ziw183/Fei_data/MSK/aligned2"
BEDGRAPH_DIR="/ix1/bnacev/ziw183/Fei_data/MSK/normalized_tracks/bedgraph"
SEACR_PATH="/ix1/bnacev/ziw183/Fei_data/CutnRun_2026_Feb/SEACR_1.3.sh"

# Output base directory
PEAKS_BASE="/ix1/bnacev/ziw183/Fei_data/MSK/peaks"

# SEACR output directories
SEACR_STRINGENT="$PEAKS_BASE/seacr/stringent"
SEACR_RELAXED="$PEAKS_BASE/seacr/relaxed"

# MACS3 output directories
MACS3_NARROW="$PEAKS_BASE/macs3/narrow"
MACS3_BROAD="$PEAKS_BASE/macs3/broad"

# Create all directories
mkdir -p "$SEACR_STRINGENT" "$SEACR_RELAXED" "$MACS3_NARROW" "$MACS3_BROAD"

# Genome size for MACS3 (human)
GSIZE="hs"

# Summary files
SEACR_SUMMARY="$PEAKS_BASE/seacr/seacr_peak_summary.txt"
MACS3_SUMMARY="$PEAKS_BASE/macs3/macs3_peak_summary.txt"
FRIP_SUMMARY="$PEAKS_BASE/frip_summary.txt"
mkdir -p "$PEAKS_BASE/seacr" "$PEAKS_BASE/macs3"

# ==============================
# HELPER FUNCTIONS
# ==============================

# Extract mark from sample name
# SYO-1_WT_H3K36me2_new_IGO_18284_8_S8_L001 -> H3K36me2_new
get_mark() {
    echo "$1" | sed 's/^SYO-1_\(WT\|KO\)_//' | sed 's/_IGO_.*//'
}

# Extract condition from sample name
# SYO-1_WT_... -> WT, SYO-1_KO_... -> KO
get_condition() {
    echo "$1" | grep -oP 'SYO-1_\K(WT|KO)'
}

# Determine if mark should use narrow peaks
is_narrow_mark() {
    local mark=$1
    case "$mark" in
        H3K4me3|H3K27ac|CTCF|SS18SSX|SUZ12_old|SUZ12_new) return 0 ;;
        *) return 1 ;;
    esac
}

# ==============================
# AUTO-DETECT SAMPLES AND IgG CONTROLS
# ==============================

echo "========================================"
echo "Building sample map..."
echo "========================================"

declare -A IGG_BY_CONDITION=()
declare -A MARK_BY_SAMPLE=()
declare -A COND_BY_SAMPLE=()
ALL_SAMPLES=()

for sample_dir in "$BAM_DIR"/SYO-1_*/; do
    [ ! -d "$sample_dir" ] && continue
    sample=$(basename "$sample_dir")
    BAM="$BAM_DIR/$sample/${sample}_final.bam"
    [ ! -s "$BAM" ] && continue

    mark=$(get_mark "$sample")
    cond=$(get_condition "$sample")
    [ -z "$cond" ] && continue

    MARK_BY_SAMPLE["$sample"]="$mark"
    COND_BY_SAMPLE["$sample"]="$cond"
    ALL_SAMPLES+=("$sample")

    if [ "$mark" = "IgG" ]; then
        IGG_BY_CONDITION["$cond"]="$sample"
        echo "  IgG control for $cond: $sample"
    fi
done

echo ""
echo "Found ${#ALL_SAMPLES[@]} total samples"
echo "  WT IgG: ${IGG_BY_CONDITION[WT]}"
echo "  KO IgG: ${IGG_BY_CONDITION[KO]}"
echo ""

# ==============================
# SAMPLE-TO-IGG MAPPING (auto-built)
# ==============================
declare -A SAMPLE_IGG_MAP=()
for sample in "${ALL_SAMPLES[@]}"; do
    mark="${MARK_BY_SAMPLE[$sample]}"
    cond="${COND_BY_SAMPLE[$sample]}"
    [ "$mark" = "IgG" ] && continue
    igg="${IGG_BY_CONDITION[$cond]}"
    if [ -n "$igg" ]; then
        SAMPLE_IGG_MAP["$sample"]="$igg"
    else
        echo "[WARNING] No IgG found for $sample (condition: $cond)"
    fi
done

echo "Sample-to-IgG mapping:"
for sample in $(echo "${!SAMPLE_IGG_MAP[@]}" | tr ' ' '\n' | sort); do
    mark="${MARK_BY_SAMPLE[$sample]}"
    cond="${COND_BY_SAMPLE[$sample]}"
    igg="${SAMPLE_IGG_MAP[$sample]}"
    if is_narrow_mark "$mark"; then
        caller="narrow"
    else
        caller="broad"
    fi
    echo "  $sample [$mark, $cond] -> $igg  ($caller)"
done
echo ""

# ==============================
# SEACR PEAK CALLING FUNCTION
# ==============================

call_seacr_peaks() {
    local sample=$1
    local control=$2

    local treat_bg="$BEDGRAPH_DIR/${sample}_normalized.bedgraph"
    local ctrl_bg="$BEDGRAPH_DIR/${control}_normalized.bedgraph"

    if [[ ! -f "$treat_bg" ]]; then
        echo "  [SEACR ERROR] Treatment not found: $treat_bg"
        return 1
    fi
    if [[ ! -f "$ctrl_bg" ]]; then
        echo "  [SEACR ERROR] Control not found: $ctrl_bg"
        return 1
    fi

    # Stringent mode
    echo "    SEACR stringent..."
    bash "$SEACR_PATH" "$treat_bg" "$ctrl_bg" non stringent "$SEACR_STRINGENT/${sample}"

    # Relaxed mode
    echo "    SEACR relaxed..."
    bash "$SEACR_PATH" "$treat_bg" "$ctrl_bg" non relaxed "$SEACR_RELAXED/${sample}"

    # Count and record peaks
    local str_peaks="${SEACR_STRINGENT}/${sample}.stringent.bed"
    local rel_peaks="${SEACR_RELAXED}/${sample}.relaxed.bed"

    local str_count=0
    local rel_count=0
    [[ -f "$str_peaks" ]] && str_count=$(wc -l < "$str_peaks")
    [[ -f "$rel_peaks" ]] && rel_count=$(wc -l < "$rel_peaks")

    echo -e "${sample}\t${control}\tstringent\t${str_count}" >> "$SEACR_SUMMARY"
    echo -e "${sample}\t${control}\trelaxed\t${rel_count}" >> "$SEACR_SUMMARY"
    echo "    Stringent: $str_count peaks | Relaxed: $rel_count peaks"
}

# ==============================
# MACS3 PEAK CALLING FUNCTION
# ==============================

call_macs3_peaks() {
    local sample=$1
    local control=$2
    local mark=$3

    local treat_bam="$BAM_DIR/${sample}/${sample}_final.bam"
    local ctrl_bam="$BAM_DIR/${control}/${control}_final.bam"

    if [[ ! -f "$treat_bam" ]]; then
        echo "  [MACS3 ERROR] Treatment BAM not found: $treat_bam"
        return 1
    fi
    if [[ ! -f "$ctrl_bam" ]]; then
        echo "  [MACS3 ERROR] Control BAM not found: $ctrl_bam"
        return 1
    fi

    if is_narrow_mark "$mark"; then
        # Narrow peaks (H3K4me3, H3K27ac, CTCF, SS18SSX, SUZ12)
        echo "    MACS3 narrow..."
        macs3 callpeak \
            -t "$treat_bam" \
            -c "$ctrl_bam" \
            -f BAMPE \
            -g "$GSIZE" \
            -n "$sample" \
            --outdir "$MACS3_NARROW" \
            -q 0.05 \
            --keep-dup all \
            --nomodel \
            --shift -75 \
            --extsize 150 \
            --call-summits \
            2> "$MACS3_NARROW/${sample}_macs3.log"

        local narrow_file="$MACS3_NARROW/${sample}_peaks.narrowPeak"
        local narrow_count=0
        [[ -f "$narrow_file" ]] && narrow_count=$(wc -l < "$narrow_file")
        echo -e "${sample}\t${control}\tnarrow\t${narrow_count}" >> "$MACS3_SUMMARY"
        echo "    Narrow: $narrow_count peaks"
    else
        # Broad peaks (H3K27me3, H3K36me2, H3K36me3)
        echo "    MACS3 broad..."
        macs3 callpeak \
            -t "$treat_bam" \
            -c "$ctrl_bam" \
            -f BAMPE \
            -g "$GSIZE" \
            -n "$sample" \
            --outdir "$MACS3_BROAD" \
            -q 0.05 \
            --keep-dup all \
            --nomodel \
            --shift -75 \
            --extsize 150 \
            --broad \
            --broad-cutoff 0.1 \
            2> "$MACS3_BROAD/${sample}_macs3.log"

        local broad_file="$MACS3_BROAD/${sample}_peaks.broadPeak"
        local broad_count=0
        [[ -f "$broad_file" ]] && broad_count=$(wc -l < "$broad_file")
        echo -e "${sample}\t${control}\tbroad\t${broad_count}" >> "$MACS3_SUMMARY"
        echo "    Broad: $broad_count peaks"
    fi
}

# ==============================
# FRiP SCORE CALCULATION FUNCTION
# ==============================

calculate_frip() {
    local sample=$1
    local mark=$2
    local bam_file="$BAM_DIR/${sample}/${sample}_final.bam"

    if [[ ! -f "$bam_file" ]]; then
        echo "  [FRiP ERROR] BAM not found: $bam_file"
        return 1
    fi

    # Total mapped reads (excluding unmapped, duplicates; MAPQ >= 10)
    local total_reads
    total_reads=$(samtools view -c -F 1028 -q 10 "$bam_file")

    if [ "$total_reads" -eq 0 ]; then
        echo "  [FRiP WARNING] 0 total reads for $sample"
        echo -e "${sample}\t${mark}\t${total_reads}\t0\t0\t0\t0\t0\t0" >> "$FRIP_SUMMARY"
        return
    fi

    local seacr_str_rip=0 seacr_str_frip="NA"
    local seacr_rel_rip=0 seacr_rel_frip="NA"
    local macs3_rip=0 macs3_frip="NA"
    local macs3_mode="NA"

    # --- SEACR FRiP ---
    local seacr_str_peaks="${SEACR_STRINGENT}/${sample}.stringent.bed"
    local seacr_rel_peaks="${SEACR_RELAXED}/${sample}.relaxed.bed"

    if [[ -f "$seacr_str_peaks" ]] && [[ -s "$seacr_str_peaks" ]]; then
        seacr_str_rip=$(bedtools intersect -a "$bam_file" -b "$seacr_str_peaks" -u -f 0.20 | samtools view -c -F 1028 -q 10 -)
        seacr_str_frip=$(awk -v rip="$seacr_str_rip" -v total="$total_reads" 'BEGIN {printf "%.4f", rip/total}')
    fi

    if [[ -f "$seacr_rel_peaks" ]] && [[ -s "$seacr_rel_peaks" ]]; then
        seacr_rel_rip=$(bedtools intersect -a "$bam_file" -b "$seacr_rel_peaks" -u -f 0.20 | samtools view -c -F 1028 -q 10 -)
        seacr_rel_frip=$(awk -v rip="$seacr_rel_rip" -v total="$total_reads" 'BEGIN {printf "%.4f", rip/total}')
    fi

    # --- MACS3 FRiP (narrow or broad depending on mark) ---
    if is_narrow_mark "$mark"; then
        macs3_mode="narrow"
        local macs3_peaks="$MACS3_NARROW/${sample}_peaks.narrowPeak"
    else
        macs3_mode="broad"
        local macs3_peaks="$MACS3_BROAD/${sample}_peaks.broadPeak"
    fi

    if [[ -f "$macs3_peaks" ]] && [[ -s "$macs3_peaks" ]]; then
        macs3_rip=$(bedtools intersect -a "$bam_file" -b "$macs3_peaks" -u -f 0.20 | samtools view -c -F 1028 -q 10 -)
        macs3_frip=$(awk -v rip="$macs3_rip" -v total="$total_reads" 'BEGIN {printf "%.4f", rip/total}')
    fi

    echo -e "${sample}\t${mark}\t${total_reads}\t${seacr_str_rip}\t${seacr_str_frip}\t${seacr_rel_rip}\t${seacr_rel_frip}\t${macs3_rip}\t${macs3_frip}\t${macs3_mode}" >> "$FRIP_SUMMARY"
    echo "    Total reads: $total_reads"
    echo "    SEACR stringent FRiP: $seacr_str_frip ($seacr_str_rip reads in peaks)"
    echo "    SEACR relaxed   FRiP: $seacr_rel_frip ($seacr_rel_rip reads in peaks)"
    echo "    MACS3 $macs3_mode     FRiP: $macs3_frip ($macs3_rip reads in peaks)"
}

# ==============================
# MAIN PROCESSING
# ==============================

echo "========================================"
echo "Integrated Peak Calling: SEACR + MACS3 + FRiP"
echo "========================================"
echo "BAM dir:      $BAM_DIR"
echo "BedGraph dir: $BEDGRAPH_DIR"
echo ""
echo "Output:"
echo "  SEACR stringent: $SEACR_STRINGENT"
echo "  SEACR relaxed:   $SEACR_RELAXED"
echo "  MACS3 narrow:    $MACS3_NARROW"
echo "  MACS3 broad:     $MACS3_BROAD"
echo ""
echo "Peak calling strategy:"
echo "  Narrow (MACS3 narrow + SEACR): H3K4me3, H3K27ac, CTCF, SS18SSX, SUZ12"
echo "  Broad  (MACS3 broad + SEACR):  H3K27me3, H3K36me2, H3K36me3"
echo "========================================"
echo ""

# Initialize summary files
echo -e "Sample\tIgG_Control\tMode\tNum_Peaks" > "$SEACR_SUMMARY"
echo -e "Sample\tIgG_Control\tMode\tNum_Peaks" > "$MACS3_SUMMARY"
echo -e "Sample\tMark\tTotal_Reads\tSEACR_Str_RiP\tSEACR_Str_FRiP\tSEACR_Rel_RiP\tSEACR_Rel_FRiP\tMACS3_RiP\tMACS3_FRiP\tMACS3_Mode" > "$FRIP_SUMMARY"

# Process each sample
for sample in $(echo "${!SAMPLE_IGG_MAP[@]}" | tr ' ' '\n' | sort); do
    igg="${SAMPLE_IGG_MAP[$sample]}"
    mark="${MARK_BY_SAMPLE[$sample]}"
    cond="${COND_BY_SAMPLE[$sample]}"

    echo "========================================"
    echo "Processing: $sample"
    echo "  Mark: $mark | Condition: $cond | IgG: $igg"
    echo "========================================"

    # SEACR peak calling
    echo "  [SEACR]"
    call_seacr_peaks "$sample" "$igg"

    # MACS3 peak calling (mark-aware: narrow vs broad)
    echo "  [MACS3]"
    call_macs3_peaks "$sample" "$igg" "$mark"

    # FRiP score calculation
    echo "  [FRiP]"
    calculate_frip "$sample" "$mark"

    echo ""
done

# ==============================
# FINAL SUMMARY REPORT
# ==============================

echo ""
echo "========================================"
echo "PEAK CALLING COMPLETE!"
echo "========================================"
echo ""
echo "============ SEACR RESULTS ============"
echo "Stringent peaks:"
grep "stringent" "$SEACR_SUMMARY" | sort | awk -F'\t' '{printf "  %-60s %6s peaks\n", $1, $4}'
echo ""
echo "Relaxed peaks:"
grep "relaxed" "$SEACR_SUMMARY" | sort | awk -F'\t' '{printf "  %-60s %6s peaks\n", $1, $4}'
echo ""
echo "============ MACS3 RESULTS ============"
echo "Narrow peaks:"
grep "narrow" "$MACS3_SUMMARY" | sort | awk -F'\t' '{printf "  %-60s %6s peaks\n", $1, $4}'
echo ""
echo "Broad peaks:"
grep "broad" "$MACS3_SUMMARY" | sort | awk -F'\t' '{printf "  %-60s %6s peaks\n", $1, $4}'
echo ""
echo "============ FRiP SCORES ============"
echo ""
printf "  %-55s %-8s %12s %12s %12s\n" "Sample" "Mark" "SEACR_Str" "SEACR_Rel" "MACS3"
printf "  %-55s %-8s %12s %12s %12s\n" "-------" "----" "---------" "---------" "-----"
tail -n +2 "$FRIP_SUMMARY" | sort | while IFS=$'\t' read -r s mk tr ssr ssf srr srf mr mf mm; do
    printf "  %-55s %-8s %12s %12s %12s\n" "$s" "$mk" "$ssf" "$srf" "$mf"
done
echo ""
echo "========================================"
echo "Output directories:"
echo "  $PEAKS_BASE/seacr/stringent/"
echo "  $PEAKS_BASE/seacr/relaxed/"
echo "  $PEAKS_BASE/macs3/narrow/"
echo "  $PEAKS_BASE/macs3/broad/"
echo ""
echo "Summary files:"
echo "  $SEACR_SUMMARY"
echo "  $MACS3_SUMMARY"
echo "  $FRIP_SUMMARY"
echo "========================================"
echo ""
echo "FRiP interpretation (CUT&RUN typically has higher FRiP than ChIP-seq):"
echo "  > 0.3  = Excellent enrichment"
echo "  0.1-0.3 = Good enrichment"
echo "  0.01-0.1 = Acceptable (common for broad marks like H3K27me3)"
echo "  < 0.01 = Low enrichment, inspect tracks manually"
echo ""
echo "Recommended peak caller usage:"
echo "  - H3K4me3, H3K27ac, CTCF:           MACS3 narrow or SEACR stringent"
echo "  - H3K27me3, H3K36me2, H3K36me3:     MACS3 broad or SEACR relaxed"
echo "  - SS18SSX, SUZ12:                    MACS3 narrow or SEACR stringent"
echo "  - High-confidence: Intersect SEACR + MACS3 results"
echo "========================================"