# CAT12

**CAT12** · Plugin version 1.1.1 · Runtime brainprep-anat-v1

T1w tissue segmentation, morphometry, and image-quality reporting.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.2/cat12-1.1.1.nipa-plugin.tar.gz)

SHA-256: `86e5d7eabe610e9b0bf7a6e7e8e32eaf5e3fa34f0eff12ae3e95c756eed35449`

[Upstream project](https://github.com/ChristianGaser/cat12)

[All official plugins](../official-plugins.md)

## Package files

- [plugin.yaml](#package-file-1)
- [run.sh](#package-file-2)
- [run_cat12_one.sh](#package-file-3)

### Package file 1

**plugin.yaml**

```yaml
schema: nipa.plugin/v3
plugin:
  id: cat12
  name: CAT12
  version: 1.1.1
  category: structural
  description: T1w tissue segmentation, morphometry, and image-quality reporting.
transformation:
  inputs:
    t1w:
      type: imaging.mri.anatomical.image
      attributes:
        contrast: T1w
      source: dataset
      cardinality: one
  outputs:
    smoothed_modulated_gm:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: tissue
        tissue: gray_matter
        method: cat12
        normalized: true
        modulated: true
        smoothed: true
    smoothed_modulated_wm:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: tissue
        tissue: white_matter
        method: cat12
        normalized: true
        modulated: true
        smoothed: true
    modulated_gm:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: tissue
        tissue: gray_matter
        method: cat12
        normalized: true
        modulated: true
    modulated_wm:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: tissue
        tissue: white_matter
        method: cat12
        normalized: true
        modulated: true
    normalized_tissue:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: tissue
        method: cat12
        space: normalized
        normalized: true
    native_tissue:
      type: imaging.mri.anatomical.segmentation
      attributes:
        segmentation_type: tissue
        method: cat12
        space: native
    deformation:
      type: transform
      attributes:
        method: cat12
    qc_report:
      type: qc
      attributes:
        scope: anatomical_mri
        method: cat12
    html_report:
      type: report
      attributes:
        report_type: morphometry
        format: html
        method: cat12
    table:
      type: table.feature
      attributes:
        domain: morphometry
        method: cat12
  capability:
    title: Brain morphometry
    goal: Segment tissue and measure gray/white matter morphology
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 8
    memory_gb: 32
    time: '12:00:00'
    gpu_count: 0
    scratch_gb: 32
  runtime:
    requirements:
    - id: cat12-brainprep-v1
      kind: container
      version: brainprep-anat-v1
      acquisition: managed
      binding_env: CAT12_SIF
      discovery:
        filename_patterns:
        - '*brainprep-anat*v1*.sif'
        - '*brainprep*anat*.sif'
        - '*cat12*.sif'
      runtimes:
      - apptainer
      - singularity
      sources:
      - uri: docker://neurospin/brainprep-anat@sha256:f999dfb4f6fa0c043a2f624314c5598765d2cb1e5ecc86c2874cfa53a44cd88d
        digest: sha256:f999dfb4f6fa0c043a2f624314c5598765d2cb1e5ecc86c2874cfa53a44cd88d
        official: true
        approximate_size_gb: 15.72
  outputs:
    root: derivatives/cat12
    environment: CAT12_OUT_ROOT
    formats:
    - id: smoothed_modulated_gm
      label: Smoothed modulated gray matter
      group: VBM
      patterns:
      - smwp1*.nii
      - smwp1*.nii.gz
    - id: smoothed_modulated_wm
      label: Smoothed modulated white matter
      group: VBM
      patterns:
      - smwp2*.nii
      - smwp2*.nii.gz
    - id: modulated_gm
      label: Modulated gray matter
      group: VBM
      patterns:
      - mwp1*.nii
      - mwp1*.nii.gz
    - id: modulated_wm
      label: Modulated white matter
      group: VBM
      patterns:
      - mwp2*.nii
      - mwp2*.nii.gz
    - id: normalized_tissue
      label: Normalized tissue map
      group: Segmentation
      patterns:
      - wp[123]*.nii
      - wp[123]*.nii.gz
    - id: native_tissue
      label: Native tissue segmentation
      group: Segmentation
      patterns:
      - p[123]*.nii
      - p[123]*.nii.gz
    - id: deformation
      label: Deformation field
      group: Deformation
      patterns:
      - y_*.nii
      - y_*.nii.gz
      - iy_*.nii
      - iy_*.nii.gz
      - wj_*.nii
      - wj_*.nii.gz
    - id: nifti
      label: CAT12 NIfTI derivative
      group: Other images
      patterns:
      - '*.nii'
      - '*.nii.gz'
    - id: qc_report
      label: CAT12 quality report
      group: Reports
      patterns:
      - cat_*.xml
      - '*report*.xml'
      role: report
      qc: cat12_iqr
    - id: html_report
      label: CAT12 HTML report
      group: Reports
      patterns:
      - '*.html'
      - '*.htm'
      role: report
    - id: table
      label: CAT12 table
      group: Tables
      patterns:
      - '*.csv'
      - '*.tsv'
    exclude:
    - .nipa_complete/**
    - '**/.nipa_complete/**'
ui:
  modalities:
  - anat
```

### Package file 2

**run.sh**

```bash
#!/usr/bin/env bash

set -euo pipefail

# NIPA calls this scheduler-agnostic entrypoint with subject and session arguments.
SUBJECT="${1:-}"
SESSION="${2:-}"

if [[ ! "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]]; then
    echo "ERROR: Invalid or missing subject: $SUBJECT" >&2
    exit 2
fi
if [[ ! "$SESSION" =~ ^ses-[A-Za-z0-9]+$ ]]; then
    echo "ERROR: Invalid or missing session: $SESSION" >&2
    exit 2
fi

: "${PROJECT_ROOT:?PROJECT_ROOT is not set}"
: "${BIDS_ROOT:?BIDS_ROOT was not provided by NIPA ProjectContext}"
: "${CAT12_OUT_ROOT:?CAT12_OUT_ROOT was not provided by NIPA PluginRegistry}"
: "${CAT12_SIF:?CAT12_SIF was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
NIPA_SKIP_EXISTING="${NIPA_SKIP_EXISTING:-1}"

T1_GZ="$BIDS_ROOT/$SUBJECT/$SESSION/anat/${SUBJECT}_${SESSION}_T1w.nii.gz"
T1_NII="$BIDS_ROOT/$SUBJECT/$SESSION/anat/${SUBJECT}_${SESSION}_T1w.nii"
if [[ -f "$T1_GZ" ]]; then
    T1="$T1_GZ"
elif [[ -f "$T1_NII" ]]; then
    T1="$T1_NII"
else
    echo "ERROR: T1w image not found:" >&2
    echo "  $T1_GZ" >&2
    echo "  $T1_NII" >&2
    exit 1
fi

if [[ ! -f "$CAT12_SIF" ]]; then
    echo "ERROR: CAT12 container not found: $CAT12_SIF" >&2
    exit 1
fi

OUT="$CAT12_OUT_ROOT/derivatives/$SUBJECT"
SESSION_OUT="$OUT/$SESSION"
CONTAINER_T1="/data/$SUBJECT/$SESSION/anat/$(basename "$T1")"
CONTAINER_OUT="/out/derivatives/$SUBJECT"
TMP_ROOT="${NIPA_EXECUTION_WORK_DIR:?NIPA_EXECUTION_WORK_DIR was not provided by the Executor}/cat12"
SUCCESS_FILE="$SESSION_OUT/.cat12_complete"
LOG_FILE="$SESSION_OUT/brainprep_cat12.log"

mkdir -p "$CAT12_OUT_ROOT/logs" "$SESSION_OUT" "$TMP_ROOT"

if [[ "$NIPA_SKIP_EXISTING" == "1" && -f "$SUCCESS_FILE" ]]; then
    echo "Already completed: $SUBJECT $SESSION"
    exit 0
fi

mkdir -p "$TMP_ROOT/mcr_cache" "$TMP_ROOT/tmp" "$TMP_ROOT/matlab_pref"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

echo "============================================"
echo "NIPA CAT12 VBM job"
echo "Executor job: ${NIPA_EXECUTOR_JOB_ID:-local}"
echo "Host:      $(hostname)"
echo "Date:      $(date)"
echo "Subject:   $SUBJECT"
echo "Session:   $SESSION"
echo "Input T1:  $T1"
echo "Output:    $OUT"
echo "SIF:       $CAT12_SIF"
echo "============================================"

env -u DISPLAY \
"$NIPA_CONTAINER_RUNTIME" exec \
    --cleanenv \
    --bind "$BIDS_ROOT:/data:ro" \
    --bind "$CAT12_OUT_ROOT:/out" \
    --bind "$TMP_ROOT:/nipa-work" \
    --env MCR_CACHE_ROOT=/nipa-work/mcr_cache \
    --env TMPDIR=/nipa-work/tmp \
    --env MATLAB_PREFDIR=/nipa-work/matlab_pref \
    --env LIBGL_ALWAYS_SOFTWARE=1 \
    --env MESA_LOADER_DRIVER_OVERRIDE=swrast \
    "$CAT12_SIF" \
    brainprep cat12vbm \
    --anatomical "$CONTAINER_T1" \
    --outdir "$CONTAINER_OUT" \
    --session "$SESSION" \
    --verbose 2 \
    2>&1 | tee "$LOG_FILE"

MWP1="$SESSION_OUT/mri/mwp1u${SUBJECT}_${SESSION}_T1w.nii"
if [[ ! -f "$MWP1" ]]; then
    echo "ERROR: Expected MWP1 not found: $MWP1" >&2
    find "$SESSION_OUT" -type f -name 'mwp1*.nii' -print
    exit 1
fi

touch "$SUCCESS_FILE"
echo "CAT12 completed successfully: $MWP1"
echo "Finished: $(date)"
```

### Package file 3

**run_cat12_one.sh**

*Empty file.*
