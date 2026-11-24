#!/usr/bin/env bash

set -euo pipefail

# NIPA calls this scheduler-agnostic entrypoint with subject and session arguments.
SUBJECT="${1:-}"
SESSION="${2:-}"

if [[ ! "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]]; then
    echo "ERROR: Invalid or missing subject: $SUBJECT" >&2
    exit 2
fi
if [[ ! "$SESSION" =~ ^ses-[A-Za-z0-9]+$ ]]; then
    echo "ERROR: Invalid or missing session: $SESSION" >&2
    exit 2
fi

: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"
: "${BIDS_ROOT:?BIDS_ROOT was not provided by NIPA ProjectContext}"
: "${CAT12_OUT_ROOT:?CAT12_OUT_ROOT was not provided by NIPA PluginRegistry}"
: "${CAT12_SIF:?CAT12_SIF was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
NIPA_SKIP_EXISTING="${NIPA_SKIP_EXISTING:-1}"

T1_GZ="$BIDS_ROOT/$SUBJECT/$SESSION/anat/${SUBJECT}_${SESSION}_T1w.nii.gz"
T1_NII="$BIDS_ROOT/$SUBJECT/$SESSION/anat/${SUBJECT}_${SESSION}_T1w.nii"
if [[ -f "$T1_GZ" ]]; then
    T1="$T1_GZ"
elif [[ -f "$T1_NII" ]]; then
    T1="$T1_NII"
else
    echo "ERROR: T1w image not found:" >&2
    echo "  $T1_GZ" >&2
    echo "  $T1_NII" >&2
    exit 1
fi

if [[ ! -f "$CAT12_SIF" ]]; then
    echo "ERROR: CAT12 container not found: $CAT12_SIF" >&2
    exit 1
fi

OUT="$CAT12_OUT_ROOT/derivatives/$SUBJECT"
SESSION_OUT="$OUT/$SESSION"
CONTAINER_T1="/data/$SUBJECT/$SESSION/anat/$(basename "$T1")"
CONTAINER_OUT="/out/derivatives/$SUBJECT"
TMP_ROOT="${NIPA_EXECUTION_WORK_DIR:?NIPA_EXECUTION_WORK_DIR was not provided by the Executor}/cat12"
SUCCESS_FILE="$SESSION_OUT/.cat12_complete"
LOG_FILE="$SESSION_OUT/brainprep_cat12.log"

mkdir -p "$CAT12_OUT_ROOT/logs" "$SESSION_OUT" "$TMP_ROOT"

if [[ "$NIPA_SKIP_EXISTING" == "1" && -f "$SUCCESS_FILE" ]]; then
    echo "Already completed: $SUBJECT $SESSION"
    exit 0
fi

mkdir -p "$TMP_ROOT/mcr_cache" "$TMP_ROOT/tmp" "$TMP_ROOT/matlab_pref"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

echo "============================================"
echo "NIPA CAT12 VBM job"
echo "Executor job: ${NIPA_EXECUTOR_JOB_ID:-local}"
echo "Host:      $(hostname)"
echo "Date:      $(date)"
echo "Subject:   $SUBJECT"
echo "Session:   $SESSION"
echo "Input T1:  $T1"
echo "Output:    $OUT"
echo "SIF:       $CAT12_SIF"
echo "============================================"

env -u DISPLAY \
"$NIPA_CONTAINER_RUNTIME" exec \
    --cleanenv \
    --bind "$BIDS_ROOT:/data:ro" \
    --bind "$CAT12_OUT_ROOT:/out" \
    --bind "$TMP_ROOT:/nipa-work" \
    --env MCR_CACHE_ROOT=/nipa-work/mcr_cache \
    --env TMPDIR=/nipa-work/tmp \
    --env MATLAB_PREFDIR=/nipa-work/matlab_pref \
    --env LIBGL_ALWAYS_SOFTWARE=1 \
    --env MESA_LOADER_DRIVER_OVERRIDE=swrast \
    "$CAT12_SIF" \
    brainprep cat12vbm \
    --anatomical "$CONTAINER_T1" \
    --outdir "$CONTAINER_OUT" \
    --session "$SESSION" \
    --verbose 2 \
    2>&1 | tee "$LOG_FILE"

MWP1="$SESSION_OUT/mri/mwp1u${SUBJECT}_${SESSION}_T1w.nii"
if [[ ! -f "$MWP1" ]]; then
    echo "ERROR: Expected MWP1 not found: $MWP1" >&2
    find "$SESSION_OUT" -type f -name 'mwp1*.nii' -print
    exit 1
fi

touch "$SUCCESS_FILE"
echo "CAT12 completed successfully: $MWP1"
echo "Finished: $(date)"
