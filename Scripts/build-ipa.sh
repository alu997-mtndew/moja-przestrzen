#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
version=${1:-0.1.0}
build_number=${2:-1}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $build_number =~ ^[1-9][0-9]*$ ]]

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p dist "$work/ipa/Payload"

xcodebuild -project MojaPrzestrzen.xcodeproj -scheme MojaPrzestrzen \
    -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath "$work/DerivedData" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" build

app="$work/DerivedData/Build/Products/Release-iphoneos/MojaPrzestrzen.app"
plist="$app/Info.plist"
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
test "$(read_plist CFBundleIdentifier)" = pl.dawidp.mojaprzestrzen
test "$(read_plist CFBundleShortVersionString)" = "$version"
test "$(read_plist CFBundleVersion)" = "$build_number"
test "$(read_plist CFBundleSupportedPlatforms:0)" = iPhoneOS
test "$(xcrun lipo -archs "$app/$(read_plist CFBundleExecutable)")" = arm64
test ! -e "$app/_CodeSignature"
test ! -e "$app/embedded.mobileprovision"

ditto "$app" "$work/ipa/Payload/MojaPrzestrzen.app"
(cd "$work/ipa" && /usr/bin/zip -qry "$work/MojaPrzestrzen.ipa" Payload)
unzip -t "$work/MojaPrzestrzen.ipa"
mv "$work/MojaPrzestrzen.ipa" "dist/MojaPrzestrzen-$version.ipa"
