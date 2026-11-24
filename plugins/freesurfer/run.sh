#!/usr/bin/env bash
set -euo pipefail

SUBJECT="${1:?Usage: run.sh sub-XXX ses-YY|no-session}"
SESSION="${2:?Usage: run.sh sub-XXX ses-YY|no-session}"

: "${NIPA_INPUT_T1W_PATH:?NIPA did not resolve the T1w input}"
: "${FREESURFER_SIF:?FREESURFER_SIF was not resolved by NIPA Runtime Manager}"
: "${FS_LICENSE:?FS_LICENSE was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
: "${FREESURFER_OUT_ROOT:?FREESURFER_OUT_ROOT was not resolved by NIPA output contract}"

T1W="${NIPA_INPUT_T1W_PATH}"
FS_SIF="${FREESURFER_SIF}"
if [[ "$SESSION" == "no-session" ]]; then
    FS_ID="$SUBJECT"
else
    FS_ID="${SUBJECT}_${SESSION}"
fi
SUBJECT_DIR="${FREESURFER_OUT_ROOT}/${FS_ID}"
REFERENCE_DIR="${FREESURFER_OUT_ROOT}/.nipa_references"
REFERENCE_FILE="${REFERENCE_DIR}/${FS_ID}.path"

fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ -f "$T1W" ]] || fail "Resolved T1w input not found: $T1W"
[[ -f "$FS_SIF" ]] || fail "FreeSurfer container not found: $FS_SIF"
[[ -f "$FS_LICENSE" ]] || fail "FreeSurfer license not found: $FS_LICENSE"
command -v "$NIPA_CONTAINER_RUNTIME" >/dev/null 2>&1 || fail "container runtime unavailable: $NIPA_CONTAINER_RUNTIME"
mkdir -p "$FREESURFER_OUT_ROOT" "$REFERENCE_DIR"

is_complete() {
    [[ -f "$SUBJECT_DIR/mri/norm.mgz" ]] && \
    [[ -f "$SUBJECT_DIR/mri/wmparc.mgz" ]] && \
    [[ -f "$SUBJECT_DIR/mri/transforms/talairach.xfm" ]]
}
record_output() {
    printf '%s\n' "$SUBJECT_DIR" > "${REFERENCE_FILE}.tmp.$$"
    mv -f "${REFERENCE_FILE}.tmp.$$" "$REFERENCE_FILE"
}

if is_complete; then
    record_output
    echo "SKIP: FreeSurfer reconstruction already complete for $FS_ID"
    exit 0
fi

echo "Running FreeSurfer recon-all for $FS_ID"
"$NIPA_CONTAINER_RUNTIME" exec --cleanenv \
    --bind "${T1W}:/input/T1w.nii.gz:ro" \
    --bind "${FREESURFER_OUT_ROOT}:/subjects" \
    --bind "${FS_LICENSE}:/opt/freesurfer/license.txt:ro" \
    --env SUBJECTS_DIR=/subjects \
    --env FS_LICENSE=/opt/freesurfer/license.txt \
    --env OMP_NUM_THREADS="${NIPA_CPUS:-1}" \
    "$FS_SIF" \
    bash -c '
      set -euo pipefail
      source /usr/local/freesurfer/SetUpFreeSurfer.sh || true
      export SUBJECTS_DIR=/subjects
      export FS_LICENSE=/opt/freesurfer/license.txt
      export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
      command -v recon-all >/dev/null 2>&1 || { echo "ERROR: recon-all unavailable" >&2; exit 1; }
      recon-all -subject "$1" -i /input/T1w.nii.gz -all
    ' bash "$FS_ID"

is_complete || fail "FreeSurfer recon-all finished but required reconstruction components are missing for $FS_ID"
record_output
