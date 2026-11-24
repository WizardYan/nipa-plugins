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
    refs = root / ".nipa_references"
    if not refs.is_dir():
        return {"results": results}
    for ref in sorted(refs.glob("*.path")):
        raw = ref.read_text(encoding="utf-8").strip()
        if not raw:
            continue
        path = Path(raw).expanduser().resolve()
        required = [path / "mri/norm.mgz", path / "mri/wmparc.mgz", path / "mri/transforms/talairach.xfm"]
        if path.is_dir() and all(item.is_file() for item in required):
            subject, session = _entities(ref.stem)
            results.append({"subject": subject, "session": session, "path": str(path), "reference": str(ref.resolve())})
    return {"results": results}


def discover_artifacts(*, root: Path, definition: dict[str, Any], scan_payload: dict[str, Any]) -> Iterable[Artifact]:
    version = (definition.get("plugin") or {}).get("version")
    for record in scan_payload.get("results", []):
        path = Path(record["path"]).resolve()
        subject = str(record["subject"]); session = str(record["session"])
        components = [path / "mri/norm.mgz", path / "mri/wmparc.mgz", path / "mri/transforms/talairach.xfm"]
        key = f"imaging.mri.anatomical.reconstruction|{subject}|{session}|{path}"
        resources = [resource_for_path(path, role="primary", format="surface_reconstruction_dir")]
        resources.extend(resource_for_path(p, role=f"component:{p.name}", format=p.suffix.lstrip(".")) for p in components)
        yield Artifact(
            id="art_" + hashlib.sha256(key.encode()).hexdigest()[:24],
            type="imaging.mri.anatomical.reconstruction",
            entities={"subject": subject, "session": session},
            attributes={"representation": "anatomical_reconstruction", "method": "freesurfer"},
            resources=tuple(resources),
            annotations={"reference_record": record.get("reference")},
            provenance={"generator": {"transformation": "freesurfer", "version": version}},
            origin={"kind": "generated"},
        )
