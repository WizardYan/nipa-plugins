#!/usr/bin/env bash

set -euo pipefail

SUBJECT="${1:?Usage: run.sh sub-XXX ses-YY|no-session}"
SESSION="${2:?Usage: run.sh sub-XXX ses-YY|no-session}"

: "${NIPA_INPUT_RECONSTRUCTION_PATH:?NIPA did not resolve the reconstruction Artifact resource}"
: "${FREESURFER_SIF:?FREESURFER_SIF was not resolved by NIPA Runtime Manager}"
: "${FS_LICENSE:?FS_LICENSE was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
: "${THALAMIC_NUCLEI_OUT_ROOT:?THALAMIC_NUCLEI_OUT_ROOT was not resolved by NIPA output contract}"

SUBJECT_DIR="${NIPA_INPUT_RECONSTRUCTION_PATH%/}"
FS_SUBJECTS_DIR="$(dirname "$SUBJECT_DIR")"
FS_ID="$(basename "$SUBJECT_DIR")"
if [[ "$SESSION" == "no-session" ]]; then
    EXPECTED_ID="$SUBJECT"
else
    EXPECTED_ID="${SUBJECT}_${SESSION}"
fi

FS_SIF="$FREESURFER_SIF"
PROJECT_ROOT="${PROJECT_ROOT:?PROJECT_ROOT is not configured}"
MCR_DIR="${THALAMIC_MCR_DIR:-$(dirname "$PROJECT_ROOT")/softwares/freesurfer_MCRv97}"
REFERENCE_DIR="$THALAMIC_NUCLEI_OUT_ROOT/references"
REFERENCE_FILE="$REFERENCE_DIR/${EXPECTED_ID}.paths"

fail(){ echo "ERROR: $*" >&2; exit 1; }
[[ -d "$SUBJECT_DIR" ]] || fail "Resolved FreeSurfer reconstruction directory not found: $SUBJECT_DIR"
[[ "$FS_ID" == "$EXPECTED_ID" ]] || fail "Resolved reconstruction target mismatch: expected $EXPECTED_ID but Artifact locator points to $FS_ID ($SUBJECT_DIR)"
for required in \
    "$SUBJECT_DIR/mri/norm.mgz" \
    "$SUBJECT_DIR/mri/wmparc.mgz" \
    "$SUBJECT_DIR/mri/transforms/talairach.xfm"
do
    [[ -f "$required" ]] || fail "Incomplete FreeSurfer reconstruction Artifact for $FS_ID: missing $required"
done
[[ -f "$FS_SIF" ]] || fail "FreeSurfer container not found: $FS_SIF"
[[ -f "$FS_LICENSE" ]] || fail "FreeSurfer license not found: $FS_LICENSE"
[[ -d "$MCR_DIR" ]] || fail "FreeSurfer MCRv97 not found: $MCR_DIR (set THALAMIC_MCR_DIR to override)"
command -v "$NIPA_CONTAINER_RUNTIME" >/dev/null 2>&1 || fail "container runtime is unavailable on this compute node: $NIPA_CONTAINER_RUNTIME"

record_outputs() {
    mkdir -p "$REFERENCE_DIR"
    local tmp="${REFERENCE_FILE}.tmp.$$"
    find "$SUBJECT_DIR/mri" -maxdepth 1 -type f -name 'ThalamicNuclei*.mgz' -print | sort > "$tmp"
    [[ -s "$tmp" ]] || { rm -f "$tmp"; fail "No ThalamicNuclei*.mgz output found for $FS_ID"; }
    mv -f "$tmp" "$REFERENCE_FILE"
}

if compgen -G "$SUBJECT_DIR/mri/ThalamicNuclei*.mgz" >/dev/null; then
    record_outputs
    echo "SKIP: thalamic nuclei segmentation already exists for $FS_ID"
    exit 0
fi

echo "============================================================"
echo "NIPA FreeSurfer thalamic nuclei segmentation"
echo "Job ID: ${NIPA_EXECUTOR_JOB_ID:-local}"
echo "Node: $(hostname)"
echo "Subject: $FS_ID"
echo "Resolved reconstruction Artifact: ${NIPA_INPUT_RECONSTRUCTION_ARTIFACT_ID:-unknown}"
echo "FreeSurfer dir: $SUBJECT_DIR"
echo "FreeSurfer SUBJECTS_DIR: $FS_SUBJECTS_DIR"
echo "MCR: $MCR_DIR"
echo "Started: $(date --iso-8601=seconds)"
echo "============================================================"

"$NIPA_CONTAINER_RUNTIME" exec --cleanenv \
    --bind "${FS_SUBJECTS_DIR}:/subjects" \
    --bind "${MCR_DIR}:/usr/local/freesurfer/MCRv97:ro" \
    --bind "${FS_LICENSE}:/opt/freesurfer/license.txt:ro" \
    --env SUBJECTS_DIR=/subjects \
    --env FS_LICENSE=/opt/freesurfer/license.txt \
    --env OMP_NUM_THREADS="${NIPA_CPUS:-1}" \
    "$FS_SIF" \
    bash -c '
        echo "Container: $(hostname)"
        if [[ ! -f /usr/local/freesurfer/SetUpFreeSurfer.sh ]]; then
            echo "ERROR: /usr/local/freesurfer/SetUpFreeSurfer.sh not found" >&2
            exit 1
        fi
        source /usr/local/freesurfer/SetUpFreeSurfer.sh
        setup_rc=$?
        if (( setup_rc != 0 )); then
            echo "WARNING: FreeSurfer setup returned ${setup_rc}; continuing to verify the command." >&2
        fi
        export SUBJECTS_DIR=/subjects
        export FS_LICENSE=/opt/freesurfer/license.txt
        export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
        if ! command -v segmentThalamicNuclei.sh >/dev/null 2>&1; then
            echo "ERROR: segmentThalamicNuclei.sh unavailable after FreeSurfer setup" >&2
            exit 1
        fi
        echo "Running segmentThalamicNuclei.sh for $1"
        segmentThalamicNuclei.sh "$1"
    ' bash "$FS_ID"

record_outputs
echo "Completed: $FS_ID"
echo "Finished: $(date --iso-8601=seconds)"
