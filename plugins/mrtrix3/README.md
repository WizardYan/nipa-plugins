# MRtrix3 diffusion tensor fitting for NIPA

This plugin fits a diffusion tensor to one selected NIfTI DWI and publishes fractional anisotropy (FA), mean diffusivity (MD), axial diffusivity (AD), and radial diffusivity (RD). Use a DWI prepared for tensor fitting with matching FSL-format gradient files. For example, `sub-01_dwi.nii.gz` needs `sub-01_dwi.bvec` and `sub-01_dwi.bval` in the same folder. For multi-shell acquisitions, select a DWI prepared with the shells appropriate for your tensor analysis.

Prepare the DWI with any required motion, eddy-current, and susceptibility distortion correction before running the plugin. Tensor fitting always runs first.

- **Tractography** is off by default. Enable it to estimate a white matter FOD with single-shell CSD and generate 100,000 whole-brain iFOD2 streamlines. This option requires b=0 and one nonzero diffusion shell.
- **Connectome** is off by default. Enable it to also run tractography and generate a symmetric streamline-count matrix and streamline assignments. Under **Parcellation source**, choose an existing aligned 3D integer-label NIfTI or a FreeSurfer reconstruction for the selected target. The reconstruction must contain `mri/norm.mgz` and `mri/aparc+aseg.mgz`.
- With **FreeSurfer reconstruction**, the plugin registers `norm.mgz` to the mean b=0 image using rigid FLIRT with normalized mutual information. It converts FreeSurfer labels to consecutive node IDs and resamples them with nearest-neighbor interpolation. The output includes the aligned node map, registration matrix, and node lookup table. Inspect the label overlay on the b=0 image before interpreting the connectome.

The NIPA source update enables the checkboxes and conditional planning. Use this package with a NIPA build that includes that update so Review workflow can require the parcellation before submission.

In Plugin Store → MRtrix3 → Runtime and license setup, select **Build SIF with Singularity** when Singularity is available to NIPA. NIPA converts the official MRtrix3 3.0.8 Docker image into a SIF on the server and registers it in the configured runtime store. The server needs access to Docker Hub and writable build scratch. The runtime store must be accessible to the compute nodes.

To build outside NIPA, follow the [official container instructions](https://mrtrix.readthedocs.io/en/latest/installation/using_containers.html), then use **Find existing SIF** to register the image.

```bash
singularity build mrtrix3-3.0.8.sif docker://mrtrix3/mrtrix3:3.0.8
```

Register the SIF as the `mrtrix3-3.0.8` runtime in NIPA. Install the plugin package, register or select the DWI Artifact, then choose **Diffusion tensor fitting** in Expert Analysis. If a target has multiple DWIs, select the intended Artifact explicitly.

On a Singularity-only cluster such as Clinwulf, copy the SIF to storage accessible from the compute nodes and register that shared path in the cluster's NIPA instance. Make `singularity` available to NIPA and its Slurm jobs, loading your site's module where required. From a compute allocation, verify the image with:

```bash
singularity --version
singularity exec --cleanenv /shared/path/mrtrix3-3.0.8.sif dwi2tensor -version
```

See the MRtrix3 documentation for [dwi2tensor](https://mrtrix.readthedocs.io/en/latest/reference/commands/dwi2tensor.html) and [tensor2metric](https://mrtrix.readthedocs.io/en/latest/reference/commands/tensor2metric.html).
