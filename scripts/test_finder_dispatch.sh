#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -module-cache-path "$PWD/build/module-cache" -parse-as-library Sources/Core/FileActions.swift Sources/FinderExtension/*.swift Tests/FinderDispatchTests.swift -framework FinderSync -framework AppKit -o build/finder-dispatch-tests
build/finder-dispatch-tests "$@"
