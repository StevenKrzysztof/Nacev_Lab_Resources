#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for the Cut&Run / CUT&Tag template scripts.
# These scripts intentionally use yq for YAML access so project-specific
# settings stay in config.yaml instead of inside the shell code.

die() {
    echo "[FATAL] $*" >&2
    exit 1
}

warn() {
    echo "[WARNING] $*" >&2
}

info() {
    echo "[INFO] $*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_file() {
    [[ -f "$1" ]] || die "Required file not found: $1"
}

require_dir() {
    [[ -d "$1" ]] || die "Required directory not found: $1"
}

config_get() {
    local config=$1
    local key=$2
    yq -r "$key // \"\"" "$config"
}

config_get_bool() {
    local config=$1
    local key=$2
    local default=${3:-false}
    local value
    value=$(yq -r "$key // \"$default\"" "$config")
    [[ "$value" == "true" ]]
}

config_get_list() {
    local config=$1
    local key=$2
    yq -r "$key[]? // empty" "$config"
}

prepare_run() {
    CONFIG=${1:-}
    SAMPLE_SHEET=${2:-}

    [[ -n "$CONFIG" ]] || die "Usage: $0 /path/to/config.yaml /path/to/sample_sheet.csv"
    [[ -n "$SAMPLE_SHEET" ]] || die "Usage: $0 /path/to/config.yaml /path/to/sample_sheet.csv"
    require_file "$CONFIG"
    require_file "$SAMPLE_SHEET"
    require_command yq

    PROJECT_ID=$(config_get "$CONFIG" '.project.project_id')
    OUTPUT_DIR=$(config_get "$CONFIG" '.project.output_dir')
    THREADS=$(config_get "$CONFIG" '.resources.threads')

    [[ -n "$PROJECT_ID" ]] || die "Missing project.project_id in config"
    [[ -n "$OUTPUT_DIR" ]] || die "Missing project.output_dir in config"
    [[ -n "$THREADS" ]] || THREADS=1

    ALIGN_DIR="$OUTPUT_DIR/alignment"
    TRACK_DIR="$OUTPUT_DIR/tracks"
    PEAK_DIR="$OUTPUT_DIR/peaks"
    SUMMARY_DIR="$OUTPUT_DIR/summaries"
    mkdir -p "$ALIGN_DIR" "$TRACK_DIR" "$PEAK_DIR" "$SUMMARY_DIR"
}

check_sample_sheet_header() {
    local expected="sample_id,condition,target,replicate,fastq_r1,fastq_r2,control_sample_id,normalization_group,peak_type,include_spikein"
    local observed
    observed=$(head -n 1 "$SAMPLE_SHEET" | tr -d '\r')
    [[ "$observed" == "$expected" ]] || die "Sample sheet header does not match expected header: $expected"
}

read_samples() {
    # The template sample sheet is intentionally simple CSV without quoted commas.
    # Avoid commas inside metadata fields.
    tail -n +2 "$SAMPLE_SHEET" | sed '/^[[:space:]]*$/d'
}

sample_bam() {
    local sample_id=$1
    echo "$ALIGN_DIR/$sample_id/$sample_id.final.bam"
}

sample_spikein_bedgraph() {
    local sample_id=$1
    echo "$TRACK_DIR/spikein/bedgraph/$sample_id.spikein_normalized.bedgraph"
}

sample_cpm_bedgraph() {
    local sample_id=$1
    echo "$TRACK_DIR/cpm/bedgraph/$sample_id.cpm.bedgraph"
}
