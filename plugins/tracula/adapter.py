"""NIPA TRACULA plugin adapter.

NIPA owns artifact/runtime resolution.  The TRACULA plugin owns its validated
native workflow: wrapper preflight -> FreeSurfer validation -> direct artifact-based
configuration -> config validation -> prep/bedp/path.
"""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class TraculaRuntime:
    freesurfer_sif: Path
    fs_license: Path
    fsl_dir: Path
    ants_env: Path


NATIVE_WORKFLOW = (
    "recon-all-version",
    "trac-all-version",
    "check-freesurfer-outputs",
    "auto-configuration",
    "validate-configuration",
    "prep",
    "bedp",
    "path",
)


def validate_runtime(runtime: TraculaRuntime) -> bool:
    checks = {
        "FreeSurfer container": runtime.freesurfer_sif,
        "FreeSurfer license": runtime.fs_license,
        "FSL": runtime.fsl_dir,
        "ANTs": runtime.ants_env,
    }
    missing = [name for name, path in checks.items() if not path.exists()]
    if missing:
        raise RuntimeError("Missing TRACULA runtime: " + ", ".join(missing))
    return True
