# brainageR

Plugin version **0.1.1** · brainageR **2.1** · Requires **NIPA 3.0.15 or newer**

Predict brain age from raw T1w MRI; output age, confidence interval, optional brain-PAD and available segmentation QC.

[README and runtime setup](brainager/README.md) · [Download package](https://github.com/WizardYan/nipa-plugins/releases/download/brainager-v0.1.1/brainager-0.1.1.nipa-plugin.tar.gz)

SHA-256 `920b28e207654a5dd547bc7439b1d36551244f1fff67f043baddc26f703e66fc`

## One-click runtime setup

After updating the plugin, click **Build SIF with Singularity** in its runtime setup panel. Apptainer uses **Install runtime**. NIPA converts the digest-pinned third-party atlasli/brainage OCI image into a local SIF and registers it, using the existing generic runtime installer. Docker is not required on the execution host. Existing SIF registration remains supported.

## Acceptance status

17 engineering tests passed. Public OCI manifest digest and platform verified, GUI build button visible, and installation API task creation tested with a simulated worker. **The complete real SIF build and real MRI prediction have not been verified.** This image is published by atlasli, not the brainageR authors. No NIPA core change is required.

## Files

- [plugin.yaml](brainager/plugin.yaml)
- [run.py](brainager/run.py)
- [README.md](brainager/README.md)

[All official plugins](../official-plugins.md)
