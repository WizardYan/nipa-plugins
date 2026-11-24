#!/usr/bin/env bash
set -euo pipefail

ID="${1:?usage: tracula_check_freesurfer_outputs.sh <subject-session> <resolved-subject-dir> [resolved-thalamic-mgz]}"
SUBJECT_DIR="${2:?usage: tracula_check_freesurfer_outputs.sh <subject-session> <resolved-subject-dir> [resolved-thalamic-mgz]}"
THALAMIC_MGZ="${3:-}"

[[ "$SUBJECT_DIR" = /* ]] || { echo "ERROR: resolved FreeSurfer subject directory must be absolute: $SUBJECT_DIR" >&2; exit 1; }
[[ -d "$SUBJECT_DIR" ]] || { echo "ERROR: resolved FreeSurfer subject directory not found: $SUBJECT_DIR" >&2; exit 1; }
[[ "$(basename "$SUBJECT_DIR")" == "$ID" ]] || { echo "ERROR: resolved FreeSurfer subject target mismatch: expected $ID, got $(basename "$SUBJECT_DIR")" >&2; exit 1; }

required=(
    "$SUBJECT_DIR/mri/aparc+aseg.mgz"
    "$SUBJECT_DIR/mri/brain.mgz"
)
for path in "${required[@]}"; do
    [[ -f "$path" ]] || { echo "ERROR: required FreeSurfer output missing: $path" >&2; exit 1; }
done

if [[ -n "$THALAMIC_MGZ" ]]; then
    [[ "$THALAMIC_MGZ" = /* ]] || { echo "ERROR: resolved thalamic segmentation path must be absolute: $THALAMIC_MGZ" >&2; exit 1; }
    [[ -f "$THALAMIC_MGZ" ]] || { echo "ERROR: resolved thalamic-nuclei segmentation missing: $THALAMIC_MGZ" >&2; exit 1; }
    [[ "$(dirname "$THALAMIC_MGZ")" == "$SUBJECT_DIR/mri" ]] || {
        echo "ERROR: resolved thalamic segmentation is not part of the resolved reconstruction: $THALAMIC_MGZ" >&2
        exit 1
    }
    case "$(basename "$THALAMIC_MGZ")" in
        ThalamicNuclei*.mgz) ;;
        *) echo "ERROR: resolved thalamic resource is not a ThalamicNuclei*.mgz file: $THALAMIC_MGZ" >&2; exit 1 ;;
    esac
fi

echo "FreeSurfer prerequisite check: OK"
echo "  Subject: $ID"
echo "  Directory: $SUBJECT_DIR"
if [[ -n "$THALAMIC_MGZ" ]]; then
    echo "  Thalamic nuclei: $THALAMIC_MGZ"
else
    echo "  Thalamic nuclei: not resolved (optional; TRACULA will use usethalnuc=0)"
fi
