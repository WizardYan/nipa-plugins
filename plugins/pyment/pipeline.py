"""Runs inside the pinned image; no NIPA imports, network weight lookup or Docker CMD."""
import argparse
import hashlib
from importlib.metadata import version
import json
from pathlib import Path
import subprocess

MODELS = {
    'multi-2025': {'architecture': 'sfcn-multi', 'blob': 'c18be19f64b4e398c446d871a7e9d35ec8c88f1d',
                   'targets': ['age','sex','handedness','bmi','fluid_intelligence','neuroticism']},
    'reg-2025': {'architecture': 'sfcn-reg', 'blob': 'a8baaed43082ebac70427a8bf122ffd7c63b51e2', 'targets': ['age']},
}


def weights_identity(path, expected_blob):
    size = path.stat().st_size
    if size == 0:
        raise ValueError('The selected bundled model weights are empty')
    sha256 = hashlib.sha256()
    blob = hashlib.sha1(f'blob {size}\0'.encode())
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(8*1024*1024), b''):
            sha256.update(chunk)
            blob.update(chunk)
    if blob.hexdigest() != expected_blob:
        raise ValueError('Bundled weights do not match the selected upstream model identifier')
    return sha256.hexdigest()


def execute(model, *, work=Path('/work'), weights_root=Path('/.pyment/weights')):
    definition = MODELS[model]
    installed = version('pyment')
    if installed != '5.1.0':
        raise ValueError('Expected pyment 5.1.0 in the configured runtime')
    weights = weights_root / f'{model}.h5'
    # An explicit existing file avoids ensure_weights() downloading a fallback.
    digest = weights_identity(weights, definition['blob'])
    output = work/'output'
    output.mkdir()
    preprocessing = output/'fastsurfer'
    preprocessing.mkdir()
    subprocess.run(['sh','/scripts/preprocess.sh','--license','/licenses/freesurfer.txt',
                    '--python','/envs/fastsurfer/bin/python',str(work/'input/sub-input_T1w.nii.gz'),
                    str(preprocessing)],check=True)
    subprocess.run(['pyment-predict',str(preprocessing),'--format','fastsurfer',
                    '--destination',str(output/'predictions.csv'),'--weights',str(weights),
                    '--model',definition['architecture'],'--targets',*definition['targets']],check=True)
    (output/'model.json').write_text(json.dumps({'pyment_version':installed,'model':model,
        'architecture':definition['architecture'],'weights_sha256':digest,
        'upstream_weights_blob':definition['blob'],'device':'cpu'},indent=2)+'\n')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--model',choices=MODELS,required=True)
    execute(parser.parse_args().model)
