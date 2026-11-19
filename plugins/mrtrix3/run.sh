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
options=$(python3 -c 'import json, os; p=json.loads(os.environ.get("NIPA_PARAMETERS_JSON", "{}")); print(int(p.get("tractography") is True or p.get("connectome") is True), int(p.get("connectome") is True), p.get("parcellation_source", "aligned"))')
read -r tracking connectome parcellation_source <<< "$options"
inputs=(--bind "$dwi:/nipa-input/$input_name:ro"
  --bind "$stem.bvec:/nipa-input/dwi.bvec:ro"
  --bind "$stem.bval:/nipa-input/dwi.bval:ro")
dwi_path="/nipa-input/$input_name"
grad=(-fslgrad /nipa-input/dwi.bvec /nipa-input/dwi.bval)
if [[ "$connectome" == 1 && "$parcellation_source" == freesurfer ]]; then
  reconstruction="${NIPA_INPUT_RECONSTRUCTION_PATH:?Select a FreeSurfer reconstruction Artifact}"
  for file in norm.mgz aparc+aseg.mgz; do
    if [[ ! -s "$reconstruction/mri/$file" ]]; then
      echo "FreeSurfer reconstruction is missing mri/$file: $reconstruction" >&2
      exit 2
    fi
  done
  inputs+=(--bind "$reconstruction/mri/norm.mgz:/nipa-input/norm.mgz:ro"
           --bind "$reconstruction/mri/aparc+aseg.mgz:/nipa-input/aparc+aseg.mgz:ro")
  atlas_path=/nipa-work/nodes_dwi.nii.gz
elif [[ "$connectome" == 1 ]]; then
  atlas="${NIPA_INPUT_PARCELLATION_PATH:?Connectome requires an aligned parcellation Artifact}"
  case "$atlas" in
    *.nii.gz) atlas_path=/nipa-input/atlas.nii.gz ;;
    *.nii) atlas_path=/nipa-input/atlas.nii ;;
    *) echo "Connectome requires a NIfTI parcellation." >&2; exit 2 ;;
  esac
  inputs+=(--bind "$atlas:$atlas_path:ro")
fi
mr() { "${container[@]}" "${inputs[@]}" "$image" "$@"; }
validate_parcellation() {
  dwi_grid=$(mr mrinfo -size -spacing -transform "$dwi_path" | awk 'NR<=2 {print $1,$2,$3; next} {print}')
  atlas_grid=$(mr mrinfo -size -spacing -transform "$atlas_path")
  dimensions=$(mr mrinfo -ndim "$atlas_path")
  datatype=$(mr mrinfo -datatype "$atlas_path")
  if [[ "$dimensions" != 3 || ! "$datatype" =~ ^U?Int ]] ||
     ! awk '
       NR == FNR { widths[FNR] = NF; for (i = 1; i <= NF; i++) grid[FNR, i] = $i; next }
       NF != widths[FNR] { exit 1 }
       { for (i = 1; i <= NF; i++) {
           delta = $i - grid[FNR, i]
           if (delta > 0.0001 || delta < -0.0001) exit 1
         }
       }
     ' <(printf '%s\n' "$dwi_grid") <(printf '%s\n' "$atlas_grid"); then
    echo "Connectome requires a 3D integer label image matching the DWI grid and orientation." >&2
    exit 2
  fi
  read -r minimum maximum < <(mr mrstats "$atlas_path" -output min -output max)
  awk -v lo="$minimum" -v hi="$maximum" 'BEGIN {exit !(lo >= 0 && hi > 0)}' || {
    echo "Parcellation must contain positive region labels and no negative labels." >&2
    exit 2
  }
}
if [[ "$tracking" == 1 ]]; then
  shell_bvalues=$(mr mrinfo -shell_bvalues "${grad[@]}" "$dwi_path")
  read -r -a shells <<< "$shell_bvalues"
  # MRtrix reports shell means and treats b-values below 10 as b=0 by default.
  if [[ "${#shells[@]}" != 2 ]] ||
     ! awk -v baseline="${shells[0]}" -v diffusion="${shells[1]}" \
         'BEGIN { exit !(baseline < 10 && diffusion >= 10) }'; then
    printf 'Tractography requires a b=0 baseline and one nonzero diffusion shell. MRtrix detected: %s\n' \
      "${shell_bvalues:-none}" >&2
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
  if [[ "$parcellation_source" == freesurfer ]]; then
    echo "Preparing FreeSurfer parcellation in the selected DWI grid."
    mr dwiextract "$dwi_path" /nipa-work/b0.mif -bzero "${grad[@]}" -nthreads "$threads"
    mr mrmath /nipa-work/b0.mif mean /nipa-work/mean_b0.nii.gz -axis 3 -nthreads "$threads"
    mr mrconvert /nipa-input/norm.mgz /nipa-work/freesurfer_norm.nii.gz
    mr labelconvert /nipa-input/aparc+aseg.mgz /opt/freesurfer/FreeSurferColorLUT.txt \
      /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt /nipa-work/nodes_t1w.nii.gz
    mr env FSLOUTPUTTYPE=NIFTI_GZ /opt/fsl/bin/flirt -in /nipa-work/freesurfer_norm.nii.gz \
      -ref /nipa-work/mean_b0.nii.gz -dof 6 -cost normmi -omat /nipa-work/freesurfer_to_dwi.mat
    mr env FSLOUTPUTTYPE=NIFTI_GZ /opt/fsl/bin/flirt -in /nipa-work/nodes_t1w.nii.gz \
      -ref /nipa-work/mean_b0.nii.gz -applyxfm -init /nipa-work/freesurfer_to_dwi.mat \
      -interp nearestneighbour -datatype short -out "$atlas_path"
    mr cat /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt > "$work/node_labels.txt"
    files+=(nodes_dwi.nii.gz freesurfer_to_dwi.mat node_labels.txt)
  fi
  validate_parcellation
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
