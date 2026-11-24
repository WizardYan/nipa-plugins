#!/usr/bin/env bash

set -euo pipefail

SUBJECT="${1:-}"
SESSION="${2:-}"
[[ "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]] || { echo "ERROR: invalid subject: $SUBJECT" >&2; exit 2; }
[[ "$SESSION" =~ ^(ses-[A-Za-z0-9]+|no-session)$ ]] || { echo "ERROR: invalid session: $SESSION" >&2; exit 2; }

: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"
: "${BIDS_ROOT:?BIDS_ROOT was not provided by NIPA ProjectContext}"
TRACULA_OUT_ROOT="${TRACULA_OUT_ROOT:-$PROJECT_ROOT/derivatives/tracula}"
: "${NIPA_INPUT_RECONSTRUCTION_PATH:?NIPA did not resolve the reconstruction Artifact resource}"
: "${FREESURFER_SIF:?FREESURFER_SIF was not resolved by NIPA Runtime Manager}"
: "${FS_LICENSE:?FS_LICENSE was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
: "${FSLDIR:?FSLDIR was not resolved by NIPA Runtime Manager}"
: "${ANTS_ENV:?ANTS_ENV was not resolved by NIPA Runtime Manager}"
ANTSPATH="${ANTSPATH:-${ANTS_ENV%/}/bin/}"
# TRACULA_EXEC is a plugin-private execution asset. NIPA resolves its absolute
# path before executor submission so scheduler staging cannot change its meaning.
TRACULA_EXEC="${TRACULA_EXEC:-}"
TRACULA_CHECK_FS="${TRACULA_CHECK_FS:-}"
TRACULA_AUTO_CONFIG="${TRACULA_AUTO_CONFIG:-}"
TRACULA_VALIDATE_CONFIG="${TRACULA_VALIDATE_CONFIG:-}"
NIPA_SKIP_EXISTING="${NIPA_SKIP_EXISTING:-1}"

if [[ "$SESSION" == "no-session" ]]; then
    ID="$SUBJECT"
    DWI_DIR="$BIDS_ROOT/$SUBJECT/dwi"
else
    ID="${SUBJECT}_${SESSION}"
    DWI_DIR="$BIDS_ROOT/$SUBJECT/$SESSION/dwi"
fi
DWI="$DWI_DIR/${ID}_dwi.nii.gz"
[[ -f "$DWI" ]] || DWI="$DWI_DIR/${ID}_dwi.nii"
BVEC="$DWI_DIR/${ID}_dwi.bvec"
BVAL="$DWI_DIR/${ID}_dwi.bval"
FS_SUBJECT="${NIPA_INPUT_RECONSTRUCTION_PATH%/}"
FREESURFER_SUBJECTS_DIR="$(dirname "$FS_SUBJECT")"
FS_ID="$(basename "$FS_SUBJECT")"
THALAMIC_NUCLEI="${NIPA_INPUT_THALAMIC_NUCLEI_PATH:-}"
CONFIG_DIR="$TRACULA_OUT_ROOT/config"
CONFIG="$CONFIG_DIR/$ID.dmrirc"
SUCCESS_DIR="$TRACULA_OUT_ROOT/.nipa_complete"
SUCCESS="$SUCCESS_DIR/$ID.complete"

[[ -f "$DWI" ]] || { echo "ERROR: DWI not found for $ID under $DWI_DIR" >&2; exit 1; }
[[ -f "$BVEC" ]] || { echo "ERROR: bvec not found: $BVEC" >&2; exit 1; }
[[ -f "$BVAL" ]] || { echo "ERROR: bval not found: $BVAL" >&2; exit 1; }
[[ -d "$FS_SUBJECT" ]] || { echo "ERROR: resolved FreeSurfer reconstruction directory not found: $FS_SUBJECT" >&2; exit 1; }
[[ "$FS_ID" == "$ID" ]] || { echo "ERROR: resolved reconstruction target mismatch: expected $ID but Artifact locator points to $FS_ID ($FS_SUBJECT)" >&2; exit 1; }
[[ -f "$FS_SUBJECT/mri/aparc+aseg.mgz" ]] || { echo "ERROR: missing FreeSurfer aparc+aseg.mgz for $ID" >&2; exit 1; }
if [[ -n "$THALAMIC_NUCLEI" ]]; then
    [[ -f "$THALAMIC_NUCLEI" ]] || { echo "ERROR: resolved thalamic-nuclei Artifact resource not found: $THALAMIC_NUCLEI" >&2; exit 1; }
    THALAMIC_PARENT="$(dirname "$THALAMIC_NUCLEI")"
    [[ "$THALAMIC_PARENT" == "$FS_SUBJECT/mri" ]] || {
        echo "ERROR: resolved thalamic-nuclei Artifact does not belong to the resolved FreeSurfer reconstruction" >&2
        echo "  reconstruction: $FS_SUBJECT" >&2
        echo "  segmentation:   $THALAMIC_NUCLEI" >&2
        exit 1
    }
    case "$(basename "$THALAMIC_NUCLEI")" in
        ThalamicNuclei*.mgz) ;;
        *) echo "ERROR: resolved thalamic-nuclei Artifact is not a ThalamicNuclei*.mgz resource: $THALAMIC_NUCLEI" >&2; exit 1 ;;
    esac
fi
[[ -f "$FREESURFER_SIF" ]] || { echo "ERROR: FreeSurfer container not found: $FREESURFER_SIF" >&2; exit 1; }
[[ -f "$FS_LICENSE" ]] || { echo "ERROR: FreeSurfer license not found: $FS_LICENSE" >&2; exit 1; }
command -v "$NIPA_CONTAINER_RUNTIME" >/dev/null || { echo "ERROR: container runtime is unavailable: $NIPA_CONTAINER_RUNTIME" >&2; exit 1; }

mkdir -p "$CONFIG_DIR" "$TRACULA_OUT_ROOT/logs" "$SUCCESS_DIR"
if [[ "$NIPA_SKIP_EXISTING" == "1" && -f "$SUCCESS" ]]; then
    echo "Already completed: $ID"
    exit 0
fi

# v0.40 preserves the native wrapper sequence while restoring the previously
# working direct dmrirc generation logic inside the TRACULA plugin adapter.
# NIPA passes resolved artifacts explicitly; no temporary BIDS view is created.

validate_asset() {
    local name="$1" path="$2"
    [[ -n "$path" ]] || { echo "ERROR: $name was not supplied by NIPA plugin runtime" >&2; exit 1; }
    [[ "$path" = /* ]] || { echo "ERROR: $name must be an absolute path: $path" >&2; [[ "$name" != "TRACULA_EXEC" ]] || echo "ERROR: TRACULA_EXEC must be an absolute path" >&2; exit 1; }
    [[ -x "$path" ]] || { echo "ERROR: $name is missing or not executable: $path" >&2; exit 1; }
}

validate_asset TRACULA_EXEC "$TRACULA_EXEC"
validate_asset TRACULA_CHECK_FS "$TRACULA_CHECK_FS"
validate_asset TRACULA_AUTO_CONFIG "$TRACULA_AUTO_CONFIG"
validate_asset TRACULA_VALIDATE_CONFIG "$TRACULA_VALIDATE_CONFIG"

# v0.38: establish one exported plugin execution context before invoking any
# TRACULA helper subprocess.  Values resolved by NIPA must cross the process
# boundary; otherwise helper scripts see unset variables even though the
# parent Slurm shell can use them.
export PROJECT_ROOT
export BIDS_ROOT
export TRACULA_OUT_ROOT
export FREESURFER_SUBJECTS_DIR
export FREESURFER_SIF
export FS_LICENSE
export NIPA_CONTAINER_RUNTIME
export FSLDIR
export ANTS_ENV
export ANTSPATH
export TRACULA_EXEC
export TRACULA_CHECK_FS
export TRACULA_AUTO_CONFIG
export TRACULA_VALIDATE_CONFIG
export NIPA_SKIP_EXISTING
export NIPA_INPUT_RECONSTRUCTION_ARTIFACT_ID
export NIPA_INPUT_RECONSTRUCTION_PATH
export NIPA_INPUT_THALAMIC_NUCLEI_ARTIFACT_ID="${NIPA_INPUT_THALAMIC_NUCLEI_ARTIFACT_ID:-}"
export NIPA_INPUT_THALAMIC_NUCLEI_PATH="$THALAMIC_NUCLEI"

run_tracula() {
    "$TRACULA_EXEC" "$@"
}

run_stage() {
    local stage="$1"
    local stage_log="$TRACULA_OUT_ROOT/logs/${ID}_${stage}.log"
    echo "--------------------------------------------------"
    echo "TRACULA stage: $stage"
    echo "Subject-session: $ID"
    echo "Started: $(date --iso-8601=seconds)"
    echo "Stage log: $stage_log"
    echo "--------------------------------------------------"
    run_tracula trac-all "-$stage" -c "/tracula/config/$ID.dmrirc" 2>&1 | tee "$stage_log"
}

echo "=================================================="
echo "NIPA TRACULA job"
echo "Executor job: ${NIPA_EXECUTOR_JOB_ID:-local}"
echo "Host: $(hostname)"
echo "Subject-session: $ID"
echo "DWI: $DWI"
echo "FreeSurfer reconstruction Artifact: ${NIPA_INPUT_RECONSTRUCTION_ARTIFACT_ID:-unknown}"
echo "FreeSurfer: $FS_SUBJECT"
echo "Thalamic nuclei Artifact: ${NIPA_INPUT_THALAMIC_NUCLEI_ARTIFACT_ID:-not resolved (optional)}"
echo "Thalamic nuclei: ${THALAMIC_NUCLEI:-not resolved (TRACULA will use usethalnuc=0)}"
echo "Output: $TRACULA_OUT_ROOT"
echo "Config: $CONFIG"
echo "Container: $FREESURFER_SIF"
echo "FSL: $FSLDIR"
echo "ANTs: $ANTS_ENV"
echo "ANTSPATH: $ANTSPATH"
echo "=================================================="

echo "--------------------------------------------------"
echo "TRACULA native wrapper preflight"
echo "--------------------------------------------------"
run_tracula recon-all -version
run_tracula trac-all -version

echo "--------------------------------------------------"
echo "FreeSurfer prerequisite validation"
echo "--------------------------------------------------"
"$TRACULA_CHECK_FS" "$ID" "$FS_SUBJECT" "$THALAMIC_NUCLEI"

echo "--------------------------------------------------"
echo "TRACULA automatic configuration"
echo "--------------------------------------------------"
"$TRACULA_AUTO_CONFIG" "$SUBJECT" "$SESSION" "$ID" "$DWI" "$BVEC" "$BVAL" "$DWI_DIR/${ID}_dwi.json" "$FS_SUBJECT" "$THALAMIC_NUCLEI"

echo "--------------------------------------------------"
echo "TRACULA configuration validation"
echo "--------------------------------------------------"
"$TRACULA_VALIDATE_CONFIG" "$ID"

run_stage prep
run_stage bedp
run_stage path

touch "$SUCCESS"
echo "TRACULA completed successfully: $ID"
echo "Finished: $(date --iso-8601=seconds)"
