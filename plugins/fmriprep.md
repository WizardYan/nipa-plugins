# fMRIPrep

**fMRIPrep** · Plugin version 1.0.0 · Runtime 25.2.4

BIDS-native preprocessing for resting-state and task functional MRI.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/fmriprep-1.0.0.nipa-plugin.tar.gz)

SHA-256: `98caab763a71209e0b70f0001cab08a9c98fe5916bf649df8cecb2885dbcbdb5`

[Upstream project](https://fmriprep.org/)

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
  id: fmriprep
  name: fMRIPrep
  version: 1.0.0
  category: functional
  description: BIDS-native preprocessing for resting-state and task functional MRI.
transformation:
  inputs:
    bold:
      type: imaging.mri.functional.bold
      source: dataset
      cardinality: many
    t1w:
      type: imaging.mri.anatomical.image
      source: dataset
      required: false
      attributes:
        contrast: T1w
  outputs:
    preprocessed_bold:
      type: imaging.mri.functional.bold
      attributes:
        processing_state: preprocessed
    bold_reference:
      type: imaging.mri.functional.bold
      attributes:
        representation: reference
    functional_brain_mask:
      type: imaging.mri.functional.mask
      attributes:
        mask_type: brain
    anatomical_brain_mask:
      type: imaging.mri.anatomical.mask
      attributes:
        mask_type: brain
    preprocessed_t1w:
      type: imaging.mri.anatomical.image
      attributes:
        contrast: T1w
        processing_state: preprocessed
    confounds:
      type: imaging.mri.functional.timeseries
      attributes:
        representation: confounds
    spatial_transform:
      type: transform
    report:
      type: report
    metadata:
      type: metadata
    text:
      type: text
    freesurfer_reconstruction:
      type: imaging.mri.anatomical.reconstruction
      virtual: true
      attributes:
        representation: anatomical_reconstruction
        method: freesurfer
    derivatives_dataset:
      type: dataset.derivatives.bids
      virtual: true
      attributes:
        standard: BIDS
        dataset_type: derivative
        processing_state: preprocessed
        pipeline_name: fmriprep
  capability:
    title: Functional MRI preprocessing
    goal: Preprocess BOLD data using a BIDS-native workflow
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 16
    memory_gb: 64
    time: '48:00:00'
    gpu_count: 0
    scratch_gb: 100
  runtime:
    requirements:
    - id: fmriprep-25.2.4
      kind: container
      version: 25.2.4
      acquisition: managed
      binding_env: FMRIPREP_SIF
      discovery:
        filename_patterns:
        - '*fmriprep*25.2.4*.sif'
        - '*fmriprep*.sif'
      runtimes:
      - apptainer
      - singularity
      sources:
      - uri: docker://nipreps/fmriprep@sha256:37ca2547caba3aa0b7c01434bc7924a7497e097deb9da6de041cd990abc6b475
        digest: sha256:37ca2547caba3aa0b7c01434bc7924a7497e097deb9da6de041cd990abc6b475
        official: true
        approximate_size_gb: 2.47
    licenses:
    - id: freesurfer
      required: true
      env: FS_LICENSE
      target: /license.txt
  outputs:
    root: derivatives/fmriprep
    environment: FMRIPREP_OUT_ROOT
    formats:
    - id: preprocessed_bold
      label: Preprocessed BOLD
      group: Functional
      patterns:
      - '*desc-preproc_bold.nii'
      - '*desc-preproc_bold.nii.gz'
    - id: bold_reference
      label: BOLD reference
      group: Functional
      patterns:
      - '*boldref.nii'
      - '*boldref.nii.gz'
    - id: functional_brain_mask
      label: Functional brain mask
      group: Masks
      patterns:
      - '*/func/*brain_mask.nii'
      - '*/func/*brain_mask.nii.gz'
    - id: anatomical_brain_mask
      label: Anatomical brain mask
      group: Masks
      patterns:
      - '*/anat/*brain_mask.nii'
      - '*/anat/*brain_mask.nii.gz'
    - id: preprocessed_t1w
      label: Preprocessed T1w
      group: Anatomy
      patterns:
      - '*desc-preproc_T1w.nii'
      - '*desc-preproc_T1w.nii.gz'
      - '*desc-preproc_t1w.nii'
      - '*desc-preproc_t1w.nii.gz'
    - id: nifti
      label: fMRIPrep NIfTI derivative
      group: Images
      patterns:
      - '*.nii'
      - '*.nii.gz'
    - id: html_report
      label: fMRIPrep visual report
      group: Reports
      patterns:
      - '*.html'
      - '*.htm'
      role: report
    - id: confounds
      label: Confounds time series
      group: Functional
      patterns:
      - '*desc-confounds_timeseries.tsv'
      - '*desc-confounds_regressors.tsv'
    - id: spatial_transform
      label: Spatial transform
      group: Transforms
      patterns:
      - '*_xfm.h5'
      - '*_xfm.txt'
    - id: metadata
      label: Metadata
      group: Metadata
      patterns:
      - '*.json'
      - '*.tsv'
      - '*.csv'
    - id: text
      label: Text output
      group: Logs & text
      patterns:
      - '*.txt'
      - '*.log'
      - '*.out'
      - '*.err'
    exclude:
    - work/**
    - '**/work/**'
    - .nipa_complete/**
    - '**/.nipa_complete/**'
    artifact_adapter: adapter.py:discover_artifacts
ui:
  modalities:
  - func
```

### Package file 2

**__init__.py**

*Empty file.*

### Package file 3

**adapter.py**

```python
"""Translate fMRIPrep/FreeSurfer-native outputs into NIPA semantic artifacts."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any, Iterable

from nipa.artifacts.adapters.patterns import discover_pattern_artifacts
from nipa.artifacts.model import Artifact, resource_for_path

_FS_ENTITY_RE = re.compile(r"^(sub-[A-Za-z0-9]+)(?:_(ses-[A-Za-z0-9]+))?$")


def _virtual_id(kind: str, path: Path, subject: str | None = None, session: str | None = None) -> str:
    identity = f"{kind}|{path.resolve()}|{subject or ''}|{session or ''}"
    return "art_" + hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]


def _scan_targets(scan_payload: dict[str, Any]) -> list[tuple[str, str]]:
    """Return target identities represented by the current fMRIPrep output scan."""
    values: list[tuple[str, str]] = []
    for record in scan_payload.get("results", []):
        subject = str(record.get("subject") or "").strip()
        session = str(record.get("session") or "").strip() or "no-session"
        if subject.startswith("sub-") and subject != "unknown-subject":
            pair = (subject, session)
            if pair not in values:
                values.append(pair)
    return values


def _discover_derivatives_dataset(root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    """Publish target-scoped semantic views over one BIDS Derivatives dataset root.

    XCP-D natively consumes a derivatives dataset directory rather than isolated BOLD
    files.  The same physical root is therefore represented once per target so the
    current target-scoped NIPA resolver can bind it without encoding an fMRIPrep path
    in the downstream plugin.
    """
    description = root / "dataset_description.json"
    if not description.is_file():
        return
    try:
        dataset_description = json.loads(description.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        dataset_description = {}
    version = (definition.get("plugin") or {}).get("version")
    for subject, session in _scan_targets(scan_payload):
        yield Artifact(
            id=_virtual_id("dataset.derivatives.bids", root, subject, session),
            type="dataset.derivatives.bids",
            entities={"subject": subject, "session": session},
            attributes={
                **({"bids_version": str(dataset_description["BIDSVersion"])} if dataset_description.get("BIDSVersion") else {}),
                "standard": "BIDS",
                "dataset_type": "derivative",
                "processing_state": "preprocessed",
                "pipeline_name": "fmriprep",
                "pipeline_version": str(version or ""),
            },
            annotations={"virtual": True, "dataset_description": str(description.resolve()), "native_layout": "fmriprep"},
            resources=(resource_for_path(root, role="primary", format="bids_derivatives_directory"),),
            provenance={"generator": {"transformation": "fmriprep", "version": version}},
            origin={"kind": "generated"},
        )


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    yield from discover_pattern_artifacts(root=root, definition=definition, scan_payload=scan_payload)
    yield from _discover_derivatives_dataset(root, definition, scan_payload)

    fs_root = root / "sourcedata" / "freesurfer"
    if not fs_root.is_dir():
        return
    required = ("mri/norm.mgz", "mri/wmparc.mgz", "mri/transforms/talairach.xfm")
    for subject_dir in sorted(fs_root.iterdir()):
        if not subject_dir.is_dir():
            continue
        match = _FS_ENTITY_RE.match(subject_dir.name)
        if not match:
            continue
        components = [subject_dir / rel for rel in required]
        if not all(item.is_file() for item in components):
            continue
        subject = match.group(1)
        session = match.group(2) or "no-session"
        yield Artifact(
            id=_virtual_id("imaging.mri.anatomical.reconstruction", subject_dir),
            type="imaging.mri.anatomical.reconstruction",
            entities={"subject": subject, "session": session},
            attributes={"representation": "anatomical_reconstruction", "method": "freesurfer"},
            annotations={"components": [str(item.resolve()) for item in components], "virtual": True},
            resources=tuple([resource_for_path(subject_dir, role="primary", format="surface_reconstruction_dir")] + [resource_for_path(item, role=f"component:{item.name}", format=item.suffix.lstrip(".")) for item in components]),
            provenance={"generator": {"transformation": "fmriprep", "version": (definition.get("plugin") or {}).get("version")}},
            origin={"kind": "generated"},
        )
```

### Package file 4

**run.sh**

```bash
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
: "${FS_LICENSE:?FS_LICENSE was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
SIF="$FMRIPREP_SIF"
TEMPLATEFLOW_DIR="${TEMPLATEFLOW_DIR:-$PROJECT_ROOT/templateflow}"
WORK_ROOT="${FMRIPREP_WORK_ROOT:-${NIPA_EXECUTION_WORK_DIR:?NIPA_EXECUTION_WORK_DIR was not provided by the Executor}/fmriprep-work}"
SKIP="${NIPA_SKIP_EXISTING:-1}"
LABEL="${SUBJECT#sub-}"; SES_LABEL="${SESSION#ses-}"
SUCCESS="$OUT_ROOT/.nipa_complete/${SUBJECT}_${SESSION}.complete"
[[ "$SKIP" == 1 && -f "$SUCCESS" ]] && { echo "Already completed: $SUBJECT $SESSION"; exit 0; }
[[ -f "$SIF" ]] || { echo "ERROR: fMRIPrep container not found: $SIF" >&2; exit 1; }
[[ -f "$FS_LICENSE" ]] || { echo "ERROR: FreeSurfer license not found: $FS_LICENSE" >&2; exit 1; }
FUNC_DIR="$BIDS_ROOT/$SUBJECT"; [[ "$SESSION" != no-session ]] && FUNC_DIR="$FUNC_DIR/$SESSION"
compgen -G "$FUNC_DIR/func/*_bold.nii*" >/dev/null || { echo "ERROR: no BOLD image in $FUNC_DIR/func" >&2; exit 1; }
mkdir -p "$OUT_ROOT" "$WORK_ROOT/$SUBJECT" "$OUT_ROOT/.nipa_complete" "$TEMPLATEFLOW_DIR"
NPROCS="${NIPA_CPUS:-1}"
OMP_THREADS="$NPROCS"; (( OMP_THREADS > 8 )) && OMP_THREADS=8
NIPA_MEM_MB="${NIPA_MEMORY_MB:-4096}"
FMRIPREP_MEM_MB=$(( NIPA_MEM_MB * 90 / 100 ))
ARGS=(/data /out participant --participant-label "$LABEL" --nprocs "$NPROCS" --omp-nthreads "$OMP_THREADS" --mem "$FMRIPREP_MEM_MB" --output-spaces MNI152NLin2009cAsym:res-2 T1w --fs-license-file /license.txt --skip-bids-validation --stop-on-first-crash)
[[ "$SESSION" != no-session ]] && ARGS+=(--session-label "$SES_LABEL")
"$NIPA_CONTAINER_RUNTIME" run --cleanenv \
  --bind "$BIDS_ROOT:/data:ro" \
  --bind "$OUT_ROOT:/out" \
  --bind "$WORK_ROOT:/work" \
  --bind "$FS_LICENSE:/license.txt:ro" \
  --bind "$TEMPLATEFLOW_DIR:/templateflow" \
  --env TEMPLATEFLOW_HOME=/templateflow \
  "$SIF" "${ARGS[@]}" -w "/work/$SUBJECT"
touch "$SUCCESS"
```
