#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -D MYRIGHT_TEST -module-cache-path "$PWD/build/module-cache" -parse-as-library Sources/Core/*.swift Sources/App/*.swift Sources/FinderExtension/HostActionLauncher.swift Tests/BackgroundActionTests.swift -framework AppKit -framework SwiftUI -framework FinderSync -framework ServiceManagement -framework ImageIO -o build/background-action-tests
build/background-action-tests
