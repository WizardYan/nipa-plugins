#!/usr/bin/env bash
# TRACULA plugin-native execution wrapper.
#
# NIPA resolves runtime locations; this wrapper owns the TRACULA-specific
# execution context.  It intentionally relies on the FreeSurfer image's native
# environment instead of re-sourcing SetUpFreeSurfer.sh inside bash.  The
# standalone workflow documented in logs.docx validated this wrapper first with
# `recon-all -version` and `trac-all -version` before running TRACULA stages.

set -euo pipefail

: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"

: "${BIDS_ROOT:?BIDS_ROOT was not provided by NIPA ProjectContext}"
TRACULA_OUT_ROOT="${TRACULA_OUT_ROOT:-$PROJECT_ROOT/derivatives/tracula}"
: "${FREESURFER_SUBJECTS_DIR:?FREESURFER_SUBJECTS_DIR must be derived from the resolved reconstruction Artifact}"
: "${FREESURFER_SIF:?FREESURFER_SIF was not resolved by NIPA Runtime Manager}"
: "${FS_LICENSE:?FS_LICENSE was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
: "${FSLDIR:?FSLDIR was not resolved by NIPA Runtime Manager}"
: "${ANTS_ENV:?ANTS_ENV was not resolved by NIPA Runtime Manager}"
# Runtime Manager normally supplies ANTSPATH from the ANTs provider.  Keep a
# deterministic fallback for older site registries while preserving the same
# provider-derived location.
ANTSPATH="${ANTSPATH:-${ANTS_ENV%/}/bin/}"


[[ $# -gt 0 ]] || { echo "ERROR: no command supplied to tracula_exec.sh" >&2; exit 2; }
[[ -f "$FREESURFER_SIF" ]] || { echo "ERROR: FreeSurfer container not found: $FREESURFER_SIF" >&2; exit 1; }
[[ -f "$FS_LICENSE" ]] || { echo "ERROR: FreeSurfer license not found: $FS_LICENSE" >&2; exit 1; }
[[ -d "$BIDS_ROOT" ]] || { echo "ERROR: BIDS root not found: $BIDS_ROOT" >&2; exit 1; }
[[ -d "$FREESURFER_SUBJECTS_DIR" ]] || { echo "ERROR: FreeSurfer SUBJECTS_DIR not found: $FREESURFER_SUBJECTS_DIR" >&2; exit 1; }
[[ -d "$FSLDIR" ]] || { echo "ERROR: FSL installation not found: $FSLDIR" >&2; exit 1; }
[[ -d "$ANTS_ENV" ]] || { echo "ERROR: ANTs environment not found: $ANTS_ENV" >&2; exit 1; }
[[ -d "$ANTSPATH" ]] || { echo "ERROR: ANTs binary directory not found: $ANTSPATH" >&2; exit 1; }
[[ -x "${ANTSPATH%/}/antsRegistration" ]] || { echo "ERROR: antsRegistration not found under ANTSPATH: $ANTSPATH" >&2; exit 1; }
[[ -x "${ANTSPATH%/}/antsApplyTransforms" ]] || { echo "ERROR: antsApplyTransforms not found under ANTSPATH: $ANTSPATH" >&2; exit 1; }
command -v "$NIPA_CONTAINER_RUNTIME" >/dev/null || { echo "ERROR: container runtime unavailable: $NIPA_CONTAINER_RUNTIME" >&2; exit 1; }

mkdir -p "$TRACULA_OUT_ROOT"

bind_args=(
    --bind "$BIDS_ROOT:/bids:ro"
    --bind "$FREESURFER_SUBJECTS_DIR:/subjects:ro"
    --bind "$TRACULA_OUT_ROOT:/tracula"
    --bind "$FS_LICENSE:/opt/freesurfer/license.txt:ro"
    --bind "$FSLDIR:$FSLDIR:ro"
    --bind "$ANTS_ENV:$ANTS_ENV:ro"
)

echo "NIPA TRACULA container diagnostics"
echo "  Host:          ${HOSTNAME:-unavailable}"
echo "  Runtime:       $NIPA_CONTAINER_RUNTIME"
echo "  Runtime path:  $(command -v "$NIPA_CONTAINER_RUNTIME")"
echo "  Container:     $FREESURFER_SIF"
echo "  BIDS bind:     $BIDS_ROOT -> /bids (ro)"
echo "  Subjects bind: $FREESURFER_SUBJECTS_DIR -> /subjects (ro)"
echo "  Output bind:   $TRACULA_OUT_ROOT -> /tracula (rw)"
echo "  License bind:  $FS_LICENSE -> /opt/freesurfer/license.txt (ro)"
echo "  FSL bind:      $FSLDIR -> $FSLDIR (ro)"
echo "  ANTs bind:     $ANTS_ENV -> $ANTS_ENV (ro)"
echo "  ANTSPATH:      $ANTSPATH"
echo "  Command:       $*"
echo "  Runtime version:"
"$NIPA_CONTAINER_RUNTIME" --version 2>&1 | sed 's/^/    /' || true
echo "Launching TRACULA container..."

set +e
"$NIPA_CONTAINER_RUNTIME" exec \
    --cleanenv \
    "${bind_args[@]}" \
    --env SUBJECTS_DIR=/subjects \
    --env FS_LICENSE=/opt/freesurfer/license.txt \
    --env FSLDIR="$FSLDIR" \
    --env ANTS_ENV="$ANTS_ENV" \
    --env CONDA_PREFIX="$ANTS_ENV" \
    --env ANTSPATH="$ANTSPATH" \
    --env FSLOUTPUTTYPE=NIFTI_GZ \
    --env OMP_NUM_THREADS="${NIPA_CPUS:-1}" \
    "$FREESURFER_SIF" \
    bash -c '
        set -euo pipefail

        echo "NIPA TRACULA container entered"
        echo "  Container host: ${HOSTNAME:-unavailable}"
        echo "  Shell:          ${BASH_VERSION:-unknown}"

        # The FreeSurfer SIF is the provider of the FreeSurfer/TRACULA runtime.
        # Do not re-source SetUpFreeSurfer.sh here: the image environment is
        # already active, and re-sourcing it was the failure boundary in v0.33-0.36.
        export SUBJECTS_DIR=/subjects
        export FS_LICENSE=/opt/freesurfer/license.txt
        export FSLDIR="${FSLDIR}"
        export FSLOUTPUTTYPE=NIFTI_GZ

        # Reproduce the previously working host FSL initialization without
        # letting a non-zero `source` status terminate the wrapper.
        if [[ -f "$FSLDIR/etc/fslconf/fsl.sh" ]]; then
            set +e
            source "$FSLDIR/etc/fslconf/fsl.sh"
            set -e
        fi
        export ANTSPATH="${ANTSPATH:-${ANTS_ENV%/}/bin/}"
        export PATH="$FSLDIR/bin:${ANTSPATH%/}:$PATH"
        if [[ -d "$ANTS_ENV/lib" ]]; then
            export LD_LIBRARY_PATH="$ANTS_ENV/lib:${LD_LIBRARY_PATH:-}"
        fi

        exec "$@"
    ' bash "$@"
container_rc=$?
set -e
echo "TRACULA container process exited with code: $container_rc"
if [[ $container_rc -ne 0 ]]; then
    echo "ERROR: TRACULA container launch or in-container command failed (exit $container_rc)." >&2
fi
exit "$container_rc"
