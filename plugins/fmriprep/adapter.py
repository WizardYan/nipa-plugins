"""Translate fMRIPrep/FreeSurfer-native outputs into NIPA semantic artifacts."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any, Iterable

from nipa.artifacts.adapters.patterns import discover_pattern_artifacts
from nipa.artifacts.model import Artifact, resource_for_path

_FS_ENTITY_RE = re.compile(r"^(sub-[A-Za-z0-9]+)(?:_(ses-[A-Za-z0-9]+))?$")


def _virtual_id(kind: str, path: Path, subject: str | None = None, session: str | None = None) -> str:
    identity = f"{kind}|{path.resolve()}|{subject or ''}|{session or ''}"
    return "art_" + hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]


def _scan_targets(scan_payload: dict[str, Any]) -> list[tuple[str, str]]:
    """Return target identities represented by the current fMRIPrep output scan."""
    values: list[tuple[str, str]] = []
    for record in scan_payload.get("results", []):
        subject = str(record.get("subject") or "").strip()
        session = str(record.get("session") or "").strip() or "no-session"
        if subject.startswith("sub-") and subject != "unknown-subject":
            pair = (subject, session)
            if pair not in values:
                values.append(pair)
    return values


def _discover_derivatives_dataset(root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    """Publish target-scoped semantic views over one BIDS Derivatives dataset root.

    XCP-D natively consumes a derivatives dataset directory rather than isolated BOLD
    files.  The same physical root is therefore represented once per target so the
    current target-scoped NIPA resolver can bind it without encoding an fMRIPrep path
    in the downstream plugin.
    """
    description = root / "dataset_description.json"
    if not description.is_file():
        return
    try:
        dataset_description = json.loads(description.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        dataset_description = {}
    version = (definition.get("plugin") or {}).get("version")
    for subject, session in _scan_targets(scan_payload):
        yield Artifact(
            id=_virtual_id("dataset.derivatives.bids", root, subject, session),
            type="dataset.derivatives.bids",
            entities={"subject": subject, "session": session},
            attributes={
                **({"bids_version": str(dataset_description["BIDSVersion"])} if dataset_description.get("BIDSVersion") else {}),
                "standard": "BIDS",
                "dataset_type": "derivative",
                "processing_state": "preprocessed",
                "pipeline_name": "fmriprep",
                "pipeline_version": str(version or ""),
            },
            annotations={"virtual": True, "dataset_description": str(description.resolve()), "native_layout": "fmriprep"},
            resources=(resource_for_path(root, role="primary", format="bids_derivatives_directory"),),
            provenance={"generator": {"transformation": "fmriprep", "version": version}},
            origin={"kind": "generated"},
        )


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    yield from discover_pattern_artifacts(root=root, definition=definition, scan_payload=scan_payload)
    yield from _discover_derivatives_dataset(root, definition, scan_payload)

    fs_root = root / "sourcedata" / "freesurfer"
    if not fs_root.is_dir():
        return
    required = ("mri/norm.mgz", "mri/wmparc.mgz", "mri/transforms/talairach.xfm")
    for subject_dir in sorted(fs_root.iterdir()):
        if not subject_dir.is_dir():
            continue
        match = _FS_ENTITY_RE.match(subject_dir.name)
        if not match:
            continue
        components = [subject_dir / rel for rel in required]
        if not all(item.is_file() for item in components):
            continue
        subject = match.group(1)
        session = match.group(2) or "no-session"
        yield Artifact(
            id=_virtual_id("imaging.mri.anatomical.reconstruction", subject_dir),
            type="imaging.mri.anatomical.reconstruction",
            entities={"subject": subject, "session": session},
            attributes={"representation": "anatomical_reconstruction", "method": "freesurfer"},
            annotations={"components": [str(item.resolve()) for item in components], "virtual": True},
            resources=tuple([resource_for_path(subject_dir, role="primary", format="surface_reconstruction_dir")] + [resource_for_path(item, role=f"component:{item.name}", format=item.suffix.lstrip(".")) for item in components]),
            provenance={"generator": {"transformation": "fmriprep", "version": (definition.get("plugin") or {}).get("version")}},
            origin={"kind": "generated"},
        )
