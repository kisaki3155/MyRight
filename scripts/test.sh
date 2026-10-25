#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -module-cache-path "$PWD/build/module-cache" -parse-as-library Sources/Core/FileActions.swift Tests/FileActionsTests.swift -o build/core-tests
build/core-tests
bash scripts/test_finder_dispatch.sh
