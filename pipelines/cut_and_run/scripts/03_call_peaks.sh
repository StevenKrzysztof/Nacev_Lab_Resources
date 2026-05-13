#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

prepare_run "${1:-}" "${2:-}"
check_sample_sheet_header

require_command samtools
require_command bedtools

# Editable defaults for peak callers. Values can also be overridden in
# config.yaml under peak_calling.* where noted below. SICER2 is disabled by
# default because broad-domain settings should be reviewed for each project.
RUN_SEACR=true
RUN_MACS3=true
RUN_SICER2=false
if config_get_bool "$CONFIG" '.peak_calling.run_seacr' "$RUN_SEACR"; then RUN_SEACR=true; else RUN_SEACR=false; fi
if config_get_bool "$CONFIG" '.peak_calling.run_macs3' "$RUN_MACS3"; then RUN_MACS3=true; else RUN_MACS3=false; fi
if config_get_bool "$CONFIG" '.peak_calling.run_sicer2' "$RUN_SICER2"; then RUN_SICER2=true; else RUN_SICER2=false; fi

SEACR_SCRIPT=$(config_get "$CONFIG" '.software.seacr_script')
SEACR_NORM_MODE=$(config_get "$CONFIG" '.peak_calling.seacr_norm_mode')
SEACR_TRACK_SOURCE=$(config_get "$CONFIG" '.peak_calling.seacr_track_source')
MACS3_GSIZE=$(config_get "$CONFIG" '.peak_calling.macs3_genome_size')
MACS3_Q=$(config_get "$CONFIG" '.peak_calling.macs3_q_value')
MACS3_BROAD_CUTOFF=$(config_get "$CONFIG" '.peak_calling.macs3_broad_cutoff')
MACS3_SHIFT=$(config_get "$CONFIG" '.peak_calling.macs3_shift')
MACS3_EXTSIZE=$(config_get "$CONFIG" '.peak_calling.macs3_extsize')
FRIP_OVERLAP=$(config_get "$CONFIG" '.peak_calling.frip_min_overlap_fraction')
GENOME_BUILD=$(config_get "$CONFIG" '.reference.genome_build')
SICER2_BIN=$(config_get "$CONFIG" '.peak_calling.sicer2_bin')
SICER2_GENOME=$(config_get "$CONFIG" '.peak_calling.sicer2_genome')
EFFECTIVE_GENOME_FRACTION=$(config_get "$CONFIG" '.peak_calling.sicer2_effective_genome_fraction')
SICER2_WINDOW_SIZE=$(config_get "$CONFIG" '.peak_calling.sicer2_window_size')
SICER2_GAP_SIZE=$(config_get "$CONFIG" '.peak_calling.sicer2_gap_size')
SICER2_FRAGMENT_SIZE=$(config_get "$CONFIG" '.peak_calling.sicer2_fragment_size')
SICER2_PVALUE=$(config_get "$CONFIG" '.peak_calling.sicer2_pvalue')
SICER2_FDR=$(config_get "$CONFIG" '.peak_calling.sicer2_fdr')

[[ -n "$SEACR_NORM_MODE" ]] || SEACR_NORM_MODE=non
[[ -n "$SEACR_TRACK_SOURCE" ]] || SEACR_TRACK_SOURCE=spikein
[[ -n "$MACS3_GSIZE" ]] || MACS3_GSIZE=hs
[[ -n "$MACS3_Q" ]] || MACS3_Q=0.05
[[ -n "$MACS3_BROAD_CUTOFF" ]] || MACS3_BROAD_CUTOFF=0.1
[[ -n "$MACS3_SHIFT" ]] || MACS3_SHIFT=-75
[[ -n "$MACS3_EXTSIZE" ]] || MACS3_EXTSIZE=150
[[ -n "$FRIP_OVERLAP" ]] || FRIP_OVERLAP=0.20
[[ -n "$GENOME_BUILD" ]] || GENOME_BUILD=hg38
[[ -n "$SICER2_BIN" ]] || SICER2_BIN=SICER2
[[ -n "$SICER2_GENOME" ]] || SICER2_GENOME="$GENOME_BUILD"
[[ -n "$EFFECTIVE_GENOME_FRACTION" ]] || EFFECTIVE_GENOME_FRACTION=0.74
[[ -n "$SICER2_WINDOW_SIZE" ]] || SICER2_WINDOW_SIZE=200
[[ -n "$SICER2_GAP_SIZE" ]] || SICER2_GAP_SIZE=600
[[ -n "$SICER2_FRAGMENT_SIZE" ]] || SICER2_FRAGMENT_SIZE=150
[[ -n "$SICER2_PVALUE" ]] || SICER2_PVALUE=0.01
[[ -n "$SICER2_FDR" ]] || SICER2_FDR=0.05

if [[ "$RUN_SEACR" == true ]]; then
    require_file "$SEACR_SCRIPT"
fi
if [[ "$RUN_MACS3" == true ]]; then
    require_command macs3
fi
if [[ "$RUN_SICER2" == true ]]; then
    require_command "$SICER2_BIN"
fi

SEACR_STRINGENT="$PEAK_DIR/seacr/stringent"
SEACR_RELAXED="$PEAK_DIR/seacr/relaxed"
MACS3_NARROW="$PEAK_DIR/macs3/narrow"
MACS3_BROAD="$PEAK_DIR/macs3/broad"
SICER2_OUTPUT_DIR="$PEAK_DIR/sicer2"
SICER2_LOG_DIR="$OUTPUT_DIR/logs/sicer2"
mkdir -p "$SEACR_STRINGENT" "$SEACR_RELAXED" "$MACS3_NARROW" "$MACS3_BROAD" "$SICER2_OUTPUT_DIR" "$SICER2_LOG_DIR"

SEACR_SUMMARY="$SUMMARY_DIR/seacr_peak_summary.tsv"
MACS3_SUMMARY="$SUMMARY_DIR/macs3_peak_summary.tsv"
SICER2_SUMMARY="$SUMMARY_DIR/sicer2_peak_summary.tsv"
FRIP_SUMMARY="$SUMMARY_DIR/frip_summary.tsv"
echo -e "sample_id\tcontrol_sample_id\tmode\tnum_peaks" > "$SEACR_SUMMARY"
echo -e "sample_id\tcontrol_sample_id\tmode\tnum_peaks" > "$MACS3_SUMMARY"
echo -e "sample_id\tcontrol_sample_id\tmode\tnum_peaks\toutput_directory" > "$SICER2_SUMMARY"
echo -e "sample_id\ttarget\ttotal_reads\tseacr_stringent_reads_in_peaks\tseacr_stringent_frip\tseacr_relaxed_reads_in_peaks\tseacr_relaxed_frip\tmacs3_reads_in_peaks\tmacs3_frip\tmacs3_mode\tsicer2_reads_in_peaks\tsicer2_frip" > "$FRIP_SUMMARY"

track_for_sample() {
    local sample_id=$1
    if [[ "$SEACR_TRACK_SOURCE" == "cpm" ]]; then
        sample_cpm_bedgraph "$sample_id"
    else
        sample_spikein_bedgraph "$sample_id"
    fi
}

count_lines_if_present() {
    local file=$1
    if [[ -s "$file" ]]; then
        wc -l < "$file" | tr -d ' '
    else
        echo 0
    fi
}

call_seacr() {
    local sample_id=$1
    local control_id=$2
    local treat_bg ctrl_bg
    treat_bg=$(track_for_sample "$sample_id")
    ctrl_bg=$(track_for_sample "$control_id")

    require_file "$treat_bg"
    require_file "$ctrl_bg"

    info "Running SEACR for $sample_id vs $control_id"
    bash "$SEACR_SCRIPT" "$treat_bg" "$ctrl_bg" "$SEACR_NORM_MODE" stringent "$SEACR_STRINGENT/$sample_id"
    bash "$SEACR_SCRIPT" "$treat_bg" "$ctrl_bg" "$SEACR_NORM_MODE" relaxed "$SEACR_RELAXED/$sample_id"

    stringent_file="$SEACR_STRINGENT/$sample_id.stringent.bed"
    relaxed_file="$SEACR_RELAXED/$sample_id.relaxed.bed"
    echo -e "${sample_id}\t${control_id}\tstringent\t$(count_lines_if_present "$stringent_file")" >> "$SEACR_SUMMARY"
    echo -e "${sample_id}\t${control_id}\trelaxed\t$(count_lines_if_present "$relaxed_file")" >> "$SEACR_SUMMARY"
}

call_macs3() {
    local sample_id=$1
    local control_id=$2
    local peak_type=$3
    local treat_bam control_bam
    treat_bam=$(sample_bam "$sample_id")
    control_bam=$(sample_bam "$control_id")
    require_file "$treat_bam"
    require_file "$control_bam"

    if [[ "$peak_type" == "broad" ]]; then
        info "Running MACS3 broad for $sample_id vs $control_id"
        macs3 callpeak -t "$treat_bam" -c "$control_bam" -f BAMPE -g "$MACS3_GSIZE" -n "$sample_id" --outdir "$MACS3_BROAD" -q "$MACS3_Q" --keep-dup all --nomodel --shift "$MACS3_SHIFT" --extsize "$MACS3_EXTSIZE" --broad --broad-cutoff "$MACS3_BROAD_CUTOFF" 2> "$MACS3_BROAD/$sample_id.macs3.log"
        peak_file="$MACS3_BROAD/${sample_id}_peaks.broadPeak"
        echo -e "${sample_id}\t${control_id}\tbroad\t$(count_lines_if_present "$peak_file")" >> "$MACS3_SUMMARY"
    else
        info "Running MACS3 narrow for $sample_id vs $control_id"
        macs3 callpeak -t "$treat_bam" -c "$control_bam" -f BAMPE -g "$MACS3_GSIZE" -n "$sample_id" --outdir "$MACS3_NARROW" -q "$MACS3_Q" --keep-dup all --nomodel --shift "$MACS3_SHIFT" --extsize "$MACS3_EXTSIZE" --call-summits 2> "$MACS3_NARROW/$sample_id.macs3.log"
        peak_file="$MACS3_NARROW/${sample_id}_peaks.narrowPeak"
        echo -e "${sample_id}\t${control_id}\tnarrow\t$(count_lines_if_present "$peak_file")" >> "$MACS3_SUMMARY"
    fi
}

sicer2_peak_file_for_sample() {
    local sample_id=$1
    local sample_dir="$SICER2_OUTPUT_DIR/$sample_id"
    find "$sample_dir" -type f \( -name "*-island.bed" -o -name "*.island.bed" -o -name "*_island.bed" \) 2>/dev/null | head -1
}

call_sicer2() {
    local sample_id=$1
    local control_id=$2
    local treat_bam control_bam sample_dir log_file peak_file peak_count
    treat_bam=$(sample_bam "$sample_id")
    control_bam=$(sample_bam "$control_id")
    require_file "$treat_bam"
    require_file "$control_bam"

    sample_dir="$SICER2_OUTPUT_DIR/$sample_id"
    log_file="$SICER2_LOG_DIR/$sample_id.sicer2.log"
    mkdir -p "$sample_dir"

    info "Running SICER2 broad-domain calling for $sample_id vs $control_id"
    info "  SICER2 genome: $SICER2_GENOME; window: $SICER2_WINDOW_SIZE; gap: $SICER2_GAP_SIZE; fragment: $SICER2_FRAGMENT_SIZE; p-value placeholder: $SICER2_PVALUE; FDR: $SICER2_FDR"

    # SICER2 command-line flags differ across installations. This template uses
    # the commonly installed SICER2/sicer interface and matched control BAMs:
    #   -s  genome build label recognized by SICER2, e.g. hg38, hg19, mm10
    #   -w  window size used to scan enrichment
    #   -g  gap size used to merge enriched windows into broad domains
    #   -f  estimated fragment size
    #   -egf effective genome fraction/size adjustment
    #   -fdr false-discovery-rate threshold
    # If your installed version uses different option names, run:
    #   SICER2 --help
    # and update this command for the local environment.
    "$SICER2_BIN" \
        -t "$treat_bam" \
        -c "$control_bam" \
        -s "$SICER2_GENOME" \
        -w "$SICER2_WINDOW_SIZE" \
        -rt 1 \
        -f "$SICER2_FRAGMENT_SIZE" \
        -egf "$EFFECTIVE_GENOME_FRACTION" \
        -g "$SICER2_GAP_SIZE" \
        -fdr "$SICER2_FDR" \
        -o "$sample_dir" \
        -cpu "$THREADS" \
        2> "$log_file"

    peak_file=$(sicer2_peak_file_for_sample "$sample_id")
    peak_count=0
    [[ -n "$peak_file" && -s "$peak_file" ]] && peak_count=$(count_lines_if_present "$peak_file")
    echo -e "${sample_id}\t${control_id}\tbroad_domain\t${peak_count}\t${sample_dir}" >> "$SICER2_SUMMARY"
}

frip_for_peak_file() {
    local bam_file=$1
    local peak_file=$2
    local total_reads=$3
    if [[ -s "$peak_file" && "$total_reads" -gt 0 ]]; then
        rip=$(bedtools intersect -a "$bam_file" -b "$peak_file" -u -f "$FRIP_OVERLAP" | samtools view -c -F 1028 -q 10 -)
        frip=$(awk -v rip="$rip" -v total="$total_reads" 'BEGIN {printf "%.4f", rip/total}')
        echo "$rip,$frip"
    else
        echo "0,NA"
    fi
}

calculate_frip() {
    local sample_id=$1
    local target=$2
    local peak_type=$3
    local bam_file total_reads seacr_str seacr_rel macs3_peak macs3_mode sicer2_peak
    bam_file=$(sample_bam "$sample_id")
    require_file "$bam_file"

    total_reads=$(samtools view -c -F 1028 -q 10 "$bam_file")
    seacr_str="$SEACR_STRINGENT/$sample_id.stringent.bed"
    seacr_rel="$SEACR_RELAXED/$sample_id.relaxed.bed"
    if [[ "$peak_type" == "broad" ]]; then
        macs3_mode="broad"
        macs3_peak="$MACS3_BROAD/${sample_id}_peaks.broadPeak"
    else
        macs3_mode="narrow"
        macs3_peak="$MACS3_NARROW/${sample_id}_peaks.narrowPeak"
    fi

    IFS=',' read -r str_rip str_frip <<< "$(frip_for_peak_file "$bam_file" "$seacr_str" "$total_reads")"
    IFS=',' read -r rel_rip rel_frip <<< "$(frip_for_peak_file "$bam_file" "$seacr_rel" "$total_reads")"
    IFS=',' read -r macs_rip macs_frip <<< "$(frip_for_peak_file "$bam_file" "$macs3_peak" "$total_reads")"
    sicer2_peak=$(sicer2_peak_file_for_sample "$sample_id")
    IFS=',' read -r sicer2_rip sicer2_frip <<< "$(frip_for_peak_file "$bam_file" "$sicer2_peak" "$total_reads")"

    echo -e "${sample_id}\t${target}\t${total_reads}\t${str_rip}\t${str_frip}\t${rel_rip}\t${rel_frip}\t${macs_rip}\t${macs_frip}\t${macs3_mode}\t${sicer2_rip}\t${sicer2_frip}" >> "$FRIP_SUMMARY"
}

while IFS=',' read -r sample_id condition target replicate fastq_r1 fastq_r2 control_sample_id normalization_group peak_type include_spikein; do
    [[ -n "$sample_id" ]] || continue
    [[ -n "$control_sample_id" ]] || {
        info "Skipping control/no-control sample for peak calling: $sample_id"
        continue
    }
    [[ "$peak_type" == "narrow" || "$peak_type" == "broad" ]] || die "$sample_id has invalid peak_type '$peak_type'; use narrow or broad"

    info "Peak calling sample: $sample_id; control: $control_sample_id; peak_type: $peak_type"
    [[ "$RUN_SEACR" == true ]] && call_seacr "$sample_id" "$control_sample_id"
    [[ "$RUN_MACS3" == true ]] && call_macs3 "$sample_id" "$control_sample_id" "$peak_type"
    [[ "$RUN_SICER2" == true ]] && call_sicer2 "$sample_id" "$control_sample_id"
    calculate_frip "$sample_id" "$target" "$peak_type"
done < <(read_samples)

info "Peak calling complete"
info "SEACR summary: $SEACR_SUMMARY"
info "MACS3 summary: $MACS3_SUMMARY"
info "SICER2 summary: $SICER2_SUMMARY"
info "FRiP summary:  $FRIP_SUMMARY"
