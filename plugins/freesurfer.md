# FreeSurfer

**FreeSurfer** · Plugin version 1.1.1 · Runtime 7.3.2

Standalone FreeSurfer 7.3.2 anatomical reconstruction using recon-all.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.1/freesurfer-1.1.1.nipa-plugin.tar.gz)

SHA-256: `0f4afbab95d3b279476863f24dbaf997397c8cbbd62cb027a97c19c08a231dc5`

[Upstream project](https://surfer.nmr.mgh.harvard.edu/)

[All official plugins](../official-plugins.md)

## Package files

- [plugin.yaml](#package-file-1)
- [__init__.py](#package-file-2)
- [adapter.py](#package-file-3)
- [run.sh](#package-file-4)

### Package file 1

**plugin.yaml**

```yaml
schema: nipa.plugin/v3
plugin:
  id: freesurfer
  name: FreeSurfer
  version: 1.1.1
  category: structural
  description: Standalone FreeSurfer 7.3.2 anatomical reconstruction using recon-all.
transformation:
  inputs:
    t1w:
      type: imaging.mri.anatomical.image
      source: dataset
      cardinality: one
      label: T1-weighted anatomical MRI
      attributes:
        contrast: T1w
  outputs:
    reconstruction:
      type: imaging.mri.anatomical.reconstruction
      attributes:
        representation: anatomical_reconstruction
        method: freesurfer
  capability:
    title: FreeSurfer anatomical reconstruction
    goal: Generate a reusable FreeSurfer subject reconstruction from T1w MRI
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 8
    memory_gb: 32
    time: '48:00:00'
    gpu_count: 0
    scratch_gb: 64
  runtime:
    requirements:
    - id: freesurfer-7.3.2
      kind: container
      version: 7.3.2
      acquisition: site_provided
      binding_env: FREESURFER_SIF
      discovery:
        filename_patterns:
        - '*freesurfer*7.3.2*.sif'
        - '*Freesurfer*7.3.2*.sif'
        - '*freesurfer*.sif'
      runtimes:
      - apptainer
      - singularity
      capabilities:
      - freesurfer.core
      - freesurfer.recon_all
    licenses:
    - id: freesurfer
      required: true
      env: FS_LICENSE
      target: /opt/freesurfer/license.txt
  outputs:
    root: derivatives/freesurfer
    environment: FREESURFER_OUT_ROOT
    scanner: adapter.py:scan_outputs
    artifact_adapter: adapter.py:discover_artifacts
  provenance:
    capture:
    - resolved_inputs
    - parameters
    - runtime_requirements
    - resource_request
    - execution_identity
    portable_spec: true
```

### Package file 2

**__init__.py**

```python
"""NIPA official FreeSurfer plugin."""
```

### Package file 3

**adapter.py**

```python
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Iterable

from nipa.artifacts.model import Artifact, resource_for_path


def _entities(name: str) -> tuple[str, str]:
    if "_ses-" in name:
        subject, suffix = name.split("_ses-", 1)
        return subject, "ses-" + suffix
    return name, "no-session"


def scan_outputs(root: Path) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    refs = root / ".nipa_references"
    if not refs.is_dir():
        return {"results": results}
    for ref in sorted(refs.glob("*.path")):
        raw = ref.read_text(encoding="utf-8").strip()
        if not raw:
            continue
        path = Path(raw).expanduser().resolve()
        required = [path / "mri/norm.mgz", path / "mri/wmparc.mgz", path / "mri/transforms/talairach.xfm"]
        if path.is_dir() and all(item.is_file() for item in required):
            subject, session = _entities(ref.stem)
            results.append({"subject": subject, "session": session, "path": str(path), "reference": str(ref.resolve())})
    return {"results": results}


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    version = (definition.get("plugin") or {}).get("version")
    for record in scan_payload.get("results", []):
        path = Path(record["path"]).resolve()
        subject = str(record["subject"]); session = str(record["session"])
        components = [path / "mri/norm.mgz", path / "mri/wmparc.mgz", path / "mri/transforms/talairach.xfm"]
        key = f"imaging.mri.anatomical.reconstruction|{subject}|{session}|{path}"
        resources = [resource_for_path(path, role="primary", format="surface_reconstruction_dir")]
        resources.extend(resource_for_path(p, role=f"component:{p.name}", format=p.suffix.lstrip(".")) for p in components)
        yield Artifact(
            id="art_" + hashlib.sha256(key.encode()).hexdigest()[:24],
            type="imaging.mri.anatomical.reconstruction",
            entities={"subject": subject, "session": session},
            attributes={"representation": "anatomical_reconstruction", "method": "freesurfer"},
            resources=tuple(resources),
            annotations={"reference_record": record.get("reference")},
            provenance={"generator": {"transformation": "freesurfer", "version": version}},
            origin={"kind": "generated"},
        )
```

### Package file 4

**run.sh**

```bash
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
```
