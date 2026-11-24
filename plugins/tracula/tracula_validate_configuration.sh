#!/usr/bin/env bash
set -euo pipefail

ID="${1:?usage: tracula_validate_configuration.sh <subject-session>}"
: "${TRACULA_OUT_ROOT:?TRACULA_OUT_ROOT is not set}"
CONFIG="$TRACULA_OUT_ROOT/config/$ID.dmrirc"

[[ -s "$CONFIG" ]] || { echo "ERROR: TRACULA config missing or empty: $CONFIG" >&2; exit 1; }

grep -Eq "^[[:space:]]*setenv[[:space:]]+SUBJECTS_DIR[[:space:]]+/subjects([[:space:]]|$)" "$CONFIG" || {
    echo "ERROR: config does not use container SUBJECTS_DIR=/subjects" >&2; exit 1;
}
grep -Eq "^[[:space:]]*set[[:space:]]+dtroot[[:space:]]*=[[:space:]]*\(?/tracula\)?" "$CONFIG" || {
    echo "ERROR: config does not use container TRACULA root /tracula" >&2; exit 1;
}
grep -Eq "^[[:space:]]*set[[:space:]]+subjlist[[:space:]]*=[[:space:]]*\([[:space:]]*$ID[[:space:]]*\)" "$CONFIG" || {
    echo "ERROR: config subject list does not match $ID" >&2
    grep -E '^[[:space:]]*set[[:space:]]+subjlist' "$CONFIG" >&2 || true
    exit 1
}
grep -Eq "^[[:space:]]*set[[:space:]]+dcmroot[[:space:]]*=[[:space:]]*\(?/bids\)?" "$CONFIG" || {
    echo "ERROR: config does not use container BIDS root /bids" >&2; exit 1;
}
grep -Eq '^[[:space:]]*set[[:space:]]+dcmlist[[:space:]]*=' "$CONFIG" || { echo "ERROR: dcmlist missing from config" >&2; exit 1; }
grep -Eq '^[[:space:]]*set[[:space:]]+bveclist[[:space:]]*=' "$CONFIG" || { echo "ERROR: bveclist missing from config" >&2; exit 1; }
grep -Eq '^[[:space:]]*set[[:space:]]+bvallist[[:space:]]*=' "$CONFIG" || { echo "ERROR: bvallist missing from config" >&2; exit 1; }

echo "TRACULA configuration validation: OK"
echo "  Config: $CONFIG"
echo "  Subject-session: $ID"
