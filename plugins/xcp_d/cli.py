"""Translate NIPA XCP-D parameters into validated native CLI arguments."""
from __future__ import annotations

import json
import re
import sys
from typing import Any

MODES = {"linc", "abcd", "nichart", "none"}
NUISANCE = {"auto", "24P", "27P", "36P", "acompcor", "acompcor_gsr", "aroma", "aroma_gsr", "gsr_only", "none"}
SKIPPABLE = {"alff", "reho", "parcellation", "connectivity"}
SAFE_ATLAS = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.+-]*$")


def _as_number(value: Any, name: str, *, minimum: float | None = None) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() == "auto":
        return None
    try:
        number = float(text)
    except ValueError as exc:
        raise ValueError(f"{name} must be numeric or 'auto'") from exc
    if minimum is not None and number < minimum:
        raise ValueError(f"{name} must be >= {minimum}")
    return text


def build_arguments(params: dict[str, Any]) -> list[str]:
    mode = str(params.get("mode") or "nichart").strip()
    if mode not in MODES:
        raise ValueError(f"Invalid XCP-D mode: {mode}")
    args = ["--mode", mode]

    file_format = str(params.get("file_format") or "auto").strip()
    if file_format not in {"auto", "nifti", "cifti"}:
        raise ValueError(f"Invalid file_format: {file_format}")
    if file_format != "auto":
        args += ["--file-format", file_format]

    nuisance = str(params.get("nuisance_regressors") or "auto").strip()
    if nuisance not in NUISANCE:
        raise ValueError(f"Invalid nuisance_regressors: {nuisance}")
    if nuisance != "auto":
        args += ["--nuisance-regressors", nuisance]

    for key, flag, minimum in (
        ("fd_thresh", "--fd-thresh", 0.0),
        ("min_time", "--min-time", 0.0),
        ("smoothing", "--smoothing", 0.0),
        ("lower_bpf", "--lower-bpf", None),
        ("upper_bpf", "--upper-bpf", None),
    ):
        value = _as_number(params.get(key, "auto"), key, minimum=minimum)
        if value is not None:
            args += [flag, value]

    for key, flag in (("despike", "--despike"), ("combine_runs", "--combine-runs")):
        value = str(params.get(key) or "auto").strip()
        value = {"yes": "y", "no": "n"}.get(value, value)
        if value not in {"auto", "y", "n"}:
            raise ValueError(f"Invalid {key}: {value}")
        if value != "auto":
            args += [flag, value]

    bandpass = str(params.get("bandpass_filter") or "auto").strip()
    if bandpass not in {"auto", "enabled", "disabled"}:
        raise ValueError(f"Invalid bandpass_filter: {bandpass}")
    if bandpass == "disabled":
        args.append("--disable-bandpass-filter")

    atlases = str(params.get("atlases") or "auto").strip()
    if atlases.lower() != "auto":
        values = [x for x in re.split(r"[\s,]+", atlases) if x]
        if any(not SAFE_ATLAS.fullmatch(x) for x in values):
            raise ValueError("Atlas names may contain only letters, numbers, '.', '_', '+', and '-'")
        if values:
            args += ["--atlases", *values]

    skip = str(params.get("skip_outputs") or "").strip()
    if skip:
        values = [x for x in re.split(r"[\s,]+", skip) if x]
        bad = [x for x in values if x not in SKIPPABLE]
        if bad:
            raise ValueError("Invalid XCP-D skip outputs: " + ", ".join(bad))
        args += ["--skip", *values]
    return args


def main() -> int:
    params = json.loads(sys.stdin.read() or "{}")
    try:
        args = build_arguments(params)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    sys.stdout.buffer.write(b"\0".join(x.encode("utf-8") for x in args) + b"\0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
