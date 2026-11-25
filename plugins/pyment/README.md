# pyment for NIPA

Plugin **0.1.0** · pyment **5.1.0** · NIPA **3.0.15 or newer**

This plugin processes one reviewed raw T1-weighted image per target through the
author's FastSurfer preprocessing and pyment prediction pipeline. It supports
indexed BIDS T1w Artifacts and standalone registered T1w files. No BIDS directory
is required for a registered standalone file. Source MRI files are copied to
private attempt staging and are never passed to preprocessing in place.

## Models and parameters

| Setting | Default | Meaning |
| --- | --- | --- |
| Prediction model | `multi-2025` | Select `multi-2025` (SFCN multi-task) or `reg-2025` (SFCN age regression). The adapter selects the matching architecture, weights and target names together. |
| Chronological age | Empty | Optional years, used only for brain-PAD = predicted age minus chronological age. It does not enter the prediction model. |
| Keep FastSurfer preprocessing | On | Preserve preprocessing and register `crop.mgz`, the actual input to pyment inference. |

One parameter value applies to every selected target. For mixed-age batches,
leave chronological age empty and join subject/session ages downstream. The
plugin performs no additional age-bias correction. Model IDs are the current
2025 models and must not be confused with earlier pyment publications/models.

The upstream multi-task model has six output heads. Its native CSV is retained,
but the primary NIPA Artifact reports brain age only. No confidence interval or
uncertainty estimate is invented by this adapter.

## Outputs and lineage

- **Brain age prediction** (`table.feature`): one CSV row with predicted age,
  model ID, weights SHA-256, optional chronological age and brain-PAD.
- **pyment model input crop** (`imaging.mri.anatomical.image`): the cropped,
  FastSurfer-conformed `crop.mgz`, when preprocessing retention is enabled.

The native prediction CSV, retained preprocessing files and `execution.json`
are available through Data → By folder. Each attempt publishes to a separate
directory. NIPA attaches the input bindings, scientific execution ID, attempt ID
and workflow run lineage. `execution.json` additionally records the selected
model, architecture, actual weights SHA-256 and upstream Git blob identity.
The license file and its contents are not copied into outputs.

## Runtime and license setup

1. Install the plugin package.
2. Open its Plugin Store detail page and click **Build SIF with Singularity**.
   With Apptainer, the generic button may be called **Install runtime**. Wait for
   the image conversion and registration to complete. Docker is not required.
3. Configure the **FreeSurfer** license using a valid license file on the NIPA
   server. NIPA's site-scoped license configuration can be reused by other
   plugins. The adapter binds this file read-only at `/licenses/freesurfer.txt`.
4. Confirm both the runtime and license setup are ready before opening Analysis.

The author-published combined image is pinned to this OCI digest:

```text
docker://estenhl/pyment-preprocess-and-predict@sha256:005375770551e2d120a092293267058b4aca1373bbdcb59ae44a2c615cc3bad7
```

This is the `5.1.0` image, not a floating tag. Its public OCI manifest/config and
Linux/amd64 platform have been verified. The compressed layers total about
7.88 GiB; conversion requires additional scratch and final-image space. NIPA's
existing installer handles storage checks, background progress and cancellation.
An existing compatible SIF can also be registered through `PYMENT_SIF`/runtime
setup. The complete real SIF build has not yet been accepted for this plugin.

The image includes FastSurfer 2.0.1 and bundled pyment model weights. Before
preprocessing, the container-side adapter verifies the selected weight file
against the published Git blob identifier and computes its SHA-256. Missing or
mismatched weights fail the job; execution does not download substitute models.

The initial execution path is **CPU only**. CUDA visibility is disabled so the
plugin does not silently use an unallocated GPU. A GPU execution path requires
separate scheduler/resource and scientific acceptance. Initial suggested
resources are 4 CPUs, 16 GB RAM, 4 hours and 32 GB scratch. These are provisional
starting values, not a benchmark or guaranteed bound; users can override them.

The current development machine has approximately 8 GB RAM and no available GPU.
Engineering acceptance therefore does not claim a full real-image inference.

## GUI example

1. In Data, select one raw T1w Artifact, or register a standalone `.nii`/`.nii.gz`
   with type `imaging.mri.anatomical.image` and contrast `T1w`.
2. Choose **Use in Analysis**. In Expert choose **Brain age prediction with
   pyment**, or select its prediction output in Guided.
3. Select `multi-2025` or `reg-2025`. Leave chronological age empty initially.
4. Review the exact selected input and resources, then submit.
5. Open the prediction CSV in Data, inspect the retained crop if enabled, and
   check View provenance and filtering by the corresponding execution/run.

Existing FreeSurfer reconstructions or fMRIPrep derivatives are not accepted as
an equivalent preprocessing route by this initial adapter. It always follows
the author's raw-T1w FastSurfer path. Fine-tuning and additional phenotype
analyses are outside this initial plugin's scope.

## Package boundaries and validation

`plugin.yaml` declares parameters, inputs, outputs, managed runtime and license
requirements. `run.py` stages the exact reviewed input and publishes validated
outputs. `pipeline.py` runs inside the container and selects the matching
preprocessing/inference commands. Both Python files use only the standard
library and local plugin code; no private NIPA modules or project database APIs
are imported. Output Artifacts use single declarations, without a custom scanner.

Engineering tests use an explicitly simulated container and isolated projects.
They verify both model choices, input protection, license setup, runtime task
creation, failure cases, Artifact registration and execution/run provenance.
These tests do not constitute real SIF construction or scientific validation of
the model. Real-image inference, preprocessing QC and performance remain to be
accepted on a suitable machine.

## Licensing and upstream references

The pyment repository is licensed **CC BY-NC 4.0**. Retain the author attribution
and comply with its noncommercial conditions and the bundled dependencies'
terms. This plugin references the author's image and does not redistribute
model weights or license files.

- [pyment repository](https://github.com/estenhl/pyment-public)
- [License](https://github.com/estenhl/pyment-public/blob/main/LICENSE.md)
- [Author container image](https://hub.docker.com/r/estenhl/pyment-preprocess-and-predict)
- [Pinned source reference](https://github.com/estenhl/pyment-public/tree/db4166143aa35a8b27aa08ec4c8bb2660f545ebe)
- [FastSurfer](https://github.com/Deep-MI/FastSurfer)

The image digest, model ID and actual weight fingerprint are the execution's
reproducibility anchors; the source commit above documents the inspected interface.
