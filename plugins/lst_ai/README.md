# LST-AI CPU plugin for NIPA

Standalone Plugin SDK v3 wrapper for research-only MS lesion segmentation.
Scientific software: [CompImg/LST-AI](https://github.com/CompImg/LST-AI) (MIT).
The plugin **does not redistribute** LST-AI or its model weights.

## Installation

```bash
nipa plugin install lst_ai-1.0.2.nipa-plugin.tar.gz --replace
```

On an HPC node with Singularity available, acquire the upstream CPU image:

```bash
singularity pull lst-ai-2.0.0rc1-cpu.sif docker://jqmcginnis/lst-ai:v2.0.0rc1-cpu
```

Configure the NIPA site's runtime resolution to provide:

- `LST_AI_SIF`: absolute path to the site-managed `.sif` image.
- `NIPA_CONTAINER_RUNTIME`: `singularity`.

The upstream image tag must be checked and its immutable digest recorded before
production deployment. NIPA records plugin package identity separately from
the scientific container identity.

## Contract

- Inputs: NIPA-resolved T1w and FLAIR NIfTI images for the same subject/session.
- Input paths are read from `NIPA_INPUT_MANIFEST` dataset bindings, not
  `NIPA_INPUT_T1W_PATH` / `NIPA_INPUT_FLAIR_PATH` (artifact-only exports).
- Runtime: CPU-only Singularity, `--device cpu`.
- Outputs: `derivatives/lst_ai/sub-*/[ses-*/]`.
- Optional probability maps are copied from the working directory into
  `probability_maps/` so they appear in Results.
- The output adapter assigns semantic Artifact types only to recognized names;
  unknown NIfTI derivatives remain ordinary files in Results.

NIPA-selected inputs must both be skull-stripped or both unstripped. The default
is unstripped. The plugin does not silently select a file when multiple T1w or
FLAIR candidates exist.

## Qualification status

The manifest is SDK-valid and offline mock execution passes. Real Singularity
execution, output filename matching for the pinned LST-AI version, HPC resource
requirements, and scientific outputs must be validated at the deployment site.
This is **not** clinical software.
