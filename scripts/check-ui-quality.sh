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

if rg -n 'Color\.(rgb|WHITE)' android/app/src/main/java/com/sharesync/android/MainActivity.kt; then
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
  ios.settings.support; do
  rg -q "\"${key}\"[[:space:]]*=" "$ios_en"
  rg -q "\"${key}\"[[:space:]]*=" "$ios_zh"
done

rg -q 'adaptive\(light:' ios/ShareSyncApp/ContentView.swift
rg -q 'ViewThatFits\(in: \.horizontal\)' ios/ShareSyncApp/ContentView.swift
rg -q 'FeedbackMessage' ios/ShareSyncApp/ContentView.swift
rg -q 'confirmationDialog' ios/ShareSyncApp/ContentView.swift
rg -Fq 'TabView(selection: $selectedTab)' ios/ShareSyncApp/ContentView.swift
rg -q 'case receive' ios/ShareSyncApp/ContentView.swift
rg -q 'case activity' ios/ShareSyncApp/ContentView.swift
rg -q 'case settings' ios/ShareSyncApp/ContentView.swift

for key in \
  m36_nav_sync \
  m36_nav_activity \
  m36_nav_settings; do
  rg -q "name=\"${key}\"" android/app/src/main/res/values/strings.xml
  rg -q "name=\"${key}\"" android/app/src/main/res/values-zh-rTW/strings.xml
done

rg -q 'private fun bottomNavigation' android/app/src/main/java/com/sharesync/android/MainActivity.kt
rg -q 'MainSection.SYNC' android/app/src/main/java/com/sharesync/android/MainActivity.kt
rg -q 'MainSection.ACTIVITY' android/app/src/main/java/com/sharesync/android/MainActivity.kt
rg -q 'MainSection.SETTINGS' android/app/src/main/java/com/sharesync/android/MainActivity.kt

echo "ok adaptive appearance, feedback states, and three-section navigation"
echo
echo "UI quality checks passed."
