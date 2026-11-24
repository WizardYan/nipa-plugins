"""CAT12 quality-report parsing belongs to this plugin, not NIPA's reader."""
from pathlib import Path
import re
from xml.etree import ElementTree
import yaml

from nipa3.sdk import scan_configured_outputs

_IQR = re.compile(r'Image\s+Quality\s+Rating\s*\(IQR\)\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*%?\s*(?:\(([^)]+)\))?', re.I)


def quality(path):
    try:
        text=' '.join(value.strip() for value in ElementTree.parse(path).getroot().itertext() if value.strip())
    except (OSError,ElementTree.ParseError):
        try:text=path.read_text(encoding='utf-8',errors='replace')
        except OSError:return None,None,'not-available'
    match=_IQR.search(text)
    if not match:return None,None,'not-available'
    score=float(match.group(1))
    return score,match.group(2),'pass' if score>=70 else 'warning' if score>=50 else 'fail'


def scan_outputs(root):
    manifest=yaml.safe_load(Path(__file__).with_name('plugin.yaml').read_text())
    output=manifest['implementation']['outputs']
    payload=scan_configured_outputs(root,{'id':manifest['plugin']['id'],'output':output})
    for record in payload['results']:
        for file in record['files']:
            if file['format']!='qc_report':continue
            score,grade,status=quality(Path(root)/file['path'])
            if score is not None:
                record['qc']={'iqr':score,'grade':grade,'status':status};break
    payload['summary']['qc']={key:sum(record['qc']['status']==key for record in payload['results'])
                              for key in ('pass','warning','fail','not-available')}
    return payload
