#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

swiftc \
    Sources/Usage/AppUsage.swift \
    Sources/Usage/UsageCachePolicy.swift \
    Tests/UsageCachePolicyTests.swift \
    -o "$tmpdir/usage-cache-policy-tests"

"$tmpdir/usage-cache-policy-tests"
