#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

prepare_run "${1:-}" "${2:-}"
check_sample_sheet_header

require_command samtools
require_command bedtools
require_command bedGraphToBigWig
require_command bamCoverage
require_command bigWigToBedGraph

CHROM_SIZES=$(config_get "$CONFIG" '.reference.chromosome_sizes')
require_file "$CHROM_SIZES"

MAKE_SPIKEIN=false
config_get_bool "$CONFIG" '.tracks.make_spikein_tracks' true && MAKE_SPIKEIN=true
MAKE_CPM=false
config_get_bool "$CONFIG" '.tracks.make_cpm_tracks' true && MAKE_CPM=true
CPM_BIN_SIZE=$(config_get "$CONFIG" '.tracks.cpm_bin_size')
[[ -n "$CPM_BIN_SIZE" ]] || CPM_BIN_SIZE=10
EXTEND_READS=false
config_get_bool "$CONFIG" '.tracks.extend_reads' true && EXTEND_READS=true

ALIGNMENT_SUMMARY="$SUMMARY_DIR/alignment_and_spikein_summary.tsv"
SPIKEIN_SUMMARY="$SUMMARY_DIR/spikein_normalization_summary.tsv"
CPM_SUMMARY="$SUMMARY_DIR/cpm_track_summary.tsv"

mkdir -p "$TRACK_DIR/spikein/bedgraph" "$TRACK_DIR/spikein/bigwig" "$TRACK_DIR/cpm/bedgraph" "$TRACK_DIR/cpm/bigwig"

if [[ "$MAKE_SPIKEIN" == true ]]; then
    require_file "$ALIGNMENT_SUMMARY"
    echo -e "sample_id\tnormalization_group\tspikein_mapped_reads\tgroup_min_spikein_reads\tscale_factor" > "$SPIKEIN_SUMMARY"

    info "Calculating spike-in scale factors by normalization_group"
    groups=$(tail -n +2 "$SAMPLE_SHEET" | awk -F',' '{print $8}' | sort -u)
    for group in $groups; do
        [[ -n "$group" ]] || continue
        min_spike=$(awk -F'\t' -v csv="$SAMPLE_SHEET" -v group="$group" '
            BEGIN {
                while ((getline line < csv) > 0) {
                    if (NR == 1) continue
                    split(line, f, ",")
                    group_by_sample[f[1]] = f[8]
                }
            }
            NR > 1 && group_by_sample[$1] == group && $7 ~ /^[0-9]+$/ && $7 > 0 {
                if (min == "" || $7 < min) min = $7
            }
            END { if (min == "") print 0; else print min }
        ' "$ALIGNMENT_SUMMARY")

        while IFS=',' read -r sample_id condition target replicate fastq_r1 fastq_r2 control_sample_id normalization_group peak_type include_spikein; do
            [[ "$normalization_group" == "$group" ]] || continue
            [[ "$include_spikein" == "true" ]] || continue

            spike_count=$(awk -F'\t' -v sample="$sample_id" 'NR > 1 && $1 == sample {print $7}' "$ALIGNMENT_SUMMARY")
            if [[ -n "$spike_count" && "$spike_count" =~ ^[0-9]+$ && "$spike_count" -gt 0 && "$min_spike" -gt 0 ]]; then
                scale_factor=$(awk -v min="$min_spike" -v spike="$spike_count" 'BEGIN {printf "%.6f", min/spike}')
            else
                scale_factor="0"
                warn "$sample_id has no usable spike-in count; skipping spike-in track"
            fi
            echo -e "${sample_id}\t${normalization_group}\t${spike_count:-NA}\t${min_spike}\t${scale_factor}" >> "$SPIKEIN_SUMMARY"
        done < <(read_samples)
    done

    tail -n +2 "$SPIKEIN_SUMMARY" | while IFS=$'\t' read -r sample_id normalization_group spike_count min_spike scale_factor; do
        [[ "$scale_factor" != "0" ]] || continue
        bam_file=$(sample_bam "$sample_id")
        require_file "$bam_file"
        samtools quickcheck "$bam_file"

        bedgraph=$(sample_spikein_bedgraph "$sample_id")
        bigwig="$TRACK_DIR/spikein/bigwig/$sample_id.spikein_normalized.bw"

        info "Generating spike-in normalized track for $sample_id"
        bedtools genomecov -ibam "$bam_file" -bg -scale "$scale_factor" | sort -k1,1 -k2,2n > "$bedgraph"
        bedGraphToBigWig "$bedgraph" "$CHROM_SIZES" "$bigwig"
    done
fi

if [[ "$MAKE_CPM" == true ]]; then
    echo -e "sample_id\tfinal_mapped_reads\tbigwig\tbedgraph" > "$CPM_SUMMARY"
    while IFS=',' read -r sample_id condition target replicate fastq_r1 fastq_r2 control_sample_id normalization_group peak_type include_spikein; do
        bam_file=$(sample_bam "$sample_id")
        require_file "$bam_file"
        samtools quickcheck "$bam_file"

        read_count=$(samtools view -c "$bam_file")
        bigwig="$TRACK_DIR/cpm/bigwig/$sample_id.cpm.bw"
        bedgraph=$(sample_cpm_bedgraph "$sample_id")

        info "Generating CPM-normalized track for $sample_id"
        bamcoverage_args=(-b "$bam_file" -o "$bigwig" --normalizeUsing CPM --binSize "$CPM_BIN_SIZE" -p "$THREADS")
        [[ "$EXTEND_READS" == true ]] && bamcoverage_args+=(--extendReads)
        bamCoverage "${bamcoverage_args[@]}"
        bigWigToBedGraph "$bigwig" "$bedgraph"

        echo -e "${sample_id}\t${read_count}\t${bigwig}\t${bedgraph}" >> "$CPM_SUMMARY"
    done < <(read_samples)
fi

info "Track generation complete"
