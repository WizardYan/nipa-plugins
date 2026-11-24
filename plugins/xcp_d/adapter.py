"""Map XCP-D BIDS-style derivatives onto software-neutral NIPA artifacts."""
from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from nipa3.sdk import discover_pattern_artifacts
from nipa3.sdk import Artifact


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    for artifact in discover_pattern_artifacts(root=root, definition=definition, scan_payload=scan_payload):
        payload = artifact.to_dict()
        attributes = dict(payload.get("attributes") or {})
        entities = dict(payload.get("entities") or {})

        # BIDS atlas is an entity parsed by the generic adapter only when the
        # vocabulary knows it. Preserve it semantically for downstream matching.
        path = artifact.local_path()
        name = path.name if path else ""
        if "_atlas-" in name:
            atlas = name.split("_atlas-", 1)[1].split("_", 1)[0]
            attributes.setdefault("atlas", atlas)
        if artifact.type == "imaging.mri.functional.connectivity":
            attributes.setdefault("representation", "matrix")
            attributes.setdefault("measure", "pearson_correlation")
        if artifact.type == "imaging.mri.functional.bold":
            attributes.setdefault("denoised", True)
        if artifact.type in {
            "imaging.mri.functional.bold",
            "imaging.mri.functional.timeseries",
            "imaging.mri.functional.intrinsic_activity",
            "imaging.mri.functional.connectivity",
        }:
            attributes.setdefault("processing_state", "postprocessed")

        payload["attributes"] = attributes
        payload["entities"] = entities
        yield Artifact.from_dict(payload)
