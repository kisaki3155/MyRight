#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/MyRight.app"
EXT="$APP/Contents/PlugIns/MyRightFinder.appex"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Templates" "$EXT/Contents/MacOS" build/module-cache
SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
COMMON=(-sdk "$SDK" -target "${ARCH}-apple-macos13.0" -swift-version 5 -module-cache-path "$PWD/build/module-cache" -O)
xcrun clang -isysroot "$SDK" -mmacosx-version-min=13.0 -c Sources/FinderExtension/main.c -o build/extension-main.o
xcrun swiftc "${COMMON[@]}" -module-name MyRightFinder -application-extension Sources/Core/FileActions.swift Sources/FinderExtension/*.swift build/extension-main.o -framework AppKit -framework FinderSync -o "$EXT/Contents/MacOS/MyRightFinder"
xcrun swiftc "${COMMON[@]}" -parse-as-library -module-name MyRight Sources/Core/*.swift Sources/App/*.swift -framework AppKit -framework SwiftUI -framework FinderSync -framework ServiceManagement -framework ImageIO -o "$APP/Contents/MacOS/MyRight"
cp Config/App-Info.plist "$APP/Contents/Info.plist"
cp Config/Extension-Info.plist "$EXT/Contents/Info.plist"
cp Resources/Templates/Blank.* "$APP/Contents/Resources/Templates/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon-R.icns"
codesign --force --sign "${MYRIGHT_SIGN_IDENTITY:--}" --entitlements Config/Extension.entitlements "$EXT"
codesign --force --sign "${MYRIGHT_SIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"
