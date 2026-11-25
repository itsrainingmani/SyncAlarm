#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/syncalarm-clang"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/syncalarm-swift"
swift test --disable-sandbox --scratch-path "${TMPDIR:-/tmp}/syncalarm-tests"
Scripts/check-apps.sh
