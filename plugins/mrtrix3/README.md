# MRtrix3 diffusion tensor fitting for NIPA

This plugin fits a diffusion tensor to one selected NIfTI DWI and publishes fractional anisotropy (FA), mean diffusivity (MD), axial diffusivity (AD), and radial diffusivity (RD). Use a DWI prepared for tensor fitting with matching FSL-format gradient files. For example, `sub-01_dwi.nii.gz` needs `sub-01_dwi.bvec` and `sub-01_dwi.bval` in the same folder. For multi-shell acquisitions, select a DWI prepared with the shells appropriate for your tensor analysis.

Prepare the DWI with any required motion, eddy-current, and susceptibility distortion correction before running the plugin. Tensor fitting always runs first.

- **Tractography** is off by default. Enable it to estimate a white matter FOD with single-shell CSD and generate 100,000 whole-brain iFOD2 streamlines. This option requires b=0 and one nonzero diffusion shell.
- **Connectome** is off by default. Enable it to also run tractography and generate a symmetric streamline-count matrix and streamline assignments. Register a 3D integer-label NIfTI parcellation as an anatomical segmentation for the same target. It must already match the DWI grid and affine. Label 0 is background.

The NIPA source update enables the checkboxes and conditional planning. Use this package with a NIPA build that includes that update so Review workflow can require the parcellation before submission.

Build or obtain the MRtrix3 3.0.8 SIF using the [official container instructions](https://mrtrix.readthedocs.io/en/latest/installation/using_containers.html).

```bash
apptainer build mrtrix3-3.0.8.sif docker://mrtrix3/mrtrix3:3.0.8
```

Register the SIF as the `mrtrix3-3.0.8` runtime in NIPA. Install the plugin package, register or select the DWI Artifact, then choose **Diffusion tensor fitting** in Expert Analysis. If a target has multiple DWIs, select the intended Artifact explicitly.

On a Singularity-only cluster such as Clinwulf, copy the SIF to storage accessible from the compute nodes and register that shared path in the cluster's NIPA instance. Make `singularity` available to NIPA and its Slurm jobs, loading your site's module where required. From a compute allocation, verify the image with:

```bash
singularity --version
singularity exec --cleanenv /shared/path/mrtrix3-3.0.8.sif dwi2tensor -version
```

See the MRtrix3 documentation for [dwi2tensor](https://mrtrix.readthedocs.io/en/latest/reference/commands/dwi2tensor.html) and [tensor2metric](https://mrtrix.readthedocs.io/en/latest/reference/commands/tensor2metric.html).
