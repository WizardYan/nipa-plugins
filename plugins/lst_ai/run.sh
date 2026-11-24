#!/usr/bin/env bash
# NIPA LST-AI CPU execution adapter. Called as: run.sh sub-XXX ses-YY|no-session
set -euo pipefail

fail() { echo "ERROR: LST-AI: $*" >&2; exit 1; }

SUBJECT="${1:-}"
SESSION="${2:-}"
[[ "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]] || fail "Invalid subject: $SUBJECT"
[[ "$SESSION" == no-session || "$SESSION" =~ ^ses-[A-Za-z0-9]+$ ]] || fail "Invalid session: $SESSION"

: "${NIPA_INPUT_MANIFEST:?NIPA did not supply the execution input manifest}"
: "${LST_AI_SIF:?NIPA Runtime Manager did not resolve the LST-AI SIF}"
: "${LST_AI_OUT_ROOT:?NIPA did not resolve the LST-AI output root}"
: "${NIPA_EXECUTION_WORK_DIR:?NIPA did not provide the execution work directory}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA did not resolve Singularity}"

[[ "$(basename -- "$NIPA_CONTAINER_RUNTIME")" == singularity ]] || fail "Only Singularity is supported"
command -v "$NIPA_CONTAINER_RUNTIME" >/dev/null 2>&1 || fail "Singularity executable unavailable"
[[ -f "$LST_AI_SIF" ]] || fail "Container missing: $LST_AI_SIF"

# NIPA only exports NIPA_INPUT_<PORT>_PATH for source: artifact ports.
# Dataset ports are resolved during planning and saved under bindings in the
# attempt-scoped input manifest; use that exact reviewed selection.
[[ -f "$NIPA_INPUT_MANIFEST" ]] || fail "Input manifest missing: $NIPA_INPUT_MANIFEST"
mapfile -d '' -t INPUTS < <(python3 - "$NIPA_INPUT_MANIFEST" "$SUBJECT" "$SESSION" <<'PY'
import json
from pathlib import Path
import sys

manifest_path, subject, session = sys.argv[1:]
try:
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    if (manifest.get("subject"), manifest.get("session")) != (subject, session):
        raise ValueError("manifest target does not match execution target")
    for port in ("t1w", "flair"):
        binding = manifest["bindings"][port]
        if binding.get("source") != "dataset":
            raise ValueError(f"{port} is not a dataset input")
        selected = binding["targets"][f"{subject}/{session}"]
        if not isinstance(selected, list) or len(selected) != 1 or not isinstance(selected[0], str):
            raise ValueError(f"{port} must have exactly one selected dataset file")
        path = Path(selected[0])
        if not path.is_absolute():
            raise ValueError(f"{port} path must be absolute")
        sys.stdout.buffer.write(str(path).encode("utf-8") + b"\0")
except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
    raise SystemExit(f"ERROR: LST-AI: cannot resolve dataset inputs: {exc}")
PY
)
[[ ${#INPUTS[@]} -eq 2 ]] || fail "Input manifest did not supply exactly one T1w and one FLAIR for $SUBJECT/$SESSION"
T1W_PATH="${INPUTS[0]}"
FLAIR_PATH="${INPUTS[1]}"
[[ -f "$T1W_PATH" ]] || fail "T1w missing: $T1W_PATH"
[[ -f "$FLAIR_PATH" ]] || fail "FLAIR missing: $FLAIR_PATH"
[[ "$T1W_PATH" != "$FLAIR_PATH" ]] || fail "T1w and FLAIR cannot be the same file"

# The input paths are selected by NIPA's input resolver; do not search the
# filesystem and silently choose among potentially ambiguous BIDS candidates.
WORK="$NIPA_EXECUTION_WORK_DIR/lst-ai-${SUBJECT}-${SESSION}"
OUT="$LST_AI_OUT_ROOT/$SUBJECT"
[[ "$SESSION" == no-session ]] || OUT="$OUT/$SESSION"
mkdir -p "$WORK/in" "$WORK/temp" "$OUT"

stage_nifti() {
  local original="$1" staged="$2"
  case "$original" in
    *.nii.gz) ln -sfn -- "$(realpath -- "$original")" "$staged" ;;
    *.nii) gzip -c -- "$original" > "${staged}.tmp.$$" && mv -- "${staged}.tmp.$$" "$staged" ;;
    *) fail "Only .nii and .nii.gz inputs are supported: $original" ;;
  esac
}
stage_nifti "$T1W_PATH" "$WORK/in/t1.nii.gz"
stage_nifti "$FLAIR_PATH" "$WORK/in/flair.nii.gz"

# Use an actual file bind for inputs: Singularity can otherwise resolve
# staged symlink targets outside the container's /in mount.
T1_SOURCE="$(realpath -- "$WORK/in/t1.nii.gz")"
FLAIR_SOURCE="$(realpath -- "$WORK/in/flair.nii.gz")"

PARAMETERS_JSON="${NIPA_PARAMETERS_JSON:-}"
[[ -n "$PARAMETERS_JSON" ]] || PARAMETERS_JSON='{}'
mapfile -t PARAMS < <(python3 -c '
import json, sys
p = json.loads(sys.argv[1])
if not isinstance(p, dict): raise SystemExit("Parameters must be a JSON object")
allowed = {"mode", "threshold", "lesion_threshold_mm3", "stripped", "fast_mode", "probability_map"}
unknown = set(p) - allowed
if unknown: raise SystemExit(f"Unsupported parameters: {sorted(unknown)}")
mode = p.get("mode", "segmentation_and_annotation")
if mode not in ("segmentation_and_annotation", "segmentation_only"):
    raise SystemExit("Invalid processing mode")
def number(key, default, low, high=None):
    v = p.get(key, default)
    if isinstance(v, bool) or not isinstance(v, (float, int)) or not low <= v or (high is not None and v > high):
        raise SystemExit(f"Invalid {key}")
    return str(v)
def integer(key, default, low):
    v = p.get(key, default)
    if isinstance(v, bool) or not isinstance(v, int) or v < low:
        raise SystemExit(f"Invalid {key}: expected integer >= {low}")
    return str(v)
def boolean(key):
    v = p.get(key, False)
    if not isinstance(v, bool): raise SystemExit(f"Invalid {key}")
    return "1" if v else "0"
print(mode)
print(number("threshold", 0.5, 0, 1))
print(integer("lesion_threshold_mm3", 0, 0))
for key in ("stripped", "fast_mode", "probability_map"): print(boolean(key))
' "$PARAMETERS_JSON")
[[ ${#PARAMS[@]} -eq 6 ]] || fail "Invalid NIPA_PARAMETERS_JSON"

ARGS=(--t1 /in/t1.nii.gz --flair /in/flair.nii.gz --output /out --temp /temp
      --device cpu --threshold "${PARAMS[1]}" --lesion_threshold "${PARAMS[2]}")
[[ "${PARAMS[0]}" == segmentation_only ]] && ARGS+=(--segment_only)
[[ "${PARAMS[3]}" == 1 ]] && ARGS+=(--stripped)
[[ "${PARAMS[4]}" == 1 ]] && ARGS+=(--fast-mode)
[[ "${PARAMS[5]}" == 1 ]] && ARGS+=(--probability_map)

CPUS="${NIPA_CPUS:-1}"
[[ "$CPUS" =~ ^[1-9][0-9]*$ ]] || fail "Invalid NIPA_CPUS: $CPUS"
ARGS+=(--threads "$CPUS")

echo "LST-AI CPU: $SUBJECT $SESSION (threads=$CPUS, mode=${PARAMS[0]})"
"$NIPA_CONTAINER_RUNTIME" run --cleanenv \
  --bind "$T1_SOURCE:/in/t1.nii.gz:ro" \
  --bind "$FLAIR_SOURCE:/in/flair.nii.gz:ro" \
  --bind "$OUT:/out" \
  --bind "$WORK/temp:/temp" \
  --env "OMP_NUM_THREADS=$CPUS" \
  "$LST_AI_SIF" "${ARGS[@]}"

# LST-AI documents that probability maps are retained under --temp, not
# necessarily --output. Expose those maps in Results without copying all
# intermediate registration and skull-stripping volumes.
if [[ "${PARAMS[5]}" == 1 ]]; then
  while IFS= read -r -d '' probability_file; do
    relative="${probability_file#"$WORK/temp/"}"
    destination="$OUT/probability_maps/$relative"
    mkdir -p "$(dirname -- "$destination")"
    cp -n -- "$probability_file" "$destination"
  done < <(find "$WORK/temp" -type f \( -iname '*prob*.nii' -o -iname '*prob*.nii.gz' \) -print0)
fi
