#!/usr/bin/env python3
"""Host-side pyment adapter: only stdlib and NIPA's environment contract."""
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
from pipeline import MODELS


def required(name):
    value=os.environ.get(name)
    if not value:raise ValueError(f'{name} is missing; check the plugin runtime and license setup')
    return value


def settings():
    values=json.loads(os.environ.get('NIPA_PARAMETERS_JSON') or '{}')
    if not isinstance(values,dict) or set(values)-{'model','chronological_age','keep_preprocessing'}:
        raise ValueError('Unsupported pyment parameters')
    model=values.get('model','multi-2025')
    if model not in ('multi-2025','reg-2025'):raise ValueError('Unsupported pyment model')
    age=values.get('chronological_age')
    if age is not None and (isinstance(age,bool) or not isinstance(age,(int,float)) or not math.isfinite(age) or not 0<=age<=120):
        raise ValueError('Chronological age must be a finite number between 0 and 120')
    keep=values.get('keep_preprocessing',True)
    if not isinstance(keep,bool):raise ValueError('Keep preprocessing must be true or false')
    return model,age,keep


def run(subject,session):
    for value in (subject,session,os.environ.get('NIPA_ATTEMPT_ID') or 'manual'):
        if not re.fullmatch(r'[A-Za-z0-9_.-]+',value) or value in ('.','..'):
            raise ValueError('Invalid execution target or attempt label')
    model,age,keep=settings()
    source=Path(required('NIPA_INPUT_T1W_PATH')).resolve(strict=True)
    if not source.is_file() or not source.name.endswith(('.nii','.nii.gz')):raise ValueError('Select one raw .nii or .nii.gz T1w')
    image=Path(required('PYMENT_SIF')).resolve(strict=True)
    license_file=Path(required('FS_LICENSE')).resolve(strict=True)
    if not image.is_file() or not license_file.is_file() or not license_file.stat().st_size:
        raise ValueError('The runtime image or FreeSurfer license file is missing or empty')
    runtime=required('NIPA_CONTAINER_RUNTIME')
    if Path(runtime).name not in ('singularity','apptainer') or not shutil.which(runtime):
        raise ValueError('The configured Singularity/Apptainer executable is unavailable')
    cpus=int(os.environ.get('NIPA_CPUS') or '1')
    if cpus<1:raise ValueError('CPU count must be positive')
    work_root=Path(required('NIPA_EXECUTION_WORK_DIR')).resolve(strict=True)
    output_root=Path(required('NIPA_OUTPUT_DIR')).resolve()
    attempt=os.environ.get('NIPA_ATTEMPT_ID') or 'manual'
    destination=output_root/subject/session/attempt
    if destination.exists():raise ValueError('Outputs already exist for this attempt; start a new attempt')
    with tempfile.TemporaryDirectory(prefix='pyment-',dir=work_root) as temporary:
        work=Path(temporary)
        for name in ('input','tmp','home'):(work/name).mkdir()
        staged=work/'input/sub-input_T1w.nii.gz'
        if source.name.endswith('.gz'):shutil.copyfile(source,staged)
        else:
            with source.open('rb') as original,gzip.open(staged,'wb') as copy:shutil.copyfileobj(original,copy)
        shutil.copyfile(Path(__file__).with_name('pipeline.py'),work/'pipeline.py')
        threads=f'OMP_NUM_THREADS={cpus},OPENBLAS_NUM_THREADS={cpus},TF_NUM_INTRAOP_THREADS={cpus},TF_NUM_INTEROP_THREADS=1,CUDA_VISIBLE_DEVICES=-1'
        command=[runtime,'exec','--cleanenv','--containall','--bind',f'{work}:/work',
                 '--bind',f'{work/"tmp"}:/tmp','--bind',f'{license_file}:/licenses/freesurfer.txt:ro',
                 '--home',f'{work/"home"}:/home/nipa','--pwd','/work','--env',threads,
                 str(image),'python','/work/pipeline.py','--model',model]
        subprocess.run(command,check=True)
        produced=work/'output'
        with (produced/'predictions.csv').open(newline='') as stream:rows=list(csv.DictReader(stream))
        if len(rows)!=1:raise ValueError('pyment must return exactly one prediction for the reviewed input')
        predicted=float(rows[0]['age'])
        if not math.isfinite(predicted):raise ValueError('pyment returned a nonfinite age')
        proof=json.loads((produced/'model.json').read_text())
        if (proof.get('model')!=model or proof.get('pyment_version')!='5.1.0'
                or proof.get('architecture')!=MODELS[model]['architecture']
                or proof.get('upstream_weights_blob')!=MODELS[model]['blob']
                or not re.fullmatch(r'[a-f0-9]{64}',str(proof.get('weights_sha256') or ''))):
            raise ValueError('Output model metadata does not match the selected model/runtime')
        crop=produced/'fastsurfer/sub-input_T1w/mri/crop.mgz'
        if not crop.is_file():raise ValueError('The preprocessed model input crop is missing')
        row={'subject':subject,'session':session,'predicted_age':predicted,'model':model,
             'weights_sha256':proof['weights_sha256'],'chronological_age':age if age is not None else '',
             'brain_PAD':predicted-age if age is not None else ''}
        destination.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.pyment-publish-',dir=destination.parent) as temporary_output:
            publish=Path(temporary_output)
            with (publish/'brainage_desc-pyment_prediction.csv').open('w',newline='') as stream:
                writer=csv.DictWriter(stream,fieldnames=list(row));writer.writeheader();writer.writerow(row)
            shutil.copy2(produced/'predictions.csv',publish/'native_predictions.csv')
            if keep:shutil.copytree(produced/'fastsurfer',publish/'preprocessed')
            proof.update(plugin_version='0.1.0',execution_id=os.environ.get('NIPA_EXECUTION_ID'),
                attempt_id=attempt,input_artifact_id=os.environ.get('NIPA_INPUT_T1W_ARTIFACT_ID'),
                parameters={'model':model,'chronological_age':age,'keep_preprocessing':keep})
            (publish/'execution.json').write_text(json.dumps(proof,indent=2)+'\n')
            publish.rename(destination)
    print(f'pyment results published: {destination}')


if __name__=='__main__':
    try:
        if len(sys.argv)!=3:raise ValueError('Expected subject and session')
        run(*sys.argv[1:])
    except (ValueError,KeyError,OSError,subprocess.CalledProcessError) as exc:
        raise SystemExit(f'pyment failed: {exc}')
