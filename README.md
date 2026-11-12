# nipa-plugins

Official plugin packages for NIPA (NeuroImaging Processing & Analytics). Find the six `.nipa-plugin.tar.gz` archives under **Assets** on the [v2.3.0 release page](https://github.com/WizardYan/nipa-plugins/releases/tag/v2.3.0).

## Create an fMRIPrep plugin in NIPA

Build a separate draft called `fmriprep_tutorial` around fMRIPrep 25.2.4. You’ll check the package with a bundled example, then test preprocessing on one BIDS subject or session.

1. Download the [fMRIPrep 1.0.0 plugin archive](https://github.com/WizardYan/nipa-plugins/releases/download/v2.3.0/fmriprep-1.0.0.nipa-plugin.tar.gz) and open or extract it with your archive manager. The `fmriprep/` folder contains the reference `plugin.yaml`, `run.sh`, and `adapter.py` used below.
2. In **Plugin Store → Plugin Playground**, click **Create plugin**, enter `fmriprep_tutorial`, select **Apptainer container**, and click **Create source folder**. Keep the generated `example_input.txt`. If Playground is hidden, enable **Show Plugin Playground in Plugin Store** under **Administration → Overview**.
3. Open **Edit draft** and replace the manifest with the reference `plugin.yaml`. Set `plugin.id` to `fmriprep_tutorial`, `plugin.name` to `fMRIPrep Tutorial`, and `implementation.outputs.root` to `derivatives/fmriprep_tutorial`. The distinct ID and output folder let the tutorial coexist with the installed fMRIPrep plugin.
4. Move file discovery onto the matching Artifact output. Update `preprocessed_bold` under `transformation.outputs` as shown.

   ```yaml
   preprocessed_bold:
     type: imaging.mri.functional.bold
     attributes:
       processing_state: preprocessed
     files:
       label: Preprocessed BOLD
       group: Functional
       patterns:
         - "*desc-preproc_bold.nii"
         - "*desc-preproc_bold.nii.gz"
   ```

   Remove its old entry from `implementation.outputs.formats`. Repeat for `bold_reference`, `functional_brain_mask`, `anatomical_brain_mask`, and `preprocessed_t1w`, moving each rule’s label, group, and patterns into `files` on the matching output. Keep these five declarations in the original relative order and retain the remaining discovery rules and adapter reference. NIPA evaluates inline rules before the generic NIfTI fallback.
5. Replace the draft’s `run.sh` with the reference wrapper. The wrapper mounts the BIDS dataset read-only and uses separate output and work directories. Keep the manifest’s pinned container and FreeSurfer license requirements. [fMRIPrep 25.2.4 usage](https://fmriprep.org/en/25.2.4/usage.html)

   In the same editor, enter `adapter.py` in **New file or folder path** and click **New file**. Paste the full reference `adapter.py` into **File contents** and click **Save file**. Look for **File saved.** If `adapter.py` already exists, open it from **Supporting file**. The file lives at the draft root, where `adapter.py:discover_artifacts` expects it.
6. Add this bundled example at the top level of `plugin.yaml`, alongside `implementation`.

   ```yaml
   examples:
     - name: wrapper-smoke-test
       inputs:
         fixture: example_input.txt
       expected_outputs:
         - wrapper-smoke.txt
   ```

   Insert this immediately after `set -euo pipefail` in `run.sh`, before the BIDS, runtime, and license checks.

   ```bash
   case "${NIPA_ATTEMPT_ID:-}" in
     example|conformance)
       cp "${NIPA_INPUT_FIXTURE_PATH:?Missing example fixture}" \
         "${NIPA_OUTPUT_DIR:?Missing output directory}/wrapper-smoke.txt"
       exit 0
       ;;
   esac
   ```

   Click **Save & validate**, then **Run bundled example**. Look for `wrapper-smoke.txt`. This checks that NIPA can start the wrapper, pass it a fixture, and discover the output.
7. Click **Preview store page** and check the Artifact contracts, runtime, and license. Click **Install plugin** to validate and test the package before registering it. Use **View in Plugin Store** to open the installed page. Use **Download package** in Playground if you want a shareable archive.
8. On the installed page, check the fMRIPrep runtime and configure the FreeSurfer license. On Windows, use the WSL2 NIPA instance. In **Data**, select one subject or session with T1w and BOLD scans. Use **Preview inputs from this project** in Playground to check the bindings. In **Analyze → Expert**, select **fMRIPrep Tutorial**, review the workflow, and run it. Follow the job in **Activity**. After it completes, use **Results → Browse Artifacts** to find preprocessed BOLD and confounds, and open the HTML report to review the preprocessing.
