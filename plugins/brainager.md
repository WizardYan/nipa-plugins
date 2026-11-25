# brainageR

Plugin version **0.1.0** · Runtime **2.1** · Requires **NIPA 3.0.15 or newer**

Predict brain age from raw T1w MRI. Outputs include predicted age, its confidence interval, optional brain-PAD and a segmentation QC report when available.

[Read README and setup guide](brainager/README.md)

[Download plugin package](https://github.com/WizardYan/nipa-plugins/releases/download/brainager-v0.1.0/brainager-0.1.0.nipa-plugin.tar.gz)

SHA-256 `01fc0c75323d9b0ae56b408e54be7ca8872a174602fa64f01e02c25190d601c5`

## Package files

- [README.md](brainager/README.md)
- [plugin.yaml](brainager/plugin.yaml)
- [run.py](brainager/run.py)

## Acceptance status

16 engineering tests passed, including both container engine command paths, input preservation, standalone-file execution, Artifact discovery and execution/run lineage. The container command was explicitly simulated. A complete site-provided Singularity/Apptainer SIF is required. Real SIF build and real MRI prediction remain to be accepted; this is not a scientifically validated release.

[Upstream brainageR](https://github.com/james-cole/brainageR) · [All official plugins](../official-plugins.md)
