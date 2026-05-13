#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

prepare_run "${1:-}" "${2:-}"
check_sample_sheet_header

require_command cutadapt
require_command bowtie2
require_command samtools
require_command picard
require_command bedtools

BOWTIE2_INDEX=$(config_get "$CONFIG" '.reference.bowtie2_index')
SPIKEIN_INDEX=$(config_get "$CONFIG" '.reference.spikein_bowtie2_index')
BLACKLIST_BED=$(config_get "$CONFIG" '.reference.blacklist_bed')
MIN_MAPQ=$(config_get "$CONFIG" '.alignment.minimum_mapping_quality')
MIN_INSERT=$(config_get "$CONFIG" '.alignment.min_insert_size')
MAX_INSERT=$(config_get "$CONFIG" '.alignment.max_insert_size')
TRIM_FIRST_BP=$(config_get "$CONFIG" '.trimming.trim_first_bp')
MIN_LENGTH=$(config_get "$CONFIG" '.trimming.min_length')
ADAPTER=$(config_get "$CONFIG" '.trimming.adapter_sequence')
SPIKEIN_ENABLED=false
config_get_bool "$CONFIG" '.spikein.enabled' false && SPIKEIN_ENABLED=true
REMOVE_DUPLICATES=false
config_get_bool "$CONFIG" '.alignment.remove_duplicates' true && REMOVE_DUPLICATES=true
REMOVE_BLACKLIST=false
config_get_bool "$CONFIG" '.alignment.remove_blacklist_regions' true && REMOVE_BLACKLIST=true
CLEANUP=false
config_get_bool "$CONFIG" '.alignment.cleanup_intermediate_files' true && CLEANUP=true
REQUIRE_PROPER_PAIR=false
config_get_bool "$CONFIG" '.alignment.require_proper_pair' true && REQUIRE_PROPER_PAIR=true
ALLOW_DOVETAIL=false
config_get_bool "$CONFIG" '.alignment.allow_dovetail' true && ALLOW_DOVETAIL=true

[[ -n "$BOWTIE2_INDEX" ]] || die "Missing reference.bowtie2_index in config"
[[ -n "$MIN_MAPQ" ]] || MIN_MAPQ=30
[[ -n "$MIN_INSERT" ]] || MIN_INSERT=10
[[ -n "$MAX_INSERT" ]] || MAX_INSERT=700
[[ -n "$TRIM_FIRST_BP" ]] || TRIM_FIRST_BP=0
[[ -n "$MIN_LENGTH" ]] || MIN_LENGTH=20
[[ -n "$ADAPTER" ]] || ADAPTER=AGATCGGAAGAG

if [[ "$SPIKEIN_ENABLED" == true && -z "$SPIKEIN_INDEX" ]]; then
    die "spikein.enabled is true but reference.spikein_bowtie2_index is empty"
fi
if [[ "$REMOVE_BLACKLIST" == true ]]; then
    require_file "$BLACKLIST_BED"
fi

SUMMARY_FILE="$SUMMARY_DIR/alignment_and_spikein_summary.tsv"
echo -e "sample_id\tcondition\ttarget\treplicate\tprimary_alignment_rate\tfinal_mapped_reads\tspikein_mapped_reads\tspikein_scale_factor_100k" > "$SUMMARY_FILE"

info "Project: $PROJECT_ID"
info "Output:  $OUTPUT_DIR"
info "Running alignment and filtering from sample sheet: $SAMPLE_SHEET"

while IFS=',' read -r sample_id condition target replicate fastq_r1 fastq_r2 control_sample_id normalization_group peak_type include_spikein; do
    [[ -n "$sample_id" ]] || continue
    info "Processing sample: $sample_id"

    require_file "$fastq_r1"
    require_file "$fastq_r2"

    SAMPLE_OUT="$ALIGN_DIR/$sample_id"
    mkdir -p "$SAMPLE_OUT"

    trimmed_r1="$SAMPLE_OUT/${sample_id}_R1_trimmed.fq.gz"
    trimmed_r2="$SAMPLE_OUT/${sample_id}_R2_trimmed.fq.gz"
    cutadapt_log="$SAMPLE_OUT/cutadapt.log"

    cutadapt_args=(--cut "$TRIM_FIRST_BP" -a "$ADAPTER" -A "$ADAPTER" -m "$MIN_LENGTH")
    if config_get_bool "$CONFIG" '.trimming.trim_poly_a' true; then
        cutadapt_args+=(-a 'A{20}' -A 'A{20}')
    fi
    if config_get_bool "$CONFIG" '.trimming.trim_poly_g' true; then
        cutadapt_args+=(-a 'G{20}' -A 'G{20}')
    fi

    info "  Trimming reads"
    cutadapt "${cutadapt_args[@]}" -o "$trimmed_r1" -p "$trimmed_r2" "$fastq_r1" "$fastq_r2" > "$cutadapt_log" 2>&1

    sam_file="$SAMPLE_OUT/${sample_id}.sam"
    sorted_bam="$SAMPLE_OUT/${sample_id}.sorted.bam"
    dedup_bam="$SAMPLE_OUT/${sample_id}.dedup.bam"
    filtered_bam="$SAMPLE_OUT/${sample_id}.filtered.bam"
    final_bam="$SAMPLE_OUT/${sample_id}.final.bam"
    primary_log="$SAMPLE_OUT/${sample_id}.bowtie2.primary.log"
    duplicate_metrics="$SAMPLE_OUT/${sample_id}.dedup.metrics.txt"

    bowtie2_args=(-x "$BOWTIE2_INDEX" -1 "$trimmed_r1" -2 "$trimmed_r2" --local --very-sensitive-local --no-unal --no-mixed --no-discordant --phred33 -I "$MIN_INSERT" -X "$MAX_INSERT" --rg-id "$sample_id" --rg "SM:$sample_id" --rg "PL:ILLUMINA" --rg "LB:$sample_id" -p "$THREADS" -S "$sam_file")
    [[ "$ALLOW_DOVETAIL" == true ]] && bowtie2_args+=(--dovetail)

    info "  Aligning to primary genome"
    bowtie2 "${bowtie2_args[@]}" 2> "$primary_log"

    info "  Sorting BAM"
    samtools view -Sb "$sam_file" | samtools sort -@ "$THREADS" -o "$sorted_bam"
    samtools index "$sorted_bam"

    source_bam="$sorted_bam"
    if [[ "$REMOVE_DUPLICATES" == true ]]; then
        info "  Removing duplicates with Picard"
        picard MarkDuplicates I="$sorted_bam" O="$dedup_bam" M="$duplicate_metrics" REMOVE_DUPLICATES=true VALIDATION_STRINGENCY=LENIENT
        samtools index "$dedup_bam"
        source_bam="$dedup_bam"
    fi

    info "  Filtering BAM"
    filter_args=(-b -q "$MIN_MAPQ")
    [[ "$REQUIRE_PROPER_PAIR" == true ]] && filter_args+=(-f 2)
    chromosomes=()
    while IFS= read -r chrom; do
        [[ -n "$chrom" ]] && chromosomes+=("$chrom")
    done < <(config_get_list "$CONFIG" '.reference.canonical_chromosomes')

    if [[ ${#chromosomes[@]} -gt 0 ]]; then
        samtools view "${filter_args[@]}" "$source_bam" "${chromosomes[@]}" > "$filtered_bam"
    else
        samtools view "${filter_args[@]}" "$source_bam" > "$filtered_bam"
    fi

    if [[ "$REMOVE_BLACKLIST" == true ]]; then
        bedtools intersect -v -a "$filtered_bam" -b "$BLACKLIST_BED" > "$final_bam"
    else
        mv "$filtered_bam" "$final_bam"
    fi
    samtools index "$final_bam"

    final_reads=$(samtools view -c "$final_bam")
    primary_rate=$(grep "overall alignment rate" "$primary_log" | awk '{print $1}' || true)
    [[ -n "$primary_rate" ]] || primary_rate="NA"

    spike_count="NA"
    spike_scale="NA"
    if [[ "$SPIKEIN_ENABLED" == true && "$include_spikein" == "true" ]]; then
        spike_log="$SAMPLE_OUT/${sample_id}.bowtie2.spikein.log"
        info "  Aligning to spike-in genome"
        spike_count=$(bowtie2 -x "$SPIKEIN_INDEX" -1 "$trimmed_r1" -2 "$trimmed_r2" --local --very-sensitive-local --no-unal --no-mixed --no-discordant --phred33 -I "$MIN_INSERT" -X "$MAX_INSERT" --dovetail -p "$THREADS" 2> "$spike_log" | samtools view -c -F 4 -)
        if [[ "$spike_count" -gt 0 ]]; then
            spike_scale=$(awk -v count="$spike_count" 'BEGIN {printf "%.6f", 100000 / count}')
        else
            spike_scale="0"
            warn "$sample_id has zero spike-in reads"
        fi
    fi

    echo -e "${sample_id}\t${condition}\t${target}\t${replicate}\t${primary_rate}\t${final_reads}\t${spike_count}\t${spike_scale}" >> "$SUMMARY_FILE"

    if [[ "$CLEANUP" == true ]]; then
        rm -f "$sam_file" "$sorted_bam" "$sorted_bam.bai" "$dedup_bam" "$dedup_bam.bai" "$filtered_bam" "$trimmed_r1" "$trimmed_r2"
    fi

    info "  Done: $sample_id"
done < <(read_samples)

info "Alignment summary: $SUMMARY_FILE"
