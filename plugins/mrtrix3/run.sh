#!/usr/bin/env bash
set -euo pipefail

dwi="${NIPA_INPUT_DWI_PATH:?Select a diffusion NIfTI Artifact in NIPA}"
runtime="${NIPA_CONTAINER_RUNTIME:-}"
image="${MRTRIX3_SIF:?Register the MRtrix3 3.0.8 container in NIPA}"
output="${NIPA_OUTPUT_DIR:?NIPA output directory is missing}"
work="${NIPA_EXECUTION_WORK_DIR:?NIPA execution work directory is missing}"
threads="${NIPA_CPUS:-4}"

if [[ -z "$runtime" ]]; then
  if command -v apptainer >/dev/null 2>&1; then
    runtime=apptainer
  elif command -v singularity >/dev/null 2>&1; then
    runtime=singularity
  fi
fi
if [[ -z "$runtime" ]] || ! command -v "$runtime" >/dev/null 2>&1; then
  echo "Container runtime '${runtime:-Apptainer or Singularity}' is unavailable in this job. Load the site runtime module in the Slurm job environment." >&2
  exit 2
fi
if [[ ! -f "$image" || ! -r "$image" ]]; then
  echo "MRtrix3 SIF is not readable from this job: $image. Register a path shared with the compute nodes." >&2
  exit 2
fi

case "$dwi" in
  *.nii.gz) stem="${dwi%.nii.gz}"; input_name=dwi.nii.gz ;;
  *.nii) stem="${dwi%.nii}"; input_name=dwi.nii ;;
  *) echo "Expected a .nii or .nii.gz diffusion image." >&2; exit 2 ;;
esac
for file in "$dwi" "$stem.bvec" "$stem.bval"; do
  if [[ ! -f "$file" || ! -s "$file" ]]; then
    echo "Missing or empty diffusion input: $file" >&2
    exit 2
  fi
done
name="${stem##*/}"
if [[ ! "$name" =~ ^[[:alnum:]_-]+$ ]]; then
  echo "Use a diffusion filename with letters, numbers, underscores, or dashes." >&2
  exit 2
fi

mkdir -p "$work" "$output"
container=("$runtime" exec --cleanenv --bind "$work:/nipa-work")
options=$(python3 -c 'import json, os; p=json.loads(os.environ.get("NIPA_PARAMETERS_JSON", "{}")); print(int(p.get("tractography") is True or p.get("connectome") is True), int(p.get("connectome") is True))')
read -r tracking connectome <<< "$options"
inputs=(--bind "$dwi:/nipa-input/$input_name:ro"
  --bind "$stem.bvec:/nipa-input/dwi.bvec:ro"
  --bind "$stem.bval:/nipa-input/dwi.bval:ro")
dwi_path="/nipa-input/$input_name"
grad=(-fslgrad /nipa-input/dwi.bvec /nipa-input/dwi.bval)
if [[ "$connectome" == 1 ]]; then
  atlas="${NIPA_INPUT_PARCELLATION_PATH:?Connectome requires an aligned parcellation Artifact}"
  case "$atlas" in
    *.nii.gz) atlas_path=/nipa-input/atlas.nii.gz ;;
    *.nii) atlas_path=/nipa-input/atlas.nii ;;
    *) echo "Connectome requires a NIfTI parcellation." >&2; exit 2 ;;
  esac
  inputs+=(--bind "$atlas:$atlas_path:ro")
fi
mr() { "${container[@]}" "${inputs[@]}" "$image" "$@"; }
if [[ "$connectome" == 1 ]]; then
  dwi_grid=$(mr mrinfo -size -spacing -transform "$dwi_path" | awk 'NR<=2 {print $1,$2,$3; next} {print}')
  atlas_grid=$(mr mrinfo -size -spacing -transform "$atlas_path")
  datatype=$(mr mrinfo -datatype "$atlas_path")
  if [[ "$dwi_grid" != "$atlas_grid" || ! "$datatype" =~ ^U?Int ]]; then
    echo "Connectome requires a 3D integer label image matching the DWI grid and orientation." >&2
    exit 2
  fi
  read -r minimum maximum < <(mr mrstats "$atlas_path" -output min -output max)
  awk -v lo="$minimum" -v hi="$maximum" 'BEGIN {exit !(lo >= 0 && hi > 0)}' || {
    echo "Parcellation must contain positive region labels and no negative labels." >&2
    exit 2
  }
fi
if [[ "$tracking" == 1 ]]; then
  read -r -a shells <<< "$(mr mrinfo -shell_bvalues "${grad[@]}" "$dwi_path")"
  if [[ "${#shells[@]}" != 2 || "${shells[0]}" != 0 ]]; then
    echo "This tractography workflow requires b=0 and one nonzero diffusion shell." >&2
    exit 2
  fi
fi
mr dwi2tensor "$dwi_path" /nipa-work/tensor.mif "${grad[@]}" -nthreads "$threads"
"${container[@]}" "$image" tensor2metric /nipa-work/tensor.mif \
  -fa /nipa-work/FA.nii.gz -adc /nipa-work/MD.nii.gz \
  -ad /nipa-work/AD.nii.gz -rd /nipa-work/RD.nii.gz -nthreads "$threads"

files=(FA.nii.gz MD.nii.gz AD.nii.gz RD.nii.gz)
if [[ "$tracking" == 1 ]]; then
  mr dwi2mask "$dwi_path" /nipa-work/mask.mif "${grad[@]}" -nthreads "$threads"
  mr dwi2response tournier "$dwi_path" /nipa-work/response.txt "${grad[@]}" -mask /nipa-work/mask.mif -nthreads "$threads"
  mr dwi2fod csd "$dwi_path" /nipa-work/response.txt /nipa-work/wmfod.mif "${grad[@]}" -mask /nipa-work/mask.mif -nthreads "$threads"
  mr tckgen /nipa-work/wmfod.mif /nipa-work/tracks.tck -algorithm iFOD2 \
    -seed_image /nipa-work/mask.mif -mask /nipa-work/mask.mif -select 100000 -nthreads "$threads"
  files+=(wmfod.mif tracks.tck)
fi
if [[ "$connectome" == 1 ]]; then
  mr tck2connectome /nipa-work/tracks.tck "$atlas_path" /nipa-work/connectome.csv \
    -symmetric -out_assignments /nipa-work/assignments.txt -nthreads "$threads"
  files+=(connectome.csv assignments.txt)
fi
for file in "${files[@]}"; do
  test -s "$work/$file"
done
for file in "${files[@]}"; do
  cp -- "$work/$file" "$output/${name}_$file"
done
