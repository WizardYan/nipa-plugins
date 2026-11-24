from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Iterable

from nipa3.sdk import Artifact, resource_for_path


def _entities(name: str) -> tuple[str, str]:
    if "_ses-" in name:
        subject, suffix = name.split("_ses-", 1)
        return subject, "ses-" + suffix
    return name, "no-session"


def scan_outputs(root: Path) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    refs = root / "references"
    if not refs.is_dir():
        return {"results": results}
    for reference in sorted(refs.glob("*.paths")):
        subject, session = _entities(reference.stem)
        paths = []
        for raw in reference.read_text(encoding="utf-8").splitlines():
            path = Path(raw.strip()).expanduser()
            if path.is_file():
                paths.append(str(path.resolve()))
        if paths:
            results.append({"subject": subject, "session": session, "paths": paths, "reference": str(reference.resolve())})
    return {"results": results}


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    version = (definition.get("plugin") or {}).get("version")
    for record in scan_payload.get("results", []):
        subject = str(record["subject"]); session = str(record["session"])
        paths = [Path(x).resolve() for x in record.get("paths", []) if Path(x).is_file()]
        if not paths:
            continue
        preferred = next((p for p in paths if ".T1." in p.name), paths[0])
        ordered = [preferred] + [p for p in paths if p != preferred]
        resources = [resource_for_path(ordered[0], role="primary", format="mgz")]
        resources.extend(resource_for_path(p, role=f"component:{p.name}", format="mgz") for p in ordered[1:])
        key = f"imaging.mri.anatomical.segmentation|thalamic_nuclei|{subject}|{session}|" + "|".join(str(p) for p in ordered)
        yield Artifact(
            id="art_" + hashlib.sha256(key.encode()).hexdigest()[:24],
            type="imaging.mri.anatomical.segmentation",
            entities={"subject": subject, "session": session},
            attributes={
                "segmentation_type": "structure",
                "structure": "thalamic_nuclei",
                "method": "freesurfer",
            },
            resources=tuple(resources),
            annotations={"reference_record": record.get("reference")},
            provenance={"generator": {"transformation": "thalamic_nuclei", "version": version}},
            origin={"kind": "generated"},
        )
