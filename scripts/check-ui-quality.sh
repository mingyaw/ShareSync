#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

android_light="android/app/src/main/res/values/colors.xml"
android_dark="android/app/src/main/res/values-night/colors.xml"
ios_en="ios/ShareSyncApp/en.lproj/Localizable.strings"
ios_zh="ios/ShareSyncApp/zh-Hant.lproj/Localizable.strings"

echo "== Android UI resources =="
xmllint --noout \
  "$android_light" \
  "$android_dark" \
  android/app/src/main/res/values/styles.xml \
  android/app/src/main/res/values-night/styles.xml \
  android/app/src/main/res/values/strings.xml \
  android/app/src/main/res/values-zh-rTW/strings.xml

for color_name in \
  sharesync_primary \
  sharesync_success \
  sharesync_warning \
  sharesync_info \
  sharesync_text_primary \
  sharesync_text_secondary \
  sharesync_background \
  sharesync_surface \
  sharesync_divider \
  sharesync_qr_surface; do
  rg -q "<color name=\"${color_name}\">" "$android_light"
  rg -q "<color name=\"${color_name}\">" "$android_dark"
done

if rg -n 'Color\.(rgb|WHITE)' android/app/src/main/java/com/sharesync/android/ui; then
  echo "Android screen contains a hard-coded UI color." >&2
  exit 1
fi

echo "ok Android light/dark resources"

echo
echo "== iOS UI resources =="
plutil -lint "$ios_en" "$ios_zh"

for key in \
  ios.confirm.cancel \
  ios.confirm.reset_history.title \
  ios.confirm.reset_history.message \
  ios.confirm.reset_history.confirm \
  ios.confirm.forget_phone.title \
  ios.confirm.forget_phone.message \
  ios.confirm.forget_phone.confirm \
  ios.feedback.transfer_active \
  ios.tab.receive \
  ios.tab.activity \
  ios.tab.settings \
  ios.settings.support \
  ios.activity.empty_title \
  ios.activity.history_format \
  ios.qr.open_settings; do
  rg -q "\"${key}\"[[:space:]]*=" "$ios_en"
  rg -q "\"${key}\"[[:space:]]*=" "$ios_zh"
done

rg -q 'adaptive\(light:' ios/ShareSyncApp/ShareSyncDesignSystem.swift
rg -q 'ViewThatFits\(in: \.horizontal\)' ios/ShareSyncApp/ShareSyncDesignSystem.swift
rg -q 'FeedbackMessage' ios/ShareSyncApp/ShareSyncDesignSystem.swift
rg -q 'confirmationDialog' ios/ShareSyncApp/ContentView.swift
rg -Fq 'TabView(selection: $selectedTab)' ios/ShareSyncApp/ContentView.swift
rg -q 'Form[[:space:]]*\{' ios/ShareSyncApp/ContentView.swift
rg -q 'SyncHistoryRow' ios/ShareSyncApp/ContentView.swift
rg -q 'UIApplication.openSettingsURLString' ios/ShareSyncApp/QRCodeScannerView.swift
rg -q 'case receive' ios/ShareSyncApp/ContentView.swift
rg -q 'case activity' ios/ShareSyncApp/ContentView.swift
rg -q 'case settings' ios/ShareSyncApp/ContentView.swift

for key in \
  ui_nav_sync \
  ui_nav_activity \
  ui_nav_settings \
  settings_iphone_connected \
  settings_private_transfer; do
  rg -q "name=\"${key}\"" android/app/src/main/res/values/strings.xml
  rg -q "name=\"${key}\"" android/app/src/main/res/values-zh-rTW/strings.xml
done

rg -q 'NavigationBar' android/app/src/main/java/com/sharesync/android/ui/ShareSyncApp.kt
rg -q 'MainDestination.SYNC' android/app/src/main/java/com/sharesync/android/ui/ShareSyncApp.kt
rg -q 'MainDestination.ACTIVITY' android/app/src/main/java/com/sharesync/android/ui/ShareSyncApp.kt
rg -q 'MainDestination.SETTINGS' android/app/src/main/java/com/sharesync/android/ui/ShareSyncApp.kt
rg -q 'ShareSyncComposeTheme' android/app/src/main/java/com/sharesync/android/ui/PhotoSyncHome.kt
rg -q 'peerConnected' android/app/src/main/java/com/sharesync/android/ui/ShareSyncApp.kt

echo "ok adaptive appearance, feedback states, and three-section navigation"
echo
echo "UI quality checks passed."
