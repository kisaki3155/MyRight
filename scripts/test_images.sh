#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -module-cache-path "$PWD/build/module-cache" -parse-as-library Sources/Core/*.swift Tests/ImageConversionTests.swift -framework ImageIO -o build/image-conversion-tests
build/image-conversion-tests
xcrun swiftc -module-cache-path "$PWD/build/module-cache" -parse-as-library Sources/App/PathCopier.swift Tests/PathCopyTests.swift -framework AppKit -o build/path-copy-tests
build/path-copy-tests
