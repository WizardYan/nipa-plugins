#!/usr/bin/env bash
set -euo pipefail

SUBJECT="${1:-}"
SESSION="${2:-}"
[[ "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]] || { echo "ERROR: invalid subject: $SUBJECT" >&2; exit 2; }
[[ "$SESSION" =~ ^(ses-[A-Za-z0-9]+|no-session)$ ]] || { echo "ERROR: invalid session: $SESSION" >&2; exit 2; }

: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"
: "${NIPA_INPUT_DERIVATIVES_PATH:?NIPA did not resolve the derivatives Artifact}"
: "${XCPD_OUT_ROOT:?XCPD_OUT_ROOT was not provided by NIPA PluginRegistry}"
: "${XCPD_SIF:?XCPD_SIF was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
: "${NIPA_EXECUTION_WORK_DIR:?NIPA_EXECUTION_WORK_DIR was not provided by the Executor}"

DERIVATIVES_ROOT="${NIPA_INPUT_DERIVATIVES_PATH%/}"
OUT_ROOT="${XCPD_OUT_ROOT%/}"
WORK_ROOT="${XCPD_WORK_ROOT:-$NIPA_EXECUTION_WORK_DIR/xcp-d-work}"
SKIP_EXISTING="${NIPA_SKIP_EXISTING:-1}"

[[ -d "$DERIVATIVES_ROOT" ]] || { echo "ERROR: resolved derivatives Artifact is not a directory: $DERIVATIVES_ROOT" >&2; exit 1; }
[[ -f "$DERIVATIVES_ROOT/dataset_description.json" ]] || { echo "ERROR: resolved derivatives Artifact lacks dataset_description.json: $DERIVATIVES_ROOT" >&2; exit 1; }
[[ -f "$XCPD_SIF" ]] || { echo "ERROR: XCP-D container not found: $XCPD_SIF" >&2; exit 1; }

XCPD_CLI_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cli.py"
[[ -f "$XCPD_CLI_HELPER" ]] || { echo "ERROR: XCP-D CLI adapter missing: $XCPD_CLI_HELPER" >&2; exit 1; }
PARAMETERS_JSON="${NIPA_PARAMETERS_JSON-}"
[[ -n "$PARAMETERS_JSON" ]] || PARAMETERS_JSON='{}'
PARAM_ARGS_FILE="$NIPA_EXECUTION_WORK_DIR/xcpd-args-${SUBJECT}-${SESSION}.bin"
printf '%s' "$PARAMETERS_JSON" | python "$XCPD_CLI_HELPER" > "$PARAM_ARGS_FILE"
mapfile -d '' -t PARAM_ARGS < "$PARAM_ARGS_FILE"
CONFIG_KEY="$( (printf '%s\0' 'xcp-d-26.2.0'; cat "$PARAM_ARGS_FILE") | sha256sum | awk '{print substr($1,1,12)}' )"
SUCCESS="$OUT_ROOT/.nipa_complete/${SUBJECT}_${SESSION}_${CONFIG_KEY}.complete"
[[ "$SKIP_EXISTING" == 1 && -f "$SUCCESS" ]] && { echo "Already completed: $SUBJECT $SESSION (config $CONFIG_KEY)"; exit 0; }
mkdir -p "$OUT_ROOT" "$WORK_ROOT/$SUBJECT/$SESSION/$CONFIG_KEY" "$OUT_ROOT/.nipa_complete"

LABEL="${SUBJECT#sub-}"
SES_LABEL="${SESSION#ses-}"

# XCP-D/Nipype can hold multiple large BOLD arrays concurrently.  Do not map
# every Slurm CPU directly to a MultiProc worker.  Derive conservative
# concurrency from both CPU and memory allocations and leave memory outside
# Nipype's scheduler for the Python parent process, container runtime, reports,
# BLAS workspaces, and imperfect node-level memory estimates.
ALLOC_CPUS="${NIPA_CPUS:-1}"
ALLOC_MEM_MB="${NIPA_MEMORY_MB:-4096}"
[[ "$ALLOC_CPUS" =~ ^[0-9]+$ ]] && (( ALLOC_CPUS >= 1 )) || { echo "ERROR: invalid NIPA_CPUS: $ALLOC_CPUS" >&2; exit 2; }
[[ "$ALLOC_MEM_MB" =~ ^[0-9]+$ ]] && (( ALLOC_MEM_MB >= 1024 )) || { echo "ERROR: invalid NIPA_MEMORY_MB: $ALLOC_MEM_MB" >&2; exit 2; }

# Default to roughly one concurrent Nipype worker per 20 GiB, with a hard cap
# of four.  This is deliberately conservative for NIfTI BOLD post-processing.
MEM_DERIVED_PROCS=$(( ALLOC_MEM_MB / (20 * 1024) ))
(( MEM_DERIVED_PROCS < 1 )) && MEM_DERIVED_PROCS=1
NPROCS="$ALLOC_CPUS"
(( NPROCS > MEM_DERIVED_PROCS )) && NPROCS="$MEM_DERIVED_PROCS"
(( NPROCS > 4 )) && NPROCS=4
if [[ -n "${NIPA_XCPD_NPROCS:-}" ]]; then
  [[ "$NIPA_XCPD_NPROCS" =~ ^[0-9]+$ ]] && (( NIPA_XCPD_NPROCS >= 1 )) || { echo "ERROR: NIPA_XCPD_NPROCS must be a positive integer" >&2; exit 2; }
  (( NIPA_XCPD_NPROCS <= ALLOC_CPUS )) || { echo "ERROR: NIPA_XCPD_NPROCS exceeds allocated CPUs ($ALLOC_CPUS)" >&2; exit 2; }
  NPROCS="$NIPA_XCPD_NPROCS"
fi

OMP_THREADS=2
(( OMP_THREADS > ALLOC_CPUS )) && OMP_THREADS="$ALLOC_CPUS"
if [[ -n "${NIPA_XCPD_OMP_NTHREADS:-}" ]]; then
  [[ "$NIPA_XCPD_OMP_NTHREADS" =~ ^[0-9]+$ ]] && (( NIPA_XCPD_OMP_NTHREADS >= 1 )) || { echo "ERROR: NIPA_XCPD_OMP_NTHREADS must be a positive integer" >&2; exit 2; }
  (( NIPA_XCPD_OMP_NTHREADS <= ALLOC_CPUS )) || { echo "ERROR: NIPA_XCPD_OMP_NTHREADS exceeds allocated CPUs ($ALLOC_CPUS)" >&2; exit 2; }
  OMP_THREADS="$NIPA_XCPD_OMP_NTHREADS"
fi

MEM_FRACTION="${NIPA_XCPD_MEM_FRACTION:-80}"
[[ "$MEM_FRACTION" =~ ^[0-9]+$ ]] && (( MEM_FRACTION >= 50 && MEM_FRACTION <= 95 )) || {
  echo "ERROR: NIPA_XCPD_MEM_FRACTION must be an integer from 50 through 95" >&2
  exit 2
}
MEM_MB=$(( ALLOC_MEM_MB * MEM_FRACTION / 100 ))

ARGS=(
  /input /output participant
  --participant-label "$LABEL"
  --input-type fmriprep
  --nprocs "$NPROCS"
  --omp-nthreads "$OMP_THREADS"
  --mem-mb "$MEM_MB"
  --stop-on-first-crash
  --notrack
  --output-layout multiverse
  --work-dir "/work/$SUBJECT/$SESSION/$CONFIG_KEY"
)
[[ "$SESSION" != no-session ]] && ARGS+=(--session-id "$SES_LABEL")
ARGS+=("${PARAM_ARGS[@]}")

echo "NIPA XCP-D post-processing"
echo "Subject: $SUBJECT"
echo "Session: $SESSION"
echo "Resolved derivatives artifact: ${NIPA_INPUT_DERIVATIVES_ARTIFACT_ID:-unknown}"
echo "Resolved derivatives root: $DERIVATIVES_ROOT"
echo "Output root: $OUT_ROOT"
echo "Container: $XCPD_SIF"
echo "Slurm allocation: ${ALLOC_CPUS} CPUs / ${ALLOC_MEM_MB} MB"
echo "XCP-D concurrency: --nprocs ${NPROCS}, --omp-nthreads ${OMP_THREADS}"
echo "XCP-D scheduler memory: ${MEM_MB} MB (${MEM_FRACTION}% of allocation)"
echo "XCP-D configuration key: $CONFIG_KEY"
echo "XCP-D output layout: multiverse (configuration-separated)"

LICENSE_ARGS=()
if [[ -n "${FS_LICENSE:-}" && -f "$FS_LICENSE" ]]; then
  LICENSE_ARGS=(--bind "$FS_LICENSE:/license.txt:ro")
  ARGS+=(--fs-license-file /license.txt)
fi

"$NIPA_CONTAINER_RUNTIME" run --cleanenv \
  --env "OMP_NUM_THREADS=$OMP_THREADS" \
  --env "MKL_NUM_THREADS=$OMP_THREADS" \
  --env "OPENBLAS_NUM_THREADS=$OMP_THREADS" \
  --env "NUMEXPR_NUM_THREADS=$OMP_THREADS" \
  --env "VECLIB_MAXIMUM_THREADS=$OMP_THREADS" \
  --bind "$DERIVATIVES_ROOT:/input:ro" \
  --bind "$OUT_ROOT:/output" \
  --bind "$WORK_ROOT:/work" \
  "${LICENSE_ARGS[@]}" \
  "$XCPD_SIF" "${ARGS[@]}"

touch "$SUCCESS"
