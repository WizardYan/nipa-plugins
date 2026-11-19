#!/usr/bin/env bash

set -euo pipefail
SUBJECT="${1:-}"; SESSION="${2:-}"
[[ "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]] || { echo "ERROR: invalid subject: $SUBJECT" >&2; exit 2; }
[[ "$SESSION" =~ ^(ses-[A-Za-z0-9]+|no-session)$ ]] || { echo "ERROR: invalid session: $SESSION" >&2; exit 2; }
: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"
: "${BIDS_ROOT:?BIDS_ROOT was not provided by NIPA ProjectContext}"
: "${FMRIPREP_OUT_ROOT:?FMRIPREP_OUT_ROOT was not provided by NIPA PluginRegistry}"
OUT_ROOT="$FMRIPREP_OUT_ROOT"
: "${FMRIPREP_SIF:?FMRIPREP_SIF was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
SIF="$FMRIPREP_SIF"
TEMPLATEFLOW_DIR="${TEMPLATEFLOW_DIR:-$PROJECT_ROOT/templateflow}"
WORK_ROOT="${FMRIPREP_WORK_ROOT:-${NIPA_EXECUTION_WORK_DIR:?NIPA_EXECUTION_WORK_DIR was not provided by the Executor}/fmriprep-work}"
SKIP="${NIPA_SKIP_EXISTING:-1}"
LABEL="${SUBJECT#sub-}"; SES_LABEL="${SESSION#ses-}"
SUCCESS="$OUT_ROOT/.nipa_complete/${SUBJECT}_${SESSION}.complete"
CLI_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cli.py"
PARAM_ARGS_TEXT="$(python3 "$CLI_HELPER")"
mapfile -t SETTINGS <<< "$PARAM_ARGS_TEXT"
LICENSE_FILE="${SETTINGS[0]:-${FS_LICENSE:-}}"
SUBJECTS_DIR="${SETTINGS[1]}"
PARAM_ARGS=("${SETTINGS[@]:2:$(( ${#SETTINGS[@]} - 3 ))}")
EXTRA_BINDS=()
if [[ -n "$SUBJECTS_DIR" ]]; then
  [[ -d "$SUBJECTS_DIR" && -w "$SUBJECTS_DIR" ]] || {
    echo "ERROR: FreeSurfer subjects directory must exist and be writable." >&2
    exit 2
  }
  EXTRA_BINDS+=(--bind "$SUBJECTS_DIR:/fs-subjects")
  PARAM_ARGS+=(--fs-subjects-dir /fs-subjects)
fi
CONFIG_KEY="$(printf '%s\n' "$PARAM_ARGS_TEXT" "$LICENSE_FILE" | sha256sum | cut -d ' ' -f 1)"
if [[ "$SKIP" == 1 && -f "$SUCCESS" && "$(cat "$SUCCESS")" == "$CONFIG_KEY" ]]; then
  echo "Already completed: $SUBJECT $SESSION"
  exit 0
fi
[[ -f "$SIF" ]] || { echo "ERROR: fMRIPrep container not found: $SIF" >&2; exit 1; }
[[ -f "$LICENSE_FILE" && -r "$LICENSE_FILE" ]] || { echo "ERROR: FreeSurfer license file is missing or unreadable." >&2; exit 1; }
FUNC_DIR="$BIDS_ROOT/$SUBJECT"; [[ "$SESSION" != no-session ]] && FUNC_DIR="$FUNC_DIR/$SESSION"
compgen -G "$FUNC_DIR/func/*_bold.nii*" >/dev/null || { echo "ERROR: no BOLD image in $FUNC_DIR/func" >&2; exit 1; }
mkdir -p "$OUT_ROOT" "$WORK_ROOT/$SUBJECT" "$OUT_ROOT/.nipa_complete" "$TEMPLATEFLOW_DIR"
NPROCS="${NIPA_CPUS:-1}"
OMP_THREADS="$NPROCS"; (( OMP_THREADS > 8 )) && OMP_THREADS=8
NIPA_MEM_MB="${NIPA_MEMORY_MB:-4096}"
FMRIPREP_MEM_MB=$(( NIPA_MEM_MB * 90 / 100 ))
ARGS=(/data /out participant --participant-label "$LABEL" --nprocs "$NPROCS" --omp-nthreads "$OMP_THREADS" --mem "$FMRIPREP_MEM_MB" --fs-license-file /license.txt --skip-bids-validation --stop-on-first-crash)
ARGS+=("${PARAM_ARGS[@]}")
[[ "$SESSION" != no-session ]] && ARGS+=(--session-label "$SES_LABEL")
: > "$SUCCESS"
"$NIPA_CONTAINER_RUNTIME" run --cleanenv \
  --bind "$BIDS_ROOT:/data:ro" \
  --bind "$OUT_ROOT:/out" \
  --bind "$WORK_ROOT:/work" \
  --bind "$LICENSE_FILE:/license.txt:ro" \
  "${EXTRA_BINDS[@]}" \
  --bind "$TEMPLATEFLOW_DIR:/templateflow" \
  --env TEMPLATEFLOW_HOME=/templateflow \
  "$SIF" "${ARGS[@]}" -w "/work/$SUBJECT"
printf '%s\n' "$CONFIG_KEY" > "$SUCCESS"
