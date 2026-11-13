# NIPA Artifact contract types

Proposed contract profiles for the first rollout. Each row retains a registered Artifact type ID. A profile combines that ID with the attributes, resource requirements, and workflow checks needed to bind a particular input. The profile names are display labels.

| Profile | Artifact type ID | Attributes to declare or verify | Resource and workflow checks |
| --- | --- | --- | --- |
| Raw anatomical scan | `imaging.mri.anatomical.image` | `contrast: T1w`, `T2w`, or `FLAIR`; `processing_state: raw` | Readable 3D image in an accepted format. For paired inputs, check subject and session and any alignment requirement stated by the plugin. |
| Preprocessed anatomical scan | `imaging.mri.anatomical.image` | Contrast, `processing_state: preprocessed`, space when known | Check format and dimensions. Check the actual grid when the consumer requires voxel alignment. |
| Raw BOLD time series | `imaging.mri.functional.bold` | Proposed `representation: time_series`; `processing_state: raw` | Check a readable 4D series. Resolve inherited BIDS metadata when required. Keep task, acquisition, run, and echo as entities. |
| Preprocessed BOLD time series | `imaging.mri.functional.bold` | Proposed `representation: time_series`; `processing_state: preprocessed`; space when known | Check dimensionality and representation accepted by the consumer. Match confounds and masks to the correct run when required. |
| BOLD reference | `imaging.mri.functional.bold` | `representation: reference` | Check a readable 3D reference image and its association with the intended run. |
| Denoised BOLD | `imaging.mri.functional.bold` | `processing_state: postprocessed`; `denoised: true`; space when known | Declare the actual representation and check whether the consumer supports it. |
| Functional confounds | `imaging.mri.functional.timeseries` | `representation: confounds` | Check the required columns and alignment with the corresponding BOLD volumes according to the consumer's rules. |
| Functional connectivity | `imaging.mri.functional.connectivity` | For a matrix, `representation: matrix`; declare measure and atlas when applicable | Verify matrix shape, parcel labels and ordering, and any required time or window axis. |
| Diffusion scan | `imaging.mri.diffusion.dwi` | Processing state and space when established | When gradients are required, verify b-values and b-vectors correspond to the image volumes. |
| Anatomical segmentation | `imaging.mri.anatomical.segmentation` | Segmentation type, structure or label scheme, and space when relevant | Distinguish binary masks, discrete labels, and probabilistic outputs through the contract. Check the required reference grid. |
| FreeSurfer reconstruction | `imaging.mri.anatomical.reconstruction` | `representation: anatomical_reconstruction`; `method: freesurfer` | Resolve the subject directory. Check the consumer's required reconstruction files and subject identity. |
| BIDS source dataset | `dataset.bids` | BIDS version when known | Resolve the dataset root, target, and plugin-required inputs and metadata. |
| BIDS preprocessing derivatives | `dataset.derivatives.bids` | `standard: BIDS`; `processing_state: preprocessed`; pipeline layout when established | Resolve the dataset root. Check the layout and target files required by the consumer. The current XCP-D wrapper selects the fMRIPrep layout. |
| Plain text | `text` | Declare the encoding or format if the consumer depends on it | Bind a readable file. Project-level text can have no subject or session. |

## First workflow connections

1. **fMRIPrep → XCP-D.** Bind a preprocessing derivatives dataset that satisfies the fMRIPrep layout selected by the XCP-D wrapper. Report the missing target files or unsupported layout at review time where they can be checked. A standalone BOLD reference cannot satisfy this dataset contract.
2. **FreeSurfer → Thalamic Nuclei Segmentation.** Bind the matching FreeSurfer subject directory. Verify the files needed by the configured operation, such as `mri/norm.mgz` when used by the wrapper.
3. **BIDS T1w + FLAIR → LST-AI.** Match each contrast, pair scans within the same subject and session, and expose acquisition and run labels when multiple eligible pairs remain. Apply any required alignment check separately.

## Compatibility and rollout

NIPA currently checks type inheritance, declared attributes and entities, and required resource roles. The table also proposes checks for format, geometry, and bundle contents. Those checks need implementation or an explicit preflight before a strict contract can rely on them. The proposed BOLD `time_series` value needs to be added to the vocabulary and stamped by importers and producers before consumers require it.

Keep subject, session, task, and run as entities, and store physical format on the resource. Check relationships such as matching runs or image grids after candidate inputs have been identified. When evidence is missing, report what could not be verified. When several candidates qualify, show them for selection. When a resource is planned upstream, verify its actual files when they become available.

Keep existing type IDs and legacy plugin behavior. Introduce strict profiles per plugin connection after its producer and importer supply the required metadata. Existing artifacts can be rescanned or enriched from evidence. The built-in type registry is listed below.

## Full built-in type registry

This reference covers all 70 built-in IDs in NIPA 2.4.0a13. The parent column shows which broader type a child can satisfy during matching. Recommended attributes are guidance from the registry. A plugin declares which values it requires for a specific input. Installed plugins can also declare namespaced types, so those additions vary by installation.

### Datasets

| Type ID | Parent | Meaning | Recommended attributes |
| --- | --- | --- | --- |
| `dataset` | — | Dataset-level artifact. | `standard`, `version` |
| `dataset.bids` | `dataset` | Dataset organized according to the BIDS standard. | `bids_version`, `dataset_type` |
| `dataset.derivatives` | `dataset` | Dataset containing derived scientific products. | `pipeline_name`, `pipeline_version` |
| `dataset.derivatives.bids` | `dataset.derivatives` | BIDS-compatible derivatives dataset. | `bids_version`, `pipeline_name` |

### MRI

| Type ID | Parent | Meaning | Recommended attributes |
| --- | --- | --- | --- |
| `imaging.mri` | `imaging` | Magnetic resonance imaging domain artifact. | `field_strength`, `manufacturer` |
| `imaging.mri.anatomical` | `imaging.mri` | Structural or anatomical MRI artifact. | `space`, `resolution` |
| `imaging.mri.anatomical.image` | `imaging.mri.anatomical` | Anatomical MRI image, with contrast represented by attributes. | `contrast`, `processing_state`, `space` |
| `imaging.mri.anatomical.segmentation` | `imaging.mri.anatomical` | Anatomical segmentation, parcellation, or labeled structure map. | `segmentation_type`, `labels`, `atlas`, `space` |
| `imaging.mri.anatomical.reconstruction` | `imaging.mri.anatomical` | Reconstructed anatomical representation usable independently of its producer. | `representation`, `method`, `space` |
| `imaging.mri.anatomical.surface` | `imaging.mri.anatomical` | Cortical or subcortical surface representation. | `surface_type`, `hemisphere`, `space` |
| `imaging.mri.anatomical.mask` | `imaging.mri.anatomical` | Mask defined in an anatomical MRI domain. | `mask_type`, `space` |
| `imaging.mri.functional` | `imaging.mri` | Functional MRI domain artifact. | `task`, `space` |
| `imaging.mri.functional.bold` | `imaging.mri.functional` | Blood-oxygen-level-dependent functional MRI image data. | `processing_state`, `task`, `space`, `resolution` |
| `imaging.mri.functional.mask` | `imaging.mri.functional` | Mask defined in a functional MRI domain. | `mask_type`, `task`, `space` |
| `imaging.mri.functional.timeseries` | `imaging.mri.functional` | Functional MRI-derived temporal signal representation. | `representation`, `atlas`, `space` |
| `imaging.mri.functional.activation` | `imaging.mri.functional` | Task activation or statistical map derived from functional MRI. | `map_type`, `contrast`, `statistic`, `space` |
| `imaging.mri.functional.intrinsic_activity` | `imaging.mri.functional` | Local intrinsic activity metric derived from functional MRI. | `metric`, `frequency_band`, `space` |
| `imaging.mri.functional.decomposition` | `imaging.mri.functional` | Component or latent decomposition derived from functional MRI. | `method`, `representation`, `component_count`, `space` |
| `imaging.mri.functional.connectivity` | `imaging.mri.functional` | Functional connectivity result derived from functional MRI. | `representation`, `measure`, `atlas`, `space` |
| `imaging.mri.diffusion` | `imaging.mri` | Diffusion MRI domain artifact. | `space`, `model` |
| `imaging.mri.diffusion.dwi` | `imaging.mri.diffusion` | Diffusion-weighted MRI image data with gradient metadata. | `processing_state`, `b_values`, `space` |
| `imaging.mri.diffusion.mask` | `imaging.mri.diffusion` | Mask defined in a diffusion MRI domain. | `mask_type`, `space` |
| `imaging.mri.diffusion.model` | `imaging.mri.diffusion` | Fitted diffusion MRI model or model representation. | `model`, `parameters`, `space` |
| `imaging.mri.diffusion.scalar_map` | `imaging.mri.diffusion` | Scalar map derived from a diffusion MRI model. | `metric`, `model`, `space` |
| `imaging.mri.diffusion.orientation` | `imaging.mri.diffusion` | Fiber or orientation representation derived from diffusion MRI. | `representation`, `model`, `space` |
| `imaging.mri.diffusion.tractography` | `imaging.mri.diffusion` | Tractography or pathway representation derived from diffusion MRI. | `representation`, `algorithm`, `space` |
| `imaging.mri.diffusion.connectivity` | `imaging.mri.diffusion` | Structural connectivity result derived from diffusion MRI. | `representation`, `atlas`, `weight`, `space` |
| `imaging.mri.perfusion` | `imaging.mri` | Perfusion MRI domain artifact. | `method`, `space` |
| `imaging.mri.perfusion.image` | `imaging.mri.perfusion` | Acquired or processed perfusion MRI image. | `method`, `processing_state`, `space` |
| `imaging.mri.perfusion.parametric_map` | `imaging.mri.perfusion` | Quantitative parameter map derived from perfusion MRI. | `parameter`, `method`, `space` |
| `imaging.mri.spectroscopy` | `imaging.mri` | Magnetic resonance spectroscopy domain artifact. | `nucleus`, `acquisition_type` |
| `imaging.mri.spectroscopy.spectrum` | `imaging.mri.spectroscopy` | Magnetic resonance spectrum. | `nucleus`, `voxel`, `frequency_reference` |
| `imaging.mri.spectroscopy.map` | `imaging.mri.spectroscopy` | Spectroscopic imaging or metabolite map. | `metabolite`, `space` |
| `imaging.mri.spectroscopy.quantification` | `imaging.mri.spectroscopy` | Quantified magnetic resonance spectroscopy result. | `metabolite`, `unit`, `method` |

### PET

| Type ID | Parent | Meaning | Recommended attributes |
| --- | --- | --- | --- |
| `imaging.pet` | `imaging` | Positron emission tomography domain artifact. | `tracer`, `space` |
| `imaging.pet.image` | `imaging.pet` | Static, dynamic, acquired, or processed PET image data. | `tracer`, `acquisition`, `processing_state`, `space` |
| `imaging.pet.mask` | `imaging.pet` | Mask defined in a PET domain. | `mask_type`, `space` |
| `imaging.pet.timeseries` | `imaging.pet` | Dynamic PET temporal signal or time-activity curve. | `representation`, `tracer`, `time_unit` |
| `imaging.pet.kinetic_model` | `imaging.pet` | PET kinetic-model result. | `model`, `reference_region`, `input_function` |
| `imaging.pet.parametric_map` | `imaging.pet` | Quantitative PET parameter map. | `parameter`, `model`, `tracer`, `space` |
| `imaging.pet.segmentation` | `imaging.pet` | Segmentation derived from PET data. | `segmentation_type`, `labels`, `space` |
| `imaging.pet.quantification` | `imaging.pet` | Regional or global PET quantification result. | `measure`, `unit`, `atlas`, `tracer` |
| `imaging.pet.connectivity` | `imaging.pet` | PET covariance or connectivity result. | `representation`, `measure`, `atlas` |

### EEG

| Type ID | Parent | Meaning | Recommended attributes |
| --- | --- | --- | --- |
| `imaging.eeg` | `imaging` | Electroencephalography domain artifact. | `sampling_rate`, `reference` |
| `imaging.eeg.continuous` | `imaging.eeg` | Continuous EEG recording. | `processing_state`, `sampling_rate`, `reference` |
| `imaging.eeg.epochs` | `imaging.eeg` | Epoched EEG data. | `event_type`, `time_window`, `baseline` |
| `imaging.eeg.evoked` | `imaging.eeg` | Averaged evoked or event-related EEG response. | `event_type`, `condition`, `reference` |
| `imaging.eeg.timeseries` | `imaging.eeg` | EEG-derived temporal signal representation. | `representation`, `channels`, `source_space` |
| `imaging.eeg.spectral` | `imaging.eeg` | Frequency-domain EEG result. | `representation`, `frequency_band`, `method` |
| `imaging.eeg.time_frequency` | `imaging.eeg` | Time-frequency EEG representation. | `method`, `frequency_range`, `time_range` |
| `imaging.eeg.source` | `imaging.eeg` | EEG source-reconstruction result. | `method`, `source_space`, `inverse_method` |
| `imaging.eeg.components` | `imaging.eeg` | EEG decomposition or component representation. | `method`, `component_count` |
| `imaging.eeg.connectivity` | `imaging.eeg` | EEG connectivity result. | `representation`, `measure`, `frequency_band` |
| `imaging.eeg.events` | `imaging.eeg` | EEG event or marker information. | `event_type`, `condition` |

### Multimodal

| Type ID | Parent | Meaning | Recommended attributes |
| --- | --- | --- | --- |
| `imaging.multimodal` | `imaging` | Artifact derived jointly from multiple modalities. | `modalities` |
| `imaging.multimodal.fusion` | `imaging.multimodal` | Joint multimodal fusion result. | `modalities`, `method` |
| `imaging.multimodal.feature` | `imaging.multimodal` | Combined multimodal feature representation. | `modalities`, `feature_type` |
| `imaging.multimodal.connectivity` | `imaging.multimodal` | Connectivity result integrating multiple modalities. | `modalities`, `representation`, `measure` |
| `imaging.multimodal.representation` | `imaging.multimodal` | General multimodal latent or embedded representation. | `modalities`, `method` |

### General types

| Type ID | Parent | Meaning | Recommended attributes |
| --- | --- | --- | --- |
| `imaging` | — | Neuroimaging or neurophysiology domain artifact. | — |
| `transform` | — | Spatial, temporal, or coordinate transform. | `from_space`, `to_space`, `transform_type` |
| `table` | — | Generic structured or tabular scientific result. | `schema`, `format` |
| `table.feature` | `table` | Feature table. | `feature_domain`, `unit` |
| `table.statistics` | `table` | Statistical summary table. | `statistic`, `grouping` |
| `report` | — | Human-readable scientific or quality-control report. | `report_type`, `format` |
| `qc` | — | Quality-control artifact. | `qc_type`, `scope`, `status` |
| `model` | — | General computational or statistical model artifact. | `model_type`, `framework` |
| `metadata` | — | Metadata artifact. | `schema`, `scope` |
| `annotation` | — | Human or machine annotation. | `annotation_type`, `author` |
| `text` | — | Generic textual artifact. | `format`, `language` |
