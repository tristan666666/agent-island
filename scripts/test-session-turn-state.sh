#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

swiftc \
    Sources/Trigger/SessionTurnState.swift \
    Tests/SessionScannerStubs.swift \
    Sources/Trigger/SessionScanner.swift \
    Tests/SessionTurnStateTests.swift \
    -o "$tmpdir/session-turn-state-tests"

"$tmpdir/session-turn-state-tests"
