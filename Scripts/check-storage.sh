#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp Scripts/StorageChecks.swift "$work/main.swift"
swiftc Sources/Storage.swift "$work/main.swift" -o "$work/check-storage"
"$work/check-storage"
