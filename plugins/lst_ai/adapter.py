"""Expose recognizable LST-AI outputs as producer-neutral NIPA Artifacts.

Unknown NIfTI files remain visible in Results but do not acquire an invented
semantic type. LST-AI's output naming must be rechecked against the pinned SIF.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Iterable

from nipa3.sdk import Artifact, resource_for_path


def _output_kind(name: str) -> tuple[str, dict[str, str]] | None:
    lower = name.lower()
    if not lower.endswith((".nii", ".nii.gz")):
        return None
    if "probability" in lower or "probmap" in lower or "_prob" in lower:
        return "imaging.mri.anatomical.image", {
            "contrast": "lesion_probability", "method": "lst_ai", "space": "FLAIR"
        }
    if "annotated_seg-lst" in lower or "lesion_annotation" in lower:
        return "imaging.mri.anatomical.segmentation", {
            "segmentation_type": "lesion", "method": "lst_ai",
            "representation": "anatomical_annotation", "space": "FLAIR"
        }
    if "seg-lst" in lower or "lesion_mask" in lower or "lesion_seg" in lower:
        return "imaging.mri.anatomical.segmentation", {
            "segmentation_type": "lesion", "method": "lst_ai",
            "representation": "binary_mask", "space": "FLAIR"
        }
    return None


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    """Construct stable artifacts only for recognized output filenames."""
    root = root.resolve()
    version = (definition.get("plugin") or {}).get("version")
    seen: set[str] = set()
    for record in scan_payload.get("results", []):
        subject = str(record.get("subject") or "")
        session = str(record.get("session") or "no-session")
        if not subject.startswith("sub-"):
            continue
        for item in record.get("files", []):
            relative = Path(str(item.get("path") or ""))
            if relative.is_absolute() or ".." in relative.parts:
                continue
            path = (root / relative).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                continue
            kind = _output_kind(path.name)
            if kind is None:
                continue
            artifact_type, attributes = kind
            identity = f"lst_ai|{artifact_type}|{subject}|{session}|{relative.as_posix()}"
            artifact_id = "art_" + hashlib.sha256(identity.encode("utf-8")).hexdigest()[:24]
            if artifact_id in seen:
                continue
            seen.add(artifact_id)
            yield Artifact(
                id=artifact_id,
                type=artifact_type,
                entities={"subject": subject, "session": session},
                attributes=attributes,
                resources=(resource_for_path(
                    path, role="primary", format="nifti",
                    attributes={"relative_path": relative.as_posix(), "size_bytes": item.get("size_bytes")}
                ),),
                annotations={"name": path.name, "group": item.get("group"), "viewer": item.get("viewer")},
                provenance={"generator": {"transformation": "lst_ai", "version": version}},
                origin={"kind": "generated"},
            )
