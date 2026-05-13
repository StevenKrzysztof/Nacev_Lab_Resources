#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

prepare_run "${1:-}" "${2:-}"
check_sample_sheet_header

require_command samtools
require_command bedtools
require_command macs3

RUN_SEACR=false
config_get_bool "$CONFIG" '.peak_calling.run_seacr' true && RUN_SEACR=true
RUN_MACS3=false
config_get_bool "$CONFIG" '.peak_calling.run_macs3' true && RUN_MACS3=true
SEACR_SCRIPT=$(config_get "$CONFIG" '.software.seacr_script')
SEACR_NORM_MODE=$(config_get "$CONFIG" '.peak_calling.seacr_norm_mode')
SEACR_TRACK_SOURCE=$(config_get "$CONFIG" '.peak_calling.seacr_track_source')
MACS3_GSIZE=$(config_get "$CONFIG" '.peak_calling.macs3_genome_size')
MACS3_Q=$(config_get "$CONFIG" '.peak_calling.macs3_q_value')
MACS3_BROAD_CUTOFF=$(config_get "$CONFIG" '.peak_calling.macs3_broad_cutoff')
MACS3_SHIFT=$(config_get "$CONFIG" '.peak_calling.macs3_shift')
MACS3_EXTSIZE=$(config_get "$CONFIG" '.peak_calling.macs3_extsize')
FRIP_OVERLAP=$(config_get "$CONFIG" '.peak_calling.frip_min_overlap_fraction')

[[ -n "$SEACR_NORM_MODE" ]] || SEACR_NORM_MODE=non
[[ -n "$SEACR_TRACK_SOURCE" ]] || SEACR_TRACK_SOURCE=spikein
[[ -n "$MACS3_GSIZE" ]] || MACS3_GSIZE=hs
[[ -n "$MACS3_Q" ]] || MACS3_Q=0.05
[[ -n "$MACS3_BROAD_CUTOFF" ]] || MACS3_BROAD_CUTOFF=0.1
[[ -n "$MACS3_SHIFT" ]] || MACS3_SHIFT=-75
[[ -n "$MACS3_EXTSIZE" ]] || MACS3_EXTSIZE=150
[[ -n "$FRIP_OVERLAP" ]] || FRIP_OVERLAP=0.20

if [[ "$RUN_SEACR" == true ]]; then
    require_file "$SEACR_SCRIPT"
fi

SEACR_STRINGENT="$PEAK_DIR/seacr/stringent"
SEACR_RELAXED="$PEAK_DIR/seacr/relaxed"
MACS3_NARROW="$PEAK_DIR/macs3/narrow"
MACS3_BROAD="$PEAK_DIR/macs3/broad"
mkdir -p "$SEACR_STRINGENT" "$SEACR_RELAXED" "$MACS3_NARROW" "$MACS3_BROAD"

SEACR_SUMMARY="$SUMMARY_DIR/seacr_peak_summary.tsv"
MACS3_SUMMARY="$SUMMARY_DIR/macs3_peak_summary.tsv"
FRIP_SUMMARY="$SUMMARY_DIR/frip_summary.tsv"
echo -e "sample_id\tcontrol_sample_id\tmode\tnum_peaks" > "$SEACR_SUMMARY"
echo -e "sample_id\tcontrol_sample_id\tmode\tnum_peaks" > "$MACS3_SUMMARY"
echo -e "sample_id\ttarget\ttotal_reads\tseacr_stringent_reads_in_peaks\tseacr_stringent_frip\tseacr_relaxed_reads_in_peaks\tseacr_relaxed_frip\tmacs3_reads_in_peaks\tmacs3_frip\tmacs3_mode" > "$FRIP_SUMMARY"

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
    local bam_file total_reads seacr_str seacr_rel macs3_peak macs3_mode str_pair rel_pair macs_pair
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

    echo -e "${sample_id}\t${target}\t${total_reads}\t${str_rip}\t${str_frip}\t${rel_rip}\t${rel_frip}\t${macs_rip}\t${macs_frip}\t${macs3_mode}" >> "$FRIP_SUMMARY"
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
    calculate_frip "$sample_id" "$target" "$peak_type"
done < <(read_samples)

info "Peak calling complete"
info "SEACR summary: $SEACR_SUMMARY"
info "MACS3 summary: $MACS3_SUMMARY"
info "FRiP summary:  $FRIP_SUMMARY"
