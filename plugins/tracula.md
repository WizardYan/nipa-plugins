# TRACULA

**TRACULA** · Plugin version 1.1.1 · Runtime 7.3.2

Diffusion MRI tractography using producer-neutral artifact contracts and a native TRACULA execution adapter.

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/tracula-1.1.1.nipa-plugin.tar.gz)

SHA-256: `52a19d312ae37690f1bd8b3b5dcde314a8689bf662f26ab4aa2c0af70ab22fd1`

[Upstream project](https://surfer.nmr.mgh.harvard.edu/fswiki/Tracula)

[All official plugins](../official-plugins.md)

## Package files

- [plugin.yaml](#package-file-1)
- [__init__.py](#package-file-2)
- [adapter.py](#package-file-3)
- [run.sh](#package-file-4)
- [tracula_auto_configuration.sh](#package-file-5)
- [tracula_check_freesurfer_outputs.sh](#package-file-6)
- [tracula_exec.sh](#package-file-7)
- [tracula_validate_configuration.sh](#package-file-8)

### Package file 1

**plugin.yaml**

```yaml
schema: nipa.plugin/v3
plugin:
  id: tracula
  name: TRACULA
  version: 1.1.1
  category: diffusion
  description: Diffusion MRI tractography using producer-neutral artifact contracts and a native TRACULA execution adapter.
transformation:
  inputs:
    dwi:
      type: imaging.mri.diffusion.dwi
      source: dataset
      cardinality: one
      label: Raw diffusion MRI with bval/bvec companions
    reconstruction:
      type: imaging.mri.anatomical.reconstruction
      source: artifact
      cardinality: one
      label: FreeSurfer anatomical reconstruction
      attributes:
        representation: anatomical_reconstruction
        method: freesurfer
    thalamic_nuclei:
      type: imaging.mri.anatomical.segmentation
      source: artifact
      cardinality: one
      required: false
      label: Thalamic nuclei segmentation
      attributes:
        segmentation_type: structure
        structure: thalamic_nuclei
        method: freesurfer
  outputs:
    preprocessed_dwi:
      type: imaging.mri.diffusion.dwi
      attributes:
        processing_state: preprocessed
        stage: prep
    tensor_maps:
      type: imaging.mri.diffusion.scalar_map
      attributes:
        model: tensor
        stage: prep
    diffusion_posterior:
      type: imaging.mri.diffusion.model
      attributes:
        representation: posterior
        method: bedpostx
        stage: bedp
    tract_map:
      type: imaging.mri.diffusion.tractography
      attributes:
        representation: pathway_map
        method: tracula
        stage: path
    table:
      type: table.statistics
      attributes:
        domain: diffusion_tractography
        representation: pathway
        stage: path
    config:
      type: text
      attributes:
        format: native_configuration
  parameters:
    susceptibility_correction:
      type: enum
      default: none
      description: B0 susceptibility-distortion correction strategy.
      values:
        none: 0
        fieldmap: 1
        reverse_polarity: 2
      native_key: dob0
    eddy_correction:
      type: enum
      default: none
      description: Eddy-current correction strategy.
      values:
        none: 0
        eddy_correct: 1
        eddy: 2
      native_key: doeddy
    rotate_bvecs:
      type: boolean
      default: true
      native_key: dorotbvecs
    intra_registration:
      type: enum
      default: boundary_based
      values:
        correlation_ratio: 1
        mutual_information: 2
        boundary_based: 3
      native_key: intrareg
    intra_dof:
      type: integer
      default: 6
      minimum: 6
      maximum: 12
      native_key: intradof
    intra_max_rotation_deg:
      type: integer
      default: 90
      minimum: 0
      maximum: 180
      native_key: intrarot
    inter_registration:
      type: enum
      default: syn_fa
      values:
        affine_t1_correlation_ratio: 1
        affine_t1_mutual_information: 2
        robust_t1: 3
        cvs_t1: 4
        syn_fa: 5
      native_key: interreg
    segmentation:
      type: string
      default: aparc+aseg
      native_key: segname
    use_thalamic_nuclei:
      type: boolean
      default: true
      native_key: usethalnuc
    use_anatomical_mask:
      type: boolean
      default: true
      native_key: usemaskanat
    n_sticks:
      type: integer
      default: 2
      minimum: 1
      maximum: 3
      native_key: nstick
    burn_in_iterations:
      type: integer
      default: 200
      minimum: 0
      native_key: nburnin
    sample_iterations:
      type: integer
      default: 7500
      minimum: 1
      native_key: nsample
    keep_every:
      type: integer
      default: 5
      minimum: 1
      native_key: nkeep
    reinitialize_paths:
      type: boolean
      default: false
      native_key: reinit
  capability:
    title: White-matter tractography
    goal: Reconstruct major white-matter pathways from diffusion MRI
    abstraction: artifact-to-native-adapter
    native_engine: trac-all
implementation:
  entrypoint: run.sh
  enabled: true
  resources:
    cpus: 8
    memory_gb: 40
    time: 7-00:00:00
    gpu_count: 0
    scratch_gb: 40
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
    - id: fsl
      kind: software
      acquisition: site_provided
      binding_env: FSLDIR
      capabilities:
      - fsl.core
      - fsl.bedpostx
      - fsl.probtrackx
      commands:
      - fslmaths
      - bedpostx
      - probtrackx2
      environment:
        FSLDIR: '{root}'
        FSLOUTPUTTYPE: NIFTI_GZ
    - id: ants
      kind: conda
      acquisition: site_provided
      binding_env: ANTS_ENV
      capabilities:
      - ants.registration
      commands:
      - antsRegistration
      - antsApplyTransforms
      environment:
        ANTSPATH: '{prefix}/bin/'
    licenses:
    - id: freesurfer
      required: true
      env: FS_LICENSE
      target: /opt/freesurfer/license.txt
  outputs:
    root: derivatives/tracula
    environment: TRACULA_OUT_ROOT
    formats:
    - id: tensor_maps
      label: Diffusion tensor map
      group: Tensor maps
      patterns:
      - '*dtifit_*.nii'
      - '*dtifit_*.nii.gz'
    - id: tract_map
      label: Tract probability / pathway map
      group: Tractography
      patterns:
      - '*path*.nii'
      - '*path*.nii.gz'
      - '*tract*.nii'
      - '*tract*.nii.gz'
      - '*posterior*.nii'
      - '*posterior*.nii.gz'
    - id: nifti
      label: TRACULA NIfTI derivative
      group: Images
      patterns:
      - '*.nii'
      - '*.nii.gz'
    - id: freesurfer_volume
      label: FreeSurfer volume
      group: FreeSurfer
      patterns:
      - '*.mgz'
      - '*.mgh'
    - id: table
      label: Statistics / table
      group: Tables
      patterns:
      - '*.csv'
      - '*.tsv'
      - '*.stats'
    - id: config
      label: Configuration / text
      group: Configuration
      patterns:
      - '*.txt'
      - '*.log'
      - '*.out'
      - '*.err'
      - '*.conf'
      - '*.cfg'
    exclude:
    - logs/**
    - '**/logs/**'
    - .nipa_complete/**
    - '**/.nipa_complete/**'
  assets:
    TRACULA_EXEC:
      path: tracula_exec.sh
      executable: true
    TRACULA_CHECK_FS:
      path: tracula_check_freesurfer_outputs.sh
      executable: true
    TRACULA_AUTO_CONFIG:
      path: tracula_auto_configuration.sh
      executable: true
    TRACULA_VALIDATE_CONFIG:
      path: tracula_validate_configuration.sh
      executable: true
  stages:
  - id: prep
    label: Diffusion preprocessing and registration
    native_command: trac-all -prep
    requires:
    - imaging.mri.diffusion.dwi
    - imaging.mri.anatomical.reconstruction
    produces:
    - imaging.mri.diffusion.dwi
    - imaging.mri.diffusion.scalar_map
  - id: bedp
    label: BedpostX diffusion-model estimation
    native_command: trac-all -bedp
    depends_on:
    - prep
    requires:
    - imaging.mri.diffusion.dwi
    produces:
    - imaging.mri.diffusion.model
  - id: path
    label: Probabilistic pathway reconstruction
    native_command: trac-all -path
    depends_on:
    - bedp
    requires:
    - imaging.mri.diffusion.model
    produces:
    - imaging.mri.diffusion.tractography
    - table.statistics
  provenance:
    native_engine: trac-all
    capture:
    - resolved_inputs
    - parameters
    - runtime_requirements
    - resource_request
    - execution_identity
    - stage_sequence
    portable_spec: true
  script_env: TRACULA_SBATCH_SCRIPT
ui:
  modalities:
  - dwi
```

### Package file 2

**__init__.py**

*Empty file.*

### Package file 3

**adapter.py**

```python
"""NIPA TRACULA plugin adapter.

NIPA owns artifact/runtime resolution.  The TRACULA plugin owns its validated
native workflow: wrapper preflight -> FreeSurfer validation -> direct artifact-based
configuration -> config validation -> prep/bedp/path.
"""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class TraculaRuntime:
    freesurfer_sif: Path
    fs_license: Path
    fsl_dir: Path
    ants_env: Path


NATIVE_WORKFLOW = (
    "recon-all-version",
    "trac-all-version",
    "check-freesurfer-outputs",
    "auto-configuration",
    "validate-configuration",
    "prep",
    "bedp",
    "path",
)


def validate_runtime(runtime: TraculaRuntime) -> bool:
    checks = {
        "FreeSurfer container": runtime.freesurfer_sif,
        "FreeSurfer license": runtime.fs_license,
        "FSL": runtime.fsl_dir,
        "ANTs": runtime.ants_env,
    }
    missing = [name for name, path in checks.items() if not path.exists()]
    if missing:
        raise RuntimeError("Missing TRACULA runtime: " + ", ".join(missing))
    return True
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
: "${BIDS_ROOT:?BIDS_ROOT was not provided by NIPA ProjectContext}"
TRACULA_OUT_ROOT="${TRACULA_OUT_ROOT:-$PROJECT_ROOT/derivatives/tracula}"
: "${NIPA_INPUT_RECONSTRUCTION_PATH:?NIPA did not resolve the reconstruction Artifact resource}"
: "${FREESURFER_SIF:?FREESURFER_SIF was not resolved by NIPA Runtime Manager}"
: "${FS_LICENSE:?FS_LICENSE was not resolved by NIPA Runtime Manager}"
: "${NIPA_CONTAINER_RUNTIME:?NIPA_CONTAINER_RUNTIME was not resolved by NIPA Runtime Manager}"
: "${FSLDIR:?FSLDIR was not resolved by NIPA Runtime Manager}"
: "${ANTS_ENV:?ANTS_ENV was not resolved by NIPA Runtime Manager}"
ANTSPATH="${ANTSPATH:-${ANTS_ENV%/}/bin/}"
# TRACULA_EXEC is a plugin-private execution asset. NIPA resolves its absolute
# path before executor submission so scheduler staging cannot change its meaning.
TRACULA_EXEC="${TRACULA_EXEC:-}"
TRACULA_CHECK_FS="${TRACULA_CHECK_FS:-}"
TRACULA_AUTO_CONFIG="${TRACULA_AUTO_CONFIG:-}"
TRACULA_VALIDATE_CONFIG="${TRACULA_VALIDATE_CONFIG:-}"
NIPA_SKIP_EXISTING="${NIPA_SKIP_EXISTING:-1}"

if [[ "$SESSION" == "no-session" ]]; then
    ID="$SUBJECT"
    DWI_DIR="$BIDS_ROOT/$SUBJECT/dwi"
else
    ID="${SUBJECT}_${SESSION}"
    DWI_DIR="$BIDS_ROOT/$SUBJECT/$SESSION/dwi"
fi
DWI="$DWI_DIR/${ID}_dwi.nii.gz"
[[ -f "$DWI" ]] || DWI="$DWI_DIR/${ID}_dwi.nii"
BVEC="$DWI_DIR/${ID}_dwi.bvec"
BVAL="$DWI_DIR/${ID}_dwi.bval"
FS_SUBJECT="${NIPA_INPUT_RECONSTRUCTION_PATH%/}"
FREESURFER_SUBJECTS_DIR="$(dirname "$FS_SUBJECT")"
FS_ID="$(basename "$FS_SUBJECT")"
THALAMIC_NUCLEI="${NIPA_INPUT_THALAMIC_NUCLEI_PATH:-}"
CONFIG_DIR="$TRACULA_OUT_ROOT/config"
CONFIG="$CONFIG_DIR/$ID.dmrirc"
SUCCESS_DIR="$TRACULA_OUT_ROOT/.nipa_complete"
SUCCESS="$SUCCESS_DIR/$ID.complete"

[[ -f "$DWI" ]] || { echo "ERROR: DWI not found for $ID under $DWI_DIR" >&2; exit 1; }
[[ -f "$BVEC" ]] || { echo "ERROR: bvec not found: $BVEC" >&2; exit 1; }
[[ -f "$BVAL" ]] || { echo "ERROR: bval not found: $BVAL" >&2; exit 1; }
[[ -d "$FS_SUBJECT" ]] || { echo "ERROR: resolved FreeSurfer reconstruction directory not found: $FS_SUBJECT" >&2; exit 1; }
[[ "$FS_ID" == "$ID" ]] || { echo "ERROR: resolved reconstruction target mismatch: expected $ID but Artifact locator points to $FS_ID ($FS_SUBJECT)" >&2; exit 1; }
[[ -f "$FS_SUBJECT/mri/aparc+aseg.mgz" ]] || { echo "ERROR: missing FreeSurfer aparc+aseg.mgz for $ID" >&2; exit 1; }
if [[ -n "$THALAMIC_NUCLEI" ]]; then
    [[ -f "$THALAMIC_NUCLEI" ]] || { echo "ERROR: resolved thalamic-nuclei Artifact resource not found: $THALAMIC_NUCLEI" >&2; exit 1; }
    THALAMIC_PARENT="$(dirname "$THALAMIC_NUCLEI")"
    [[ "$THALAMIC_PARENT" == "$FS_SUBJECT/mri" ]] || {
        echo "ERROR: resolved thalamic-nuclei Artifact does not belong to the resolved FreeSurfer reconstruction" >&2
        echo "  reconstruction: $FS_SUBJECT" >&2
        echo "  segmentation:   $THALAMIC_NUCLEI" >&2
        exit 1
    }
    case "$(basename "$THALAMIC_NUCLEI")" in
        ThalamicNuclei*.mgz) ;;
        *) echo "ERROR: resolved thalamic-nuclei Artifact is not a ThalamicNuclei*.mgz resource: $THALAMIC_NUCLEI" >&2; exit 1 ;;
    esac
fi
[[ -f "$FREESURFER_SIF" ]] || { echo "ERROR: FreeSurfer container not found: $FREESURFER_SIF" >&2; exit 1; }
[[ -f "$FS_LICENSE" ]] || { echo "ERROR: FreeSurfer license not found: $FS_LICENSE" >&2; exit 1; }
command -v "$NIPA_CONTAINER_RUNTIME" >/dev/null || { echo "ERROR: container runtime is unavailable: $NIPA_CONTAINER_RUNTIME" >&2; exit 1; }

mkdir -p "$CONFIG_DIR" "$TRACULA_OUT_ROOT/logs" "$SUCCESS_DIR"
if [[ "$NIPA_SKIP_EXISTING" == "1" && -f "$SUCCESS" ]]; then
    echo "Already completed: $ID"
    exit 0
fi

# v0.40 preserves the native wrapper sequence while restoring the previously
# working direct dmrirc generation logic inside the TRACULA plugin adapter.
# NIPA passes resolved artifacts explicitly; no temporary BIDS view is created.

validate_asset() {
    local name="$1" path="$2"
    [[ -n "$path" ]] || { echo "ERROR: $name was not supplied by NIPA plugin runtime" >&2; exit 1; }
    [[ "$path" = /* ]] || { echo "ERROR: $name must be an absolute path: $path" >&2; [[ "$name" != "TRACULA_EXEC" ]] || echo "ERROR: TRACULA_EXEC must be an absolute path" >&2; exit 1; }
    [[ -x "$path" ]] || { echo "ERROR: $name is missing or not executable: $path" >&2; exit 1; }
}

validate_asset TRACULA_EXEC "$TRACULA_EXEC"
validate_asset TRACULA_CHECK_FS "$TRACULA_CHECK_FS"
validate_asset TRACULA_AUTO_CONFIG "$TRACULA_AUTO_CONFIG"
validate_asset TRACULA_VALIDATE_CONFIG "$TRACULA_VALIDATE_CONFIG"

# v0.38: establish one exported plugin execution context before invoking any
# TRACULA helper subprocess.  Values resolved by NIPA must cross the process
# boundary; otherwise helper scripts see unset variables even though the
# parent Slurm shell can use them.
export PROJECT_ROOT
export BIDS_ROOT
export TRACULA_OUT_ROOT
export FREESURFER_SUBJECTS_DIR
export FREESURFER_SIF
export FS_LICENSE
export NIPA_CONTAINER_RUNTIME
export FSLDIR
export ANTS_ENV
export ANTSPATH
export TRACULA_EXEC
export TRACULA_CHECK_FS
export TRACULA_AUTO_CONFIG
export TRACULA_VALIDATE_CONFIG
export NIPA_SKIP_EXISTING
export NIPA_INPUT_RECONSTRUCTION_ARTIFACT_ID
export NIPA_INPUT_RECONSTRUCTION_PATH
export NIPA_INPUT_THALAMIC_NUCLEI_ARTIFACT_ID="${NIPA_INPUT_THALAMIC_NUCLEI_ARTIFACT_ID:-}"
export NIPA_INPUT_THALAMIC_NUCLEI_PATH="$THALAMIC_NUCLEI"

run_tracula() {
    "$TRACULA_EXEC" "$@"
}

run_stage() {
    local stage="$1"
    local stage_log="$TRACULA_OUT_ROOT/logs/${ID}_${stage}.log"
    echo "--------------------------------------------------"
    echo "TRACULA stage: $stage"
    echo "Subject-session: $ID"
    echo "Started: $(date --iso-8601=seconds)"
    echo "Stage log: $stage_log"
    echo "--------------------------------------------------"
    run_tracula trac-all "-$stage" -c "/tracula/config/$ID.dmrirc" 2>&1 | tee "$stage_log"
}

echo "=================================================="
echo "NIPA TRACULA job"
echo "Executor job: ${NIPA_EXECUTOR_JOB_ID:-local}"
echo "Host: $(hostname)"
echo "Subject-session: $ID"
echo "DWI: $DWI"
echo "FreeSurfer reconstruction Artifact: ${NIPA_INPUT_RECONSTRUCTION_ARTIFACT_ID:-unknown}"
echo "FreeSurfer: $FS_SUBJECT"
echo "Thalamic nuclei Artifact: ${NIPA_INPUT_THALAMIC_NUCLEI_ARTIFACT_ID:-not resolved (optional)}"
echo "Thalamic nuclei: ${THALAMIC_NUCLEI:-not resolved (TRACULA will use usethalnuc=0)}"
echo "Output: $TRACULA_OUT_ROOT"
echo "Config: $CONFIG"
echo "Container: $FREESURFER_SIF"
echo "FSL: $FSLDIR"
echo "ANTs: $ANTS_ENV"
echo "ANTSPATH: $ANTSPATH"
echo "=================================================="

echo "--------------------------------------------------"
echo "TRACULA native wrapper preflight"
echo "--------------------------------------------------"
run_tracula recon-all -version
run_tracula trac-all -version

echo "--------------------------------------------------"
echo "FreeSurfer prerequisite validation"
echo "--------------------------------------------------"
"$TRACULA_CHECK_FS" "$ID" "$FS_SUBJECT" "$THALAMIC_NUCLEI"

echo "--------------------------------------------------"
echo "TRACULA automatic configuration"
echo "--------------------------------------------------"
"$TRACULA_AUTO_CONFIG" "$SUBJECT" "$SESSION" "$ID" "$DWI" "$BVEC" "$BVAL" "$DWI_DIR/${ID}_dwi.json" "$FS_SUBJECT" "$THALAMIC_NUCLEI"

echo "--------------------------------------------------"
echo "TRACULA configuration validation"
echo "--------------------------------------------------"
"$TRACULA_VALIDATE_CONFIG" "$ID"

run_stage prep
run_stage bedp
run_stage path

touch "$SUCCESS"
echo "TRACULA completed successfully: $ID"
echo "Finished: $(date --iso-8601=seconds)"
```

### Package file 5

**tracula_auto_configuration.sh**

```bash
#!/usr/bin/env bash
# Generate exactly one TRACULA dmrirc from NIPA-resolved artifacts.
#
# This is intentionally derived from the previously working standalone
# tracula_auto_configure.sh workflow. NIPA does not construct a temporary BIDS
# tree and does not call the dataset-scanning BIDS helper. The adapter only
# translates resolved host artifacts into the container-relative paths TRACULA
# expects.
set -euo pipefail

SUBJECT="${1:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json]}"
SESSION="${2:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json]}"
ID="${3:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json]}"
DWI="${4:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json]}"
BVEC="${5:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json]}"
BVAL="${6:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json]}"
JSON="${7:-}"
FS_DIR="${8:?usage: tracula_auto_configuration.sh <subject> <session> <id> <dwi> <bvec> <bval> [json] <resolved-freesurfer-subject-dir> [resolved-thalamic-mgz]}"
THALAMIC_MGZ="${9:-}"

: "${BIDS_ROOT:?BIDS_ROOT is not set}"
: "${TRACULA_OUT_ROOT:?TRACULA_OUT_ROOT is not set}"
[[ "$FS_DIR" = /* ]] || { echo "ERROR: resolved FreeSurfer directory must be absolute: $FS_DIR" >&2; exit 1; }
[[ "$(basename "$FS_DIR")" == "$ID" ]] || { echo "ERROR: resolved FreeSurfer target mismatch: expected $ID, got $(basename "$FS_DIR")" >&2; exit 1; }

CONFIG_DIR="$TRACULA_OUT_ROOT/config"
CONFIG="$CONFIG_DIR/$ID.dmrirc"
mkdir -p "$CONFIG_DIR"

problem=0
for required in "$DWI" "$BVAL" "$BVEC"; do
    if [[ ! -f "$required" ]]; then
        echo "ERROR: missing DWI input: $required" >&2
        problem=1
    fi
done
if [[ -n "$JSON" && ! -f "$JSON" ]]; then
    echo "WARNING: missing JSON sidecar: $JSON" >&2
fi
for required in \
    "$FS_DIR/mri/aparc+aseg.mgz" \
    "$FS_DIR/mri/brain.mgz"
do
    if [[ ! -f "$required" ]]; then
        echo "ERROR: missing FreeSurfer file: $required" >&2
        problem=1
    fi
done
if [[ "$problem" -ne 0 ]]; then
    exit 1
fi

USE_THALAMIC_NUCLEI=0
if [[ -n "$THALAMIC_MGZ" ]]; then
    [[ "$THALAMIC_MGZ" = /* ]] || { echo "ERROR: resolved thalamic segmentation path must be absolute: $THALAMIC_MGZ" >&2; exit 1; }
    [[ -f "$THALAMIC_MGZ" ]] || { echo "ERROR: resolved thalamic-nuclei segmentation missing: $THALAMIC_MGZ" >&2; exit 1; }
    [[ "$(dirname "$THALAMIC_MGZ")" == "$FS_DIR/mri" ]] || {
        echo "ERROR: resolved thalamic segmentation is not part of the resolved reconstruction: $THALAMIC_MGZ" >&2
        exit 1
    }
    case "$(basename "$THALAMIC_MGZ")" in
        ThalamicNuclei*.mgz) USE_THALAMIC_NUCLEI=1 ;;
        *) echo "ERROR: resolved thalamic resource is not a ThalamicNuclei*.mgz file: $THALAMIC_MGZ" >&2; exit 1 ;;
    esac
fi

# Convert NIPA-resolved host paths to paths relative to the selected BIDS root.
# TRACULA combines these with `set dcmroot = /bids` inside the container.
to_bids_relative() {
    local host_path="$1"
    local relative="${host_path#"$BIDS_ROOT"/}"
    if [[ "$relative" == "$host_path" || "$relative" == /* || "$relative" == ../* ]]; then
        echo "ERROR: artifact is not under BIDS_ROOT and cannot be translated to /bids: $host_path" >&2
        return 1
    fi
    printf '%s\n' "$relative"
}

relative_dwi="$(to_bids_relative "$DWI")"
relative_bval="$(to_bids_relative "$BVAL")"
relative_bvec="$(to_bids_relative "$BVEC")"

# Preserve the NIPA target identity exactly. A BIDS session is a distinct
# TRACULA subject because the corresponding FreeSurfer reconstruction is named
# sub-XXX_ses-YY in this workflow.
if [[ "$SESSION" == "no-session" ]]; then
    expected_id="$SUBJECT"
else
    expected_id="${SUBJECT}_${SESSION}"
fi
[[ "$ID" == "$expected_id" ]] || {
    echo "ERROR: TRACULA target identity mismatch: expected $expected_id, got $ID" >&2
    exit 1
}

cat > "$CONFIG" <<EOF_CONFIG
#!/bin/tcsh

# ============================================================
# TRACULA configuration generated by the NIPA TRACULA adapter
#
# BIDS target:
#   ${SUBJECT}/${SESSION}
#
# FreeSurfer anatomy:
#   /subjects/${ID}
#
# TRACULA output:
#   /tracula/${ID}
# ============================================================

# fMRIPrep/FreeSurfer subject directory exposed by NIPA
setenv SUBJECTS_DIR /subjects

# Root directory for TRACULA output
set dtroot = /tracula

# Each NIPA subject-session is treated as one independent TRACULA subject
set subjlist = ( ${ID} )

# ------------------------------------------------------------
# Raw BIDS DWI
# ------------------------------------------------------------
# dcmlist, bveclist, and bvallist are relative to dcmroot.
set dcmroot = /bids

set dcmlist = ( \
    ${relative_dwi} \
)

set bveclist = ( \
    ${relative_bvec} \
)

set bvallist = ( \
    ${relative_bval} \
)

# ------------------------------------------------------------
# Compatibility baseline from the previously working TRACULA workflow.
# These can become explicit plugin parameters in a later version.
# ------------------------------------------------------------
set dob0 = 0
set doeddy = 0
set dorotbvecs = 1
set intrareg = 3
set intradof = 6
set intrarot = 90
set interreg = 5
set segname = aparc+aseg
set usethalnuc = ${USE_THALAMIC_NUCLEI}
set usemaskanat = 1
set nstick = 2
set nburnin = 200
set nsample = 7500
set nkeep = 5
set reinit = 0
EOF_CONFIG

chmod 644 "$CONFIG"

echo "TRACULA configuration generated directly from NIPA-resolved artifacts"
echo "  Subject-session: $ID"
echo "  Config:          $CONFIG"
echo "  DWI:             $relative_dwi"
echo "  BVAL:            $relative_bval"
echo "  BVEC:            $relative_bvec"
echo "  FreeSurfer:      $FS_DIR"
echo "  Thalamic nuclei: ${THALAMIC_MGZ:-not resolved}"
echo "  usethalnuc:      $USE_THALAMIC_NUCLEI"
```

### Package file 6

**tracula_check_freesurfer_outputs.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

ID="${1:?usage: tracula_check_freesurfer_outputs.sh <subject-session> <resolved-subject-dir> [resolved-thalamic-mgz]}"
SUBJECT_DIR="${2:?usage: tracula_check_freesurfer_outputs.sh <subject-session> <resolved-subject-dir> [resolved-thalamic-mgz]}"
THALAMIC_MGZ="${3:-}"

[[ "$SUBJECT_DIR" = /* ]] || { echo "ERROR: resolved FreeSurfer subject directory must be absolute: $SUBJECT_DIR" >&2; exit 1; }
[[ -d "$SUBJECT_DIR" ]] || { echo "ERROR: resolved FreeSurfer subject directory not found: $SUBJECT_DIR" >&2; exit 1; }
[[ "$(basename "$SUBJECT_DIR")" == "$ID" ]] || { echo "ERROR: resolved FreeSurfer subject target mismatch: expected $ID, got $(basename "$SUBJECT_DIR")" >&2; exit 1; }

required=(
    "$SUBJECT_DIR/mri/aparc+aseg.mgz"
    "$SUBJECT_DIR/mri/brain.mgz"
)
for path in "${required[@]}"; do
    [[ -f "$path" ]] || { echo "ERROR: required FreeSurfer output missing: $path" >&2; exit 1; }
done

if [[ -n "$THALAMIC_MGZ" ]]; then
    [[ "$THALAMIC_MGZ" = /* ]] || { echo "ERROR: resolved thalamic segmentation path must be absolute: $THALAMIC_MGZ" >&2; exit 1; }
    [[ -f "$THALAMIC_MGZ" ]] || { echo "ERROR: resolved thalamic-nuclei segmentation missing: $THALAMIC_MGZ" >&2; exit 1; }
    [[ "$(dirname "$THALAMIC_MGZ")" == "$SUBJECT_DIR/mri" ]] || {
        echo "ERROR: resolved thalamic segmentation is not part of the resolved reconstruction: $THALAMIC_MGZ" >&2
        exit 1
    }
    case "$(basename "$THALAMIC_MGZ")" in
        ThalamicNuclei*.mgz) ;;
        *) echo "ERROR: resolved thalamic resource is not a ThalamicNuclei*.mgz file: $THALAMIC_MGZ" >&2; exit 1 ;;
    esac
fi

echo "FreeSurfer prerequisite check: OK"
echo "  Subject: $ID"
echo "  Directory: $SUBJECT_DIR"
if [[ -n "$THALAMIC_MGZ" ]]; then
    echo "  Thalamic nuclei: $THALAMIC_MGZ"
else
    echo "  Thalamic nuclei: not resolved (optional; TRACULA will use usethalnuc=0)"
fi
```

### Package file 7

**tracula_exec.sh**

```bash
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
```

### Package file 8

**tracula_validate_configuration.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

ID="${1:?usage: tracula_validate_configuration.sh <subject-session>}"
: "${TRACULA_OUT_ROOT:?TRACULA_OUT_ROOT is not set}"
CONFIG="$TRACULA_OUT_ROOT/config/$ID.dmrirc"

[[ -s "$CONFIG" ]] || { echo "ERROR: TRACULA config missing or empty: $CONFIG" >&2; exit 1; }

grep -Eq "^[[:space:]]*setenv[[:space:]]+SUBJECTS_DIR[[:space:]]+/subjects([[:space:]]|$)" "$CONFIG" || {
    echo "ERROR: config does not use container SUBJECTS_DIR=/subjects" >&2; exit 1;
}
grep -Eq "^[[:space:]]*set[[:space:]]+dtroot[[:space:]]*=[[:space:]]*\(?/tracula\)?" "$CONFIG" || {
    echo "ERROR: config does not use container TRACULA root /tracula" >&2; exit 1;
}
grep -Eq "^[[:space:]]*set[[:space:]]+subjlist[[:space:]]*=[[:space:]]*\([[:space:]]*$ID[[:space:]]*\)" "$CONFIG" || {
    echo "ERROR: config subject list does not match $ID" >&2
    grep -E '^[[:space:]]*set[[:space:]]+subjlist' "$CONFIG" >&2 || true
    exit 1
}
grep -Eq "^[[:space:]]*set[[:space:]]+dcmroot[[:space:]]*=[[:space:]]*\(?/bids\)?" "$CONFIG" || {
    echo "ERROR: config does not use container BIDS root /bids" >&2; exit 1;
}
grep -Eq '^[[:space:]]*set[[:space:]]+dcmlist[[:space:]]*=' "$CONFIG" || { echo "ERROR: dcmlist missing from config" >&2; exit 1; }
grep -Eq '^[[:space:]]*set[[:space:]]+bveclist[[:space:]]*=' "$CONFIG" || { echo "ERROR: bveclist missing from config" >&2; exit 1; }
grep -Eq '^[[:space:]]*set[[:space:]]+bvallist[[:space:]]*=' "$CONFIG" || { echo "ERROR: bvallist missing from config" >&2; exit 1; }

echo "TRACULA configuration validation: OK"
echo "  Config: $CONFIG"
echo "  Subject-session: $ID"
```
