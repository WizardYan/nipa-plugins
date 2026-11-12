# Thalamic Nuclei Segmentation

**Thalamic Nuclei Segmentation** · Plugin version 1.1.0 · Runtime 7.3.2

FreeSurfer thalamic nuclei segmentation as an independent Artifact producer.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/thalamic_nuclei-1.1.0.nipa-plugin.tar.gz)

SHA-256: `60785414c0a067ab317867d2941b5f17f81b212b6b16f733625965508f1accb6`

[Upstream project](https://surfer.nmr.mgh.harvard.edu/fswiki/ThalamicNuclei)

[All official plugins](../official-plugins.md)

## Package files

- [plugin.yaml](#package-file-1)
- [__init__.py](#package-file-2)
- [outputs.py](#package-file-3)
- [run.sh](#package-file-4)

### Package file 1

**plugin.yaml**

```yaml
schema: nipa.plugin/v3
plugin:
  id: thalamic_nuclei
  name: Thalamic Nuclei Segmentation
  version: 1.1.0
  category: structural
  description: FreeSurfer thalamic nuclei segmentation as an independent Artifact
    producer.
transformation:
  inputs:
    reconstruction:
      type: imaging.mri.anatomical.reconstruction
      source: artifact
      cardinality: one
      label: FreeSurfer anatomical reconstruction
      attributes:
        representation: anatomical_reconstruction
        method: freesurfer
  outputs:
    segmentation:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: structure
        structure: thalamic_nuclei
        method: freesurfer
  capability:
    title: Thalamic nuclei segmentation
    goal: Generate thalamic nuclei segmentation from a FreeSurfer anatomical reconstruction
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 1
    memory_gb: 8
    time: 04:00:00
    gpu_count: 0
    scratch_gb: 8
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
        - '*freesurfer*.sif'
      runtimes:
      - apptainer
      - singularity
      capabilities:
      - freesurfer.core
      - freesurfer.tracula
      - freesurfer.recon_all
    licenses:
    - id: freesurfer
      required: true
      env: FS_LICENSE
      target: /opt/freesurfer/license.txt
  outputs:
    root: derivatives/thalamic_nuclei
    environment: THALAMIC_NUCLEI_OUT_ROOT
    scanner: outputs.py:scan_outputs
    artifact_adapter: outputs.py:discover_artifacts
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

*Empty file.*

### Package file 3

**outputs.py**

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
    refs = root / "references"
    if not refs.is_dir():
        return {"results": results}
    for reference in sorted(refs.glob("*.paths")):
        subject, session = _entities(reference.stem)
        paths = []
        for raw in reference.read_text(encoding="utf-8").splitlines():
            path = Path(raw.strip()).expanduser()
            if path.is_file():
                paths.append(str(path.resolve()))
        if paths:
            results.append({"subject": subject, "session": session, "paths": paths, "reference": str(reference.resolve())})
    return {"results": results}


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    version = (definition.get("plugin") or {}).get("version")
    for record in scan_payload.get("results", []):
        subject = str(record["subject"]); session = str(record["session"])
        paths = [Path(x).resolve() for x in record.get("paths", []) if Path(x).is_file()]
        if not paths:
            continue
        preferred = next((p for p in paths if ".T1." in p.name), paths[0])
        ordered = [preferred] + [p for p in paths if p != preferred]
        resources = [resource_for_path(ordered[0], role="primary", format="mgz")]
        resources.extend(resource_for_path(p, role=f"component:{p.name}", format="mgz") for p in ordered[1:])
        key = f"imaging.mri.anatomical.segmentation|thalamic_nuclei|{subject}|{session}|" + "|".join(str(p) for p in ordered)
        yield Artifact(
            id="art_" + hashlib.sha256(key.encode()).hexdigest()[:24],
            type="imaging.mri.anatomical.segmentation",
            entities={"subject": subject, "session": session},
            attributes={
                "segmentation_type": "structure",
                "structure": "thalamic_nuclei",
                "method": "freesurfer",
            },
            resources=tuple(resources),
            annotations={"reference_record": record.get("reference")},
            provenance={"generator": {"transformation": "thalamic_nuclei", "version": version}},
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
```
