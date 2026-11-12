# LST-AI (CPU)

**LST-AI (CPU)** · Plugin version 1.0.3 · Runtime 2.0.0rc1-cpu

CPU-only multiple-sclerosis lesion segmentation from paired T1w and FLAIR MRI.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.2/lst_ai-1.0.3.nipa-plugin.tar.gz)

SHA-256: `51c18ed01eb76f616330c0e7ad7b71a3c582f41436da36f59cfa289bfe78703f`

[Upstream project](https://github.com/CompImg/LST-AI)

[All official plugins](../official-plugins.md)

## Package files

- [README.md](#package-file-1)
- [plugin.yaml](#package-file-2)
- [adapter.py](#package-file-3)
- [run.sh](#package-file-4)

### Package file 1

**README.md**

# LST-AI CPU plugin for NIPA

Standalone Plugin SDK v3 wrapper for research-only MS lesion segmentation.
Scientific software: [CompImg/LST-AI](https://github.com/CompImg/LST-AI) (MIT).
The plugin **does not redistribute** LST-AI or its model weights.

## Installation

```bash
nipa plugin install lst_ai-1.0.2.nipa-plugin.tar.gz --replace
```

On an HPC node with Singularity available, acquire the upstream CPU image:

```bash
singularity pull lst-ai-2.0.0rc1-cpu.sif docker://jqmcginnis/lst-ai:v2.0.0rc1-cpu
```

Configure the NIPA site's runtime resolution to provide:

- `LST_AI_SIF`: absolute path to the site-managed `.sif` image.
- `NIPA_CONTAINER_RUNTIME`: `singularity`.

The upstream image tag must be checked and its immutable digest recorded before
production deployment. NIPA records plugin package identity separately from
the scientific container identity.

## Contract

- Inputs: NIPA-resolved T1w and FLAIR NIfTI images for the same subject/session.
- Input paths are read from `NIPA_INPUT_MANIFEST` dataset bindings, not
  `NIPA_INPUT_T1W_PATH` / `NIPA_INPUT_FLAIR_PATH` (artifact-only exports).
- Runtime: CPU-only Singularity, `--device cpu`.
- Outputs: `derivatives/lst_ai/sub-*/[ses-*/]`.
- Optional probability maps are copied from the working directory into
  `probability_maps/` so they appear in Results.
- The output adapter assigns semantic Artifact types only to recognized names;
  unknown NIfTI derivatives remain ordinary files in Results.

NIPA-selected inputs must both be skull-stripped or both unstripped. The default
is unstripped. The plugin does not silently select a file when multiple T1w or
FLAIR candidates exist.

## Qualification status

The manifest is SDK-valid and offline mock execution passes. Real Singularity
execution, output filename matching for the pinned LST-AI version, HPC resource
requirements, and scientific outputs must be validated at the deployment site.
This is **not** clinical software.

### Package file 2

**plugin.yaml**

```yaml
schema: nipa.plugin/v3
plugin:
  id: lst_ai
  name: LST-AI (CPU)
  version: 1.0.3
  category: structural
  description: CPU-only multiple-sclerosis lesion segmentation from paired T1w and FLAIR MRI.
  repository: https://github.com/CompImg/LST-AI
transformation:
  inputs:
    t1w:
      type: imaging.mri.anatomical.image
      source: dataset
      cardinality: one
      attributes:
        contrast: T1w
    flair:
      type: imaging.mri.anatomical.image
      source: dataset
      cardinality: one
      attributes:
        contrast: FLAIR
  outputs:
    lesion_mask:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: lesion
        method: lst_ai
        representation: binary_mask
    lesion_probability:
      type: imaging.mri.anatomical.image
      required: false
      attributes:
        contrast: lesion_probability
        method: lst_ai
    lesion_annotation:
      type: imaging.mri.anatomical.segmentation
      required: false
      attributes:
        segmentation_type: lesion
        method: lst_ai
        representation: anatomical_annotation
    metadata:
      type: metadata
      required: false
      attributes:
        scope: lesion_segmentation
        method: lst_ai
  parameters:
    mode:
      type: enum
      default: segmentation_and_annotation
      values:
        segmentation_and_annotation: segmentation_and_annotation
        segmentation_only: segmentation_only
    threshold:
      type: number
      default: 0.5
      minimum: 0.0
      maximum: 1.0
    lesion_threshold_mm3:
      type: integer
      default: 0
      minimum: 0.0
    stripped:
      type: boolean
      default: false
    fast_mode:
      type: boolean
      default: false
    probability_map:
      type: boolean
      default: false
  capability:
    title: MS lesion segmentation
    goal: Segment lesions in paired T1w and FLAIR images using LST-AI on CPU
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 8
    memory_gb: 32
    time: '24:00:00'
    gpu_count: 0
    scratch_gb: 64
  runtime:
    requirements:
    - id: lst-ai-2.0.0rc1-cpu
      kind: container
      version: 2.0.0rc1-cpu
      acquisition: site_provided
      binding_env: LST_AI_SIF
      discovery:
        filename_patterns:
        - '*lst*ai*2.0.0rc1*cpu*.sif'
        - '*lst*ai*cpu*.sif'
      runtimes:
      - singularity
  outputs:
    root: derivatives/lst_ai
    environment: LST_AI_OUT_ROOT
    formats:
    - id: lesion_mask
      label: LST-AI NIfTI output
      group: Lesion outputs
      patterns:
      - '*.nii'
      - '*.nii.gz'
    - id: metadata
      label: LST-AI metadata
      group: Metadata
      patterns:
      - '*.json'
      - '*.tsv'
      - '*.csv'
    artifact_adapter: adapter.py:discover_artifacts
ui:
  modalities:
  - anat
upstream:
- name: LST-AI
  version: 2.0.0rc1
  runtime_requirement: lst-ai-2.0.0rc1-cpu
  homepage: https://github.com/CompImg/LST-AI
  repository: https://github.com/CompImg/LST-AI
  license: MIT
  redistribution:
    mode: site_provided
    permitted: false
```

### Package file 3

**adapter.py**

```python
"""Expose recognizable LST-AI outputs as producer-neutral NIPA Artifacts.

Unknown NIfTI files remain visible in Results but do not acquire an invented
semantic type. LST-AI's output naming must be rechecked against the pinned SIF.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Iterable

from nipa.artifacts.model import Artifact, resource_for_path


def _output_kind(name: str) -> tuple[str, dict[str, str]] | None:
    lower = name.lower()
    if not lower.endswith((".nii", ".nii.gz")):
        return None
    if "probability" in lower or "probmap" in lower or "_prob" in lower:
        return "imaging.mri.anatomical.image", {
            "contrast": "lesion_probability", "method": "lst_ai", "space": "FLAIR"
        }
    if "annotated_seg-lst" in lower or "lesion_annotation" in lower:
        return "imaging.mri.anatomical.segmentation", {
            "segmentation_type": "lesion", "method": "lst_ai",
            "representation": "anatomical_annotation", "space": "FLAIR"
        }
    if "seg-lst" in lower or "lesion_mask" in lower or "lesion_seg" in lower:
        return "imaging.mri.anatomical.segmentation", {
            "segmentation_type": "lesion", "method": "lst_ai",
            "representation": "binary_mask", "space": "FLAIR"
        }
    return None


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    """Construct stable artifacts only for recognized output filenames."""
    root = root.resolve()
    version = (definition.get("plugin") or {}).get("version")
    seen: set[str] = set()
    for record in scan_payload.get("results", []):
        subject = str(record.get("subject") or "")
        session = str(record.get("session") or "no-session")
        if not subject.startswith("sub-"):
            continue
        for item in record.get("files", []):
            relative = Path(str(item.get("path") or ""))
            if relative.is_absolute() or ".." in relative.parts:
                continue
            path = (root / relative).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                continue
            kind = _output_kind(path.name)
            if kind is None:
                continue
            artifact_type, attributes = kind
            identity = f"lst_ai|{artifact_type}|{subject}|{session}|{relative.as_posix()}"
            artifact_id = "art_" + hashlib.sha256(identity.encode("utf-8")).hexdigest()[:24]
            if artifact_id in seen:
                continue
            seen.add(artifact_id)
            yield Artifact(
                id=artifact_id,
                type=artifact_type,
                entities={"subject": subject, "session": session},
                attributes=attributes,
                resources=(resource_for_path(
                    path, role="primary", format="nifti",
                    attributes={"relative_path": relative.as_posix(), "size_bytes": item.get("size_bytes")}
                ),),
                annotations={"name": path.name, "group": item.get("group"), "viewer": item.get("viewer")},
                provenance={"generator": {"transformation": "lst_ai", "version": version}},
                origin={"kind": "generated"},
            )
```

### Package file 4

**run.sh**

```bash
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
```
