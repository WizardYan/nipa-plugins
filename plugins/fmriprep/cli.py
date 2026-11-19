"""Convert NIPA parameters to individual fMRIPrep CLI arguments."""

import json
import os
import re
import sys


def boolean(parameters, name):
    value = parameters.get(name, False)
    if not isinstance(value, bool):
        raise ValueError(f"{name} must be a boolean.")
    return value


def text(parameters, name, default=""):
    value = parameters.get(name, default)
    if not isinstance(value, str) or any(c in value for c in "\x00\n\r"):
        raise ValueError(f"{name} must be a single line of text.")
    return value.strip()


def reference(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*(?::[A-Za-z0-9_.-]+)*", value):
        raise ValueError(f"Invalid spatial reference: {value}")


def arguments(parameters):
    if not isinstance(parameters, dict):
        raise ValueError("Expected a JSON object.")
    args = []
    ignored = text(parameters, "ignore").split()
    allowed = {"fieldmaps", "slicetiming", "sbref", "t2w", "flair", "fmap-jacobian"}
    if set(ignored) - allowed:
        raise ValueError("Invalid --ignore choice.")
    if ignored:
        args.extend(["--ignore", *ignored])

    spaces = text(parameters, "output_spaces").split()
    for space in spaces:
        reference(space)
    if spaces:
        args.extend(["--output-spaces", *spaces])

    no_recon = boolean(parameters, "fs_no_reconall")
    if no_recon and parameters.get("cifti_output", "off") != "off":
        raise ValueError("CIFTI output requires FreeSurfer reconstruction.")
    for name in ("skull_strip_fixed_seed", "fs_no_reconall"):
        if boolean(parameters, name):
            args.append("--" + name.replace("_", "-"))

    choices = (
        ("bold2anat_dof", "6", ("6", "9", "12")),
        ("cifti_output", "off", ("off", "91k", "170k")),
        ("skull_strip_t1w", "force", ("auto", "skip", "force")),
    )
    for name, default, allowed in choices:
        value = parameters.get(name, default)
        if value not in allowed:
            raise ValueError(f"Invalid {name} selection.")
        if value != default:
            args.extend(["--" + name.replace("_", "-"), value])

    template = text(parameters, "skull_strip_template", "OASIS30ANTs")
    reference(template)
    if template != "OASIS30ANTs":
        args.extend(["--skull-strip-template", template])

    thresholds = (
        ("slice_time_ref", "--slice-time-ref", 0.5, 1),
        ("fd_spike_threshold", "--fd-spike-threshold", 0.5, None),
        ("dvars_spike_threshold", "--dvars-spike-threshold", 1.5, None),
    )
    for name, flag, default, maximum in thresholds:
        value = parameters.get(name, default)
        if (type(value) not in (int, float) or not 0 <= value <= (maximum or sys.float_info.max)):
            raise ValueError(f"{name} must be a finite number in the allowed range.")
        if value != default:
            args.extend([flag, str(value)])
    return args


if __name__ == "__main__":
    try:
        parameters = json.loads(os.environ.get("NIPA_PARAMETERS_JSON") or "{}")
        args = arguments(parameters)
        paths = [text(parameters, name) for name in ("fs_license_file", "fs_subjects_dir")]
        for path in paths:
            if path and (not path.startswith("/") or any(c in path for c in ":,")):
                raise ValueError("FreeSurfer paths must be absolute Linux paths without colons or commas.")
    except ValueError as exc:
        sys.exit(f"Invalid fMRIPrep parameters: {exc}")
    print("\n".join([*paths, *args, "end"]))
