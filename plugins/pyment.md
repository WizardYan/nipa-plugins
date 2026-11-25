# pyment

Plugin **0.1.0** · Runtime **5.1.0** · Requires **NIPA 3.0.15 or newer**

Predict brain age from one raw T1w MRI using the author's FastSurfer preprocessing and pyment inference pipeline. Choose **multi-2025** or **reg-2025**. The initial execution path uses CPU.

[README and setup](pyment/README.md) · [Download package](https://github.com/WizardYan/nipa-plugins/releases/download/pyment-v0.1.0/pyment-0.1.0.nipa-plugin.tar.gz)

SHA-256 `cdcb4263dad0f32970cb164a289ba92a7cc6f15c57f23c56550a7c0e73f247b4`

## Runtime and license

Use **Build SIF with Singularity** in Plugin Store (Apptainer uses **Install runtime**) to convert the author's digest-pinned OCI image and register the SIF. Configure an existing FreeSurfer license in the same setup panel. Docker is not required. Image layers total approximately 7.88 GiB; allow additional scratch and final-image space. The package includes no image, weights or license files.

## Outputs and isolation

The prediction CSV records brain age, selected model and weight fingerprint; optional chronological age adds brain-PAD. The retained FastSurfer model crop is an optional image Artifact. Inputs, outputs and execution/run provenance use NIPA's existing generic contracts. No NIPA core changes are required.

## Acceptance status

29 engineering tests passed, including both models, input protection, runtime-install and license APIs, real NIPA local-executor dispatch, Artifact registration and execution/run filtering. Scientific container commands and runtime-install workers were explicitly simulated. Reproducible packaging and clean installation passed. **A full real SIF build and real MRI prediction remain unverified.** Suggested resources are provisional. Review the README before scientific use.

pyment is licensed CC BY-NC 4.0; comply with upstream and dependency terms.

## Package files

- [README.md](pyment/README.md)
- [plugin.yaml](pyment/plugin.yaml)
- [run.py](pyment/run.py)
- [pipeline.py](pyment/pipeline.py)

[Upstream pyment](https://github.com/estenhl/pyment-public) · [All official plugins](../official-plugins.md)
