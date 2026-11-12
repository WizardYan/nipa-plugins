# Official NIPA plugin packages

Open a plugin card in NIPA’s **Plugin Store** to read its manifest, open its package files, and review its runtime and license requirements before installing. Each preview is read from the corresponding verified release archive.

[Release v2.3.0](https://github.com/WizardYan/nipa-plugins/releases/tag/v2.3.0)

- [CAT12](#cat12)
- [fMRIPrep](#fmriprep)
- [FreeSurfer](#freesurfer)
- [LST-AI (CPU)](#lst_ai)
- [Thalamic Nuclei Segmentation](#thalamic_nuclei)
- [TRACULA](#tracula)
- [XCP-D](#xcp_d)

## cat12

**CAT12** · Plugin 1.1.0 · Runtime brainprep-anat-v1

Structural MRI morphometry and tissue segmentation.

**Package files**

- `plugin.yaml`
- `__init__.py`
- `run.sh`
- `run_cat12_one.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/cat12-1.1.0.nipa-plugin.tar.gz) · [Upstream documentation](https://github.com/ChristianGaser/cat12)

## fmriprep

**fMRIPrep** · Plugin 1.0.0 · Runtime 25.2.4

BIDS-native functional MRI preprocessing with preprocessed BOLD, confounds, and visual reports. Requires a FreeSurfer license.

**Package files**

- `plugin.yaml`
- `__init__.py`
- `adapter.py`
- `run.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/fmriprep-1.0.0.nipa-plugin.tar.gz) · [Upstream documentation](https://fmriprep.org/en/25.2.4/usage.html) · [NIPA Playground tutorial](README.md#create-an-fmriprep-plugin-in-nipa)

## freesurfer

**FreeSurfer** · Plugin 1.1.0 · Runtime 7.3.2

Anatomical reconstruction from T1w MRI. Requires a FreeSurfer license.

**Package files**

- `plugin.yaml`
- `__init__.py`
- `outputs.py`
- `run.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/freesurfer-1.1.0.nipa-plugin.tar.gz) · [Upstream documentation](https://surfer.nmr.mgh.harvard.edu/)

## lst_ai

**LST-AI (CPU)** · Plugin 1.0.2 · Runtime 2.0.0rc1-cpu

Research-only MS lesion segmentation from paired T1w and FLAIR images. The archive includes the plugin README and uses a separate CPU container.

**Package files**

- `README.md`
- `plugin.yaml`
- `__init__.py`
- `adapter.py`
- `run.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/lst_ai-1.0.2.nipa-plugin.tar.gz) · [Upstream documentation](https://github.com/CompImg/LST-AI)

## thalamic_nuclei

**Thalamic Nuclei Segmentation** · Plugin 1.1.0 · Runtime FreeSurfer 7.3.2

Segments thalamic nuclei from a compatible FreeSurfer anatomical reconstruction.

**Package files**

- `plugin.yaml`
- `__init__.py`
- `outputs.py`
- `run.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/thalamic_nuclei-1.1.0.nipa-plugin.tar.gz) · [Upstream documentation](https://surfer.nmr.mgh.harvard.edu/fswiki/ThalamicNuclei)

## tracula

**TRACULA** · Plugin 1.1.1 · Runtime FreeSurfer 7.3.2

Diffusion tractography with supporting FSL and ANTs requirements declared in the manifest.

**Package files**

- `plugin.yaml`
- `__init__.py`
- `adapter.py`
- `run.sh`
- `tracula_auto_configuration.sh`
- `tracula_check_freesurfer_outputs.sh`
- `tracula_exec.sh`
- `tracula_validate_configuration.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/tracula-1.1.1.nipa-plugin.tar.gz) · [Upstream documentation](https://surfer.nmr.mgh.harvard.edu/fswiki/Tracula)

## xcp_d

**XCP-D** · Plugin 26.2.0 · Runtime 26.2.0

Post-processes compatible BIDS derivatives to produce denoised BOLD and connectivity outputs.

**Package files**

- `plugin.yaml`
- `__init__.py`
- `adapter.py`
- `cli.py`
- `run.sh`

[Download package](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/xcp_d-26.2.0.nipa-plugin.tar.gz) · [Upstream documentation](https://xcp-d.readthedocs.io/)
