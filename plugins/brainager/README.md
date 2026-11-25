# brainageR for NIPA

Plugin **0.1.1** · brainageR **2.1** · NIPA **3.0.15 or newer**

Predict brain age from one raw T1-weighted MRI per selected target. The plugin
wraps the Octave/SPM12 container implementation linked by the brainageR authors.
It does not use FreeSurfer reconstructions or fMRIPrep-preprocessed T1w images.

## Inputs and outputs

Select a raw T1w Artifact (`imaging.mri.anatomical.image`, `contrast: T1w`). This
can be an indexed BIDS input or a registered standalone file. Both `.nii` and
`.nii.gz` are supported. Ambiguous multiple inputs must be explicitly resolved
in NIPA before submission.

The required prediction Artifact is a `table.feature` CSV containing:

- `brain.predicted_age`: model prediction in years.
- `lower.CI`, `upper.CI`: upstream 95% confidence interval in years.
- `chronological_age`: optional user-provided age.
- `brain_PAD`: predicted age minus chronological age; blank when age is omitted.
- Subject and session labels used for this execution.

An upstream segmentation QC HTML report is also registered when generated. Its
image assets remain beside it in `qc/`. The unmodified native prediction CSV and
`execution.json` remain available through Data → By folder. NIPA records the
selected input, plugin/runtime identity, parameters and execution lineage.

Results use separate subject/session/attempt directories. Existing attempt
outputs are never overwritten by this adapter.

## Parameters

| Setting | Default | Meaning |
| --- | --- | --- |
| Chronological age | Empty | Optional age in years, used only for brain-PAD. Not supplied to the prediction model. |
| Keep segmentation intermediates | Off | Retain generated SPM images/transforms in the attempt output folder. |

A single parameter value applies to every selected target. For mixed-age batches,
leave chronological age empty and join subject-specific ages downstream. The
upstream model was trained on adults aged 18–92; prediction outside its training
domain requires separate validation. This adapter does not add age-bias correction.

Initial resource profile: 4 CPUs, 16 GB RAM, 4 hours and 16 GB scratch, CPU only.
These are provisional site starting values, not measured guarantees. Override
them in NIPA based on real runtime measurements.

## Runtime setup

In Plugin Store → brainageR → Runtime and license setup, click **Build SIF with
Singularity**. NIPA downloads the pinned image layers, materializes a local SIF,
checks it and registers it automatically. With Apptainer the generic button may
be labelled **Install runtime**; it performs the same SIF conversion. No Docker
daemon is required on Clinwulf. Singularity/Apptainer must already be available
in the environment that starts NIPA. You can still register an existing SIF;
`BRAINAGER_SIF` remains the runtime binding environment variable.

The managed source is the third-party **atlasli/brainage** image, whose publisher
identifies it as brainageR 2.1 based on the Octave container recipe. It is not an
author-official image. NIPA pins it by immutable OCI digest, never a floating tag:

```text
docker://atlasli/brainage@sha256:25d7ca8d699dc83cbc578467864488f162c46322c1de85b1a4efcdf99542947b
```

The download is approximately 3.43 GiB of compressed layers. Building the SIF
requires additional scratch space and may take several minutes. NIPA selects
and checks scratch storage before starting; download/conversion progress and
cancellation are available in the runtime setup panel. The existing generic
installer also registers interrupted builds as failed/retryable after a server
restart. Do not assume an interrupted build has installed a valid image.

The image must implement the upstream container layout:

- `/opt/brainageR/software/brainageR` (Octave wrapper, brainageR 2.1).
- PCA center, rotation and scale RDS files, GPR model, training labels and templates.
- SPM12 r7219 with the required Octave compatibility, R and its dependencies,
  FSL QC utilities, NiftyReg and NiftySeg.

The Octave container does not require a MATLAB license file. Its constituent
tools still have their own licensing terms. This package references an image
hosted by its publisher; it redistributes neither the container nor the models.

### Optional rebuild from upstream sources

For a build machine with Docker and Singularity/Apptainer, start from the upstream
container recipe pinned at commit `8ed63f92555c65e9c49d752af24af9db4e0a29ce`:

```sh
git clone https://github.com/fprados/brainageR_dockerfile.git
cd brainageR_dockerfile
git checkout 8ed63f92555c65e9c49d752af24af9db4e0a29ce
docker build -t brainager:2.1 .
singularity build brainager-2.1.sif docker-daemon:brainager:2.1
```

Replace `singularity` with `apptainer` where applicable. The upstream recipe is
based on Ubuntu 16.04 and downloads dependencies; current archive/CRAN availability
can require maintenance. These commands document the upstream build route; the
SIF build has **not** been accepted by this plugin's engineering tests. Preserve
the built image and its checksum after site validation, then register that SIF
on the execution site. Do not schedule image builds inside scientific jobs.

## GUI example

1. Install/update `brainager-0.1.1.nipa-plugin.tar.gz` and click the SIF build button,
   or register a complete existing SIF. Wait until runtime setup reports ready.
2. In Data, select one indexed raw T1w or import/register a standalone T1w and
   assign Artifact type `imaging.mri.anatomical.image` and contrast `T1w`.
3. Choose Use in Analysis. In Expert choose **Brain age prediction**, or choose
   its prediction output in Guided.
4. Leave chronological age empty, or enter the age for this one target. Review
   the exact input and resources, then run.
5. Find **Brain age prediction** and the optional **Segmentation QC report** in
   Data, and verify their execution/run provenance. Inspect QC before using the
   estimated age in a study.

## Input protection and isolation

The upstream Octave wrapper changes the image header in place. This adapter
copies/decompresses the reviewed input into a private attempt work directory and
passes only that copy to the container. It also provides private `/tmp` and home
directories, avoiding upstream fixed temporary filename collisions across jobs.

The adapter imports only Python's standard library. All contracts, parameters,
runtime requirements and output discovery rules live in `plugin.yaml`; no
brainageR-specific NIPA core or frontend code is required.

## Validation status

Engineering acceptance uses an explicitly simulated container command, never
synthetic prediction logic in the production entry point. It verifies exact
input staging, original-file preservation, both runtime engines, parameter
handling, failure behavior, Artifact discovery and execution/run provenance.
It is **not** a real brain-age prediction or scientific validation. Real SIF
build, raw-MRI execution and QC review remain to be accepted separately.

## Upstream sources

- [brainageR](https://github.com/james-cole/brainageR), version tag `2.1`.
- [Managed image publisher](https://hub.docker.com/r/atlasli/brainage).
- [Octave container recipe](https://github.com/fprados/brainageR_dockerfile/tree/8ed63f92555c65e9c49d752af24af9db4e0a29ce).
- [Native prediction CSV implementation](https://github.com/james-cole/brainageR/blob/2.1/predict_new_data_gm_wm_csf.R).

Please cite brainageR and relevant upstream software as requested in their documentation.
