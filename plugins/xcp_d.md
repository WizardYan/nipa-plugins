# XCP-D

**XCP-D** · Plugin version 26.2.1 · Runtime 26.2.0

Containerized resting-state fMRI post-processing from compatible BIDS preprocessing derivatives.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.2/xcp_d-26.2.1.nipa-plugin.tar.gz)

SHA-256: `a447410b28f1d05736329fcd1a572a68ac2d61d9b85854328dd2be0bb4655e65`

[Upstream project](https://xcp-d.readthedocs.io/)

[All official plugins](../official-plugins.md)

## Package files

- [plugin.yaml](#package-file-1)
- [adapter.py](#package-file-2)
- [cli.py](#package-file-3)
- [run.sh](#package-file-4)

### Package file 1

**plugin.yaml**

```yaml
schema: nipa.plugin/v3
plugin:
  id: xcp_d
  name: XCP-D
  version: 26.2.1
  category: functional
  description: Containerized resting-state fMRI post-processing from compatible BIDS preprocessing derivatives.
scientific_outputs:
- id: functional.denoised_bold
  label: Denoised BOLD
  description: Analysis-ready BOLD after functional post-processing.
  category: Functional MRI
  tags: [postprocessing, bold]
  educational_summary: Reduces nuisance and motion-related effects before downstream analysis.
  requirement:
    type: imaging.mri.functional.bold
    attributes: {processing_state: postprocessed, denoised: true}
- id: functional.connectivity_matrix
  label: Functional connectivity matrix
  description: Pairwise functional connectivity estimates between regions.
  category: Functional MRI
  tags: [connectivity, resting-state]
  requirement:
    type: imaging.mri.functional.connectivity
    attributes: {representation: matrix, measure: pearson_correlation, processing_state: postprocessed}
- id: functional.alff
  label: ALFF map
  description: Amplitude of low-frequency fluctuation map.
  category: Functional MRI
  tags: [resting-state, alff]
  requirement:
    type: imaging.mri.functional.intrinsic_activity
    attributes: {metric: ALFF, processing_state: postprocessed}
- id: functional.reho
  label: ReHo map
  description: Regional homogeneity map.
  category: Functional MRI
  tags: [resting-state, reho]
  requirement:
    type: imaging.mri.functional.intrinsic_activity
    attributes: {metric: ReHo, processing_state: postprocessed}
transformation:
  inputs:
    derivatives:
      type: dataset.derivatives.bids
      source: artifact
      cardinality: one
      label: Functional MRI preprocessing derivatives
      attributes:
        standard: BIDS
        processing_state: preprocessed
  outputs:
    denoised_bold:
      type: imaging.mri.functional.bold
      attributes:
        processing_state: postprocessed
        denoised: true
        method: xcp_d
    parcellated_timeseries:
      type: imaging.mri.functional.timeseries
      attributes:
        representation: parcel
        processing_state: postprocessed
        method: xcp_d
    connectivity:
      type: imaging.mri.functional.connectivity
      attributes:
        representation: matrix
        measure: pearson_correlation
        processing_state: postprocessed
        method: xcp_d
    alff:
      type: imaging.mri.functional.intrinsic_activity
      attributes:
        metric: ALFF
        processing_state: postprocessed
        method: xcp_d
    reho:
      type: imaging.mri.functional.intrinsic_activity
      attributes:
        metric: ReHo
        processing_state: postprocessed
        method: xcp_d
    qc:
      type: qc
      attributes:
        scope: functional_mri
        method: xcp_d
    report:
      type: report
      attributes:
        report_type: functional_postprocessing
        format: html
        method: xcp_d
    metadata:
      type: metadata
      attributes:
        scope: functional_mri
        method: xcp_d
  parameters:
    mode:
      type: enum
      default: nichart
      description: XCP-D processing mode. Mode-owned defaults remain under XCP-D control.
      values:
        linc: linc
        abcd: abcd
        nichart: nichart
        none: none
    file_format:
      type: enum
      default: auto
      description: Optional override of the mode-selected input/output representation.
      values:
        auto: auto
        nifti: nifti
        cifti: cifti
    nuisance_regressors:
      type: enum
      default: auto
      description: Built-in nuisance regression strategy or automatic mode default.
      values:
        auto: auto
        24P: 24P
        27P: 27P
        36P: 36P
        acompcor: acompcor
        acompcor_gsr: acompcor_gsr
        aroma: aroma
        aroma_gsr: aroma_gsr
        gsr_only: gsr_only
        none: none
    fd_thresh:
      type: string
      default: auto
      description: Framewise-displacement threshold in mm, or auto to retain the mode default.
    min_time:
      type: string
      default: auto
      description: Minimum retained low-motion duration in seconds, or auto to retain the mode default.
    smoothing:
      type: string
      default: auto
      description: Smoothing FWHM in mm, or auto to retain the mode default.
    despike:
      type: enum
      default: auto
      values:
        auto: auto
        'yes': y
        'no': n
    combine_runs:
      type: enum
      default: auto
      values:
        auto: auto
        'yes': y
        'no': n
    bandpass_filter:
      type: enum
      default: auto
      values:
        auto: auto
        enabled: enabled
        disabled: disabled
    lower_bpf:
      type: string
      default: auto
      description: Lower bandpass cutoff in Hz, or auto.
    upper_bpf:
      type: string
      default: auto
      description: Upper bandpass cutoff in Hz, or auto.
    atlases:
      type: string
      default: auto
      description: Space- or comma-separated atlas names; auto uses the XCP-D built-in atlas set.
    skip_outputs:
      type: string
      default: ''
      description: Optional comma/space-separated subset of alff,reho,parcellation,connectivity.
  capability:
    title: Resting-state fMRI post-processing
    goal: Produce denoised and analysis-ready functional representations from preprocessing derivatives
    abstraction: artifact-to-native-adapter
    native_engine: xcp_d
  education:
    summary: Denoises preprocessed functional MRI and produces standardized resting-state derivatives.
    why: Motion censoring and nuisance regression reduce non-neural variation in downstream measures.
    considerations:
    - Denoising choices can materially affect connectivity estimates.
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 8
    memory_gb: 96
    time: '24:00:00'
    gpu_count: 0
    scratch_gb: 100
  runtime:
    requirements:
    - id: xcp-d-26.2.0
      kind: container
      version: 26.2.0
      acquisition: site_provided
      binding_env: XCPD_SIF
      discovery:
        filename_patterns:
        - '*xcp*d*26.2.0*.sif'
        - '*xcp_d*.sif'
        - '*xcp-d*.sif'
      runtimes:
      - apptainer
      - singularity
      capabilities:
      - xcp_d.postprocessing
    licenses:
    - id: freesurfer
      required: false
      env: FS_LICENSE
      target: /license.txt
  outputs:
    root: derivatives/xcp_d
    environment: XCPD_OUT_ROOT
    formats:
    - id: denoised_bold
      label: Denoised BOLD
      group: Functional
      patterns:
      - '*desc-denoised_bold.nii.gz'
      - '*desc-denoisedSmoothed_bold.nii.gz'
      - '*desc-denoised_bold.dtseries.nii'
      - '*desc-denoisedSmoothed_bold.dtseries.nii'
    - id: parcellated_timeseries
      label: Parcellated time series
      group: Time series
      patterns:
      - '*stat-mean_timeseries.tsv'
      - '*stat-mean_timeseries.ptseries.nii'
    - id: connectivity
      label: Functional connectivity matrix
      group: Connectivity
      patterns:
      - '*stat-pearsoncorrelation*_relmat.tsv'
      - '*stat-pearsoncorrelation*_boldmap.pconn.nii'
    - id: alff
      label: ALFF
      group: Functional measures
      patterns:
      - '*stat-alff*_boldmap.nii.gz'
      - '*stat-alff*_boldmap.dscalar.nii'
    - id: reho
      label: ReHo
      group: Functional measures
      patterns:
      - '*stat-reho*_boldmap.nii.gz'
      - '*stat-reho*_boldmap.dscalar.nii'
    - id: qc
      label: Functional quality control
      group: Quality control
      patterns:
      - '*desc-linc_qc.tsv'
      - '*desc-abcc_qc.csv'
      - '*desc-abcc_qc.tsv'
    - id: report
      label: XCP-D visual report
      group: Reports
      role: report
      patterns:
      - '*.html'
      - '*.htm'
    - id: metadata
      label: XCP-D metadata
      group: Metadata
      patterns:
      - 'dataset_description.json'
      - '*desc-denoised_bold.json'
      - '*desc-denoisedSmoothed_bold.json'
      - '*outliers.tsv'
      - '*design.tsv'
    exclude:
    - work/**
    - '**/work/**'
    - .nipa_complete/**
    - '**/.nipa_complete/**'
    artifact_adapter: adapter.py:discover_artifacts
  stages:
  - id: denoise
    label: Denoising and nuisance regression
    produces:
    - imaging.mri.functional.bold
  - id: measures
    label: Resting-state functional measures
    depends_on:
    - denoise
    produces:
    - imaging.mri.functional.intrinsic_activity
  - id: parcellation
    label: Atlas parcellation
    depends_on:
    - denoise
    produces:
    - imaging.mri.functional.timeseries
  - id: connectivity
    label: Functional connectivity
    depends_on:
    - parcellation
    produces:
    - imaging.mri.functional.connectivity
  - id: qc
    label: Quality control and reports
    depends_on:
    - denoise
    produces:
    - qc
    - report
  provenance:
    native_engine: xcp_d
    capture:
    - resolved_inputs
    - parameters
    - runtime_requirements
    - resource_request
    - execution_identity
    - stage_sequence
    portable_spec: true
ui:
  modalities:
  - func
```

### Package file 2

**adapter.py**

```python
"""Map XCP-D BIDS-style derivatives onto software-neutral NIPA artifacts."""
from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from nipa.artifacts.adapters.patterns import discover_pattern_artifacts
from nipa.artifacts.model import Artifact


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    for artifact in discover_pattern_artifacts(root=root, definition=definition, scan_payload=scan_payload):
        payload = artifact.to_dict()
        attributes = dict(payload.get("attributes") or {})
        entities = dict(payload.get("entities") or {})

        # BIDS atlas is an entity parsed by the generic adapter only when the
        # vocabulary knows it. Preserve it semantically for downstream matching.
        path = artifact.local_path()
        name = path.name if path else ""
        if "_atlas-" in name:
            atlas = name.split("_atlas-", 1)[1].split("_", 1)[0]
            attributes.setdefault("atlas", atlas)
        if artifact.type == "imaging.mri.functional.connectivity":
            attributes.setdefault("representation", "matrix")
            attributes.setdefault("measure", "pearson_correlation")
        if artifact.type == "imaging.mri.functional.bold":
            attributes.setdefault("denoised", True)
        if artifact.type in {
            "imaging.mri.functional.bold",
            "imaging.mri.functional.timeseries",
            "imaging.mri.functional.intrinsic_activity",
            "imaging.mri.functional.connectivity",
        }:
            attributes.setdefault("processing_state", "postprocessed")

        payload["attributes"] = attributes
        payload["entities"] = entities
        yield Artifact.from_dict(payload)
```

### Package file 3

**cli.py**

```python
"""Translate NIPA XCP-D parameters into validated native CLI arguments."""
from __future__ import annotations

import json
import re
import sys
from typing import Any

MODES = {"linc", "abcd", "nichart", "none"}
NUISANCE = {"auto", "24P", "27P", "36P", "acompcor", "acompcor_gsr", "aroma", "aroma_gsr", "gsr_only", "none"}
SKIPPABLE = {"alff", "reho", "parcellation", "connectivity"}
SAFE_ATLAS = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.+-]*$")


def _as_number(value: Any, name: str, *, minimum: float | None = None) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() == "auto":
        return None
    try:
        number = float(text)
    except ValueError as exc:
        raise ValueError(f"{name} must be numeric or 'auto'") from exc
    if minimum is not None and number < minimum:
        raise ValueError(f"{name} must be >= {minimum}")
    return text


def build_arguments(params: dict[str, Any]) -> list[str]:
    mode = str(params.get("mode") or "nichart").strip()
    if mode not in MODES:
        raise ValueError(f"Invalid XCP-D mode: {mode}")
    args = ["--mode", mode]

    file_format = str(params.get("file_format") or "auto").strip()
    if file_format not in {"auto", "nifti", "cifti"}:
        raise ValueError(f"Invalid file_format: {file_format}")
    if file_format != "auto":
        args += ["--file-format", file_format]

    nuisance = str(params.get("nuisance_regressors") or "auto").strip()
    if nuisance not in NUISANCE:
        raise ValueError(f"Invalid nuisance_regressors: {nuisance}")
    if nuisance != "auto":
        args += ["--nuisance-regressors", nuisance]

    for key, flag, minimum in (
        ("fd_thresh", "--fd-thresh", 0.0),
        ("min_time", "--min-time", 0.0),
        ("smoothing", "--smoothing", 0.0),
        ("lower_bpf", "--lower-bpf", None),
        ("upper_bpf", "--upper-bpf", None),
    ):
        value = _as_number(params.get(key, "auto"), key, minimum=minimum)
        if value is not None:
            args += [flag, value]

    for key, flag in (("despike", "--despike"), ("combine_runs", "--combine-runs")):
        value = str(params.get(key) or "auto").strip()
        if value not in {"auto", "y", "n"}:
            raise ValueError(f"Invalid {key}: {value}")
        if value != "auto":
            args += [flag, value]

    bandpass = str(params.get("bandpass_filter") or "auto").strip()
    if bandpass not in {"auto", "enabled", "disabled"}:
        raise ValueError(f"Invalid bandpass_filter: {bandpass}")
    if bandpass == "disabled":
        args.append("--disable-bandpass-filter")

    atlases = str(params.get("atlases") or "auto").strip()
    if atlases.lower() != "auto":
        values = [x for x in re.split(r"[\s,]+", atlases) if x]
        if any(not SAFE_ATLAS.fullmatch(x) for x in values):
            raise ValueError("Atlas names may contain only letters, numbers, '.', '_', '+', and '-'")
        if values:
            args += ["--atlases", *values]

    skip = str(params.get("skip_outputs") or "").strip()
    if skip:
        values = [x for x in re.split(r"[\s,]+", skip) if x]
        bad = [x for x in values if x not in SKIPPABLE]
        if bad:
            raise ValueError("Invalid XCP-D skip outputs: " + ", ".join(bad))
        args += ["--skip", *values]
    return args


def main() -> int:
    params = json.loads(sys.stdin.read() or "{}")
    try:
        args = build_arguments(params)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    sys.stdout.buffer.write(b"\0".join(x.encode("utf-8") for x in args) + b"\0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

### Package file 4

**run.sh**

```bash
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
```
