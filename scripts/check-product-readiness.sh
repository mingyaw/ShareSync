#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

android_build="android/app/build.gradle.kts"
android_manifest="android/app/src/main/AndroidManifest.xml"
ios_project="ios/ShareSync.xcodeproj/project.pbxproj"
ios_plist="ios/ShareSyncApp/Info.plist"
ios_icon="ios/ShareSyncApp/Assets.xcassets/AppIcon.appiconset/ShareSyncIcon-1024.png"

echo "== Product identity =="
test -s "$ios_icon"
icon_width=$(sips -g pixelWidth "$ios_icon" | awk '/pixelWidth/ { print $2 }')
icon_height=$(sips -g pixelHeight "$ios_icon" | awk '/pixelHeight/ { print $2 }')
if [[ "$icon_width" != "1024" || "$icon_height" != "1024" ]]; then
  echo "iOS AppIcon must be 1024x1024, found ${icon_width}x${icon_height}." >&2
  exit 1
fi

jq empty ios/ShareSyncApp/Assets.xcassets/Contents.json
jq empty ios/ShareSyncApp/Assets.xcassets/AppIcon.appiconset/Contents.json
plutil -lint "$ios_plist"
xmllint --noout android/app/src/main/res/drawable/ic_launcher_foreground.xml "$android_manifest"
rg -q 'Assets.xcassets in Resources' "$ios_project"
rg -q 'android:icon="@mipmap/ic_launcher"' "$android_manifest"
echo "ok app identity assets"

echo
echo "== First-run and privacy copy =="
for key in \
  m32_onboarding_title \
  m32_onboarding_body \
  m32_onboarding_privacy \
  m32_onboarding_continue \
  m33_privacy_summary \
  m33_privacy_storage; do
  rg -q "name=\"${key}\"" android/app/src/main/res/values/strings.xml
  rg -q "name=\"${key}\"" android/app/src/main/res/values-zh-rTW/strings.xml
done

for key in \
  ios.welcome.title \
  ios.welcome.local \
  ios.welcome.private \
  ios.welcome.foreground \
  ios.welcome.start \
  ios.privacy.title \
  ios.privacy.local_transfer \
  ios.privacy.no_relay \
  ios.privacy.local_history \
  ios.privacy.icloud_note; do
  rg -q "\"${key}\"[[:space:]]*=" ios/ShareSyncApp/en.lproj/Localizable.strings
  rg -q "\"${key}\"[[:space:]]*=" ios/ShareSyncApp/zh-Hant.lproj/Localizable.strings
done
echo "ok bilingual first-run and privacy copy"

echo
echo "== Build channels =="
for channel in debug beta release; do
  rg -q "SHARESYNC_CHANNEL.*${channel}" "$android_build"
  rg -q "SHARESYNC_BUILD_CHANNEL = ${channel};" "$ios_project"
done

rg -q 'applicationIdSuffix = "\.debug"' "$android_build"
rg -q 'applicationIdSuffix = "\.beta"' "$android_build"
rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.sharesync.ios.debug;' "$ios_project"
rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.sharesync.ios.beta;' "$ios_project"
rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.sharesync.ios;' "$ios_project"
rg -q '<string>\$\(SHARESYNC_BUILD_CHANNEL\)</string>' "$ios_plist"
rg -q '<key>UISupportedInterfaceOrientations</key>' "$ios_plist"
rg -q '<key>UISupportedInterfaceOrientations~ipad</key>' "$ios_plist"
if rg -q 'CFBundleDisplayName' ios/ShareSyncApp/en.lproj/InfoPlist.strings ios/ShareSyncApp/zh-Hant.lproj/InfoPlist.strings; then
  echo "Localized InfoPlist strings must not override channel-specific display names." >&2
  exit 1
fi
rg -q 'android:allowBackup="false"' "$android_manifest"
echo "ok Debug, Beta, and Release boundaries"

echo
echo "Product readiness checks passed."
