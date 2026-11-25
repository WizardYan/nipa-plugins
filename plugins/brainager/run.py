#!/usr/bin/env python3
"""brainageR container adapter. Uses NIPA's environment contract and stdlib only."""
import csv
import gzip
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def required(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f'{name} was not supplied by NIPA. Configure the plugin runtime first.')
    return value


def parameters():
    values = json.loads(os.environ.get('NIPA_PARAMETERS_JSON') or '{}')
    if not isinstance(values, dict) or set(values) - {'chronological_age', 'keep_intermediates'}:
        raise ValueError('Unknown brainageR parameter')
    age = values.get('chronological_age')
    if age is not None and (isinstance(age, bool) or not isinstance(age, (int, float))
                            or not math.isfinite(age) or not 0 <= age <= 120):
        raise ValueError('Chronological age must be a finite number from 0 to 120 years')
    keep = values.get('keep_intermediates', False)
    if not isinstance(keep, bool):
        raise ValueError('Keep segmentation intermediates must be true or false')
    return age, keep


def prediction(path):
    with path.open(newline='') as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 1:
        raise ValueError('brainageR must produce exactly one prediction for the selected image')
    names = ('brain.predicted_age', 'lower.CI', 'upper.CI')
    values = [float(rows[0][name]) for name in names]
    if not all(math.isfinite(value) for value in values) or not values[1] <= values[0] <= values[2]:
        raise ValueError('brainageR returned an invalid prediction or confidence interval')
    return dict(zip(names, values))


def run(subject, session):
    # NIPA also supplies safe project-scope transport labels for standalone files.
    if any(not re.fullmatch(r'[A-Za-z0-9_.-]+', value) or value in {'.', '..'}
           for value in (subject, session)):
        raise ValueError('Invalid execution target label')
    age, keep = parameters()
    source = Path(required('NIPA_INPUT_T1W_PATH')).resolve(strict=True)
    if not source.is_file() or not (source.name.endswith('.nii') or source.name.endswith('.nii.gz')):
        raise ValueError('Select one .nii or .nii.gz raw T1w image')
    image = Path(required('BRAINAGER_SIF')).resolve(strict=True)
    if not image.is_file():
        raise ValueError('brainageR SIF is not a file')
    runtime = required('NIPA_CONTAINER_RUNTIME')
    if Path(runtime).name not in {'singularity', 'apptainer'} or not shutil.which(runtime):
        raise ValueError('The configured Singularity or Apptainer executable is unavailable')
    cpus = int(os.environ.get('NIPA_CPUS') or '1')
    if cpus < 1:
        raise ValueError('CPU count must be positive')
    work_root = Path(required('NIPA_EXECUTION_WORK_DIR')).resolve(strict=True)
    output = Path(required('NIPA_OUTPUT_DIR')).resolve()
    attempt = os.environ.get('NIPA_ATTEMPT_ID') or 'manual'
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', attempt) or attempt in {'.', '..'}:
        raise ValueError('Invalid attempt ID')
    destination = output / subject / session / attempt
    if destination.exists():
        raise ValueError('This attempt already has published outputs; use a new attempt to rerun')
    with tempfile.TemporaryDirectory(prefix='brainager-', dir=work_root) as temporary:
        work = Path(temporary)
        (work / 'tmp').mkdir()
        (work / 'home').mkdir()
        # Upstream normalizes the input header in place. Never bind the source.
        staged = work / 'input.nii'
        opener = gzip.open if source.name.endswith('.gz') else open
        with opener(source, 'rb') as original, staged.open('wb') as copy:
            shutil.copyfileobj(original, copy)
        script = '''set -eu
base=/opt/brainageR/software
for f in brainageR GPR_model_gm_wm_csf.RData pca_center.rds pca_rotation.rds pca_scale.rds templates/average_smwc1.nii templates/average_smwc2.nii templates/average_smwc3.nii; do
  test -s "$base/$f" || { echo "brainageR runtime is incomplete: $base/$f" >&2; exit 2; }
done
command -v octave >/dev/null
command -v Rscript >/dev/null
exec bash "$base/brainageR" "$@"
'''
        command = [runtime, 'exec', '--cleanenv', '--containall',
                   '--bind', f'{work}:/work', '--bind', f'{work / "tmp"}:/tmp',
                   '--home', f'{work / "home"}:/home/nipa', '--pwd', '/work',
                   '--env', f'OMP_NUM_THREADS={cpus},OPENBLAS_NUM_THREADS={cpus},MKL_NUM_THREADS={cpus}',
                   str(image), '/bin/bash', '-c', script, 'brainageR',
                   '-f', '/work/input.nii', '-o', '/work/native_prediction.csv']
        if keep:
            command.append('-d')
        subprocess.run(command, check=True)
        values = prediction(work / 'native_prediction.csv')
        values = {'subject': subject, 'session': session, **values,
                  'chronological_age': age if age is not None else '',
                  'brain_PAD': values['brain.predicted_age'] - age if age is not None else ''}
        # Publish only validated outputs; separate attempt directories retain history.
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.brainager-publish-', dir=destination.parent) as publishing:
            publish = Path(publishing)
            # Target identity is carried by the containing folders and CSV
            # columns; do not duplicate it in the generic output filename.
            name = 'brainage_desc-brainageR_prediction.csv'
            with (publish / name).open('w', newline='') as stream:
                writer = csv.DictWriter(stream, fieldnames=list(values))
                writer.writeheader()
                writer.writerow(values)
            shutil.copy2(work / 'native_prediction.csv', publish / 'native_prediction.csv')
            if (work / 'slicesdir' / 'index.html').is_file():
                shutil.copytree(work / 'slicesdir', publish / 'qc')
            if keep:
                retained = publish / 'intermediates'
                retained.mkdir()
                for path in work.iterdir():
                    if path.is_file() and path != staged and path.suffix in {'.nii', '.gz', '.mat', '.txt'}:
                        shutil.copy2(path, retained / path.name)
            (publish / 'execution.json').write_text(json.dumps({
                'tool': 'brainageR', 'tool_version': '2.1', 'plugin_version': '0.1.1',
                'execution_id': os.environ.get('NIPA_EXECUTION_ID'), 'attempt_id': attempt,
                'input_artifact_id': os.environ.get('NIPA_INPUT_T1W_ARTIFACT_ID'),
                'parameters': {'chronological_age': age, 'keep_intermediates': keep},
            }, indent=2) + '\n')
            # A directory rename publishes the complete result set on this filesystem.
            publish.rename(destination)
    print(f'brainageR results published: {destination}')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('Expected subject and session arguments')
        run(*sys.argv[1:])
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f'brainageR failed: {exc}')
