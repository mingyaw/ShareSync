#!/usr/bin/env bash
set -euo pipefail

echo "== Git author =="
git config user.name
git config user.email

echo
echo "== Sensitive identity scan =="
sensitive_identity_pattern='hansli@chai''lease|chai''lease'
if rg -n "$sensitive_identity_pattern" -S .; then
  echo "Found private identity markers."
  exit 1
fi
echo "ok sensitive identity scan"

echo
echo "== Local machine path scan =="
local_machine_path_pattern='/Users/''mingyao|Library/Developer/''Xcode'
if rg -n "$local_machine_path_pattern" -S \
  README.md docs tasks scripts android ios shared Package.swift .gitignore; then
  echo "Found local machine path markers."
  exit 1
fi
echo "ok local machine path scan"

echo
echo "== Generated artifact scan =="
if git ls-files | rg -n '(^|/)(build|DerivedData|\.gradle|\.build|xcuserdata)(/|$)|\.(apk|aab|ipa|dSYM|mobileprovision|provisionprofile|p8|p12)$'; then
  echo "Found generated or signing artifacts tracked by Git."
  exit 1
fi
echo "ok generated artifact scan"

echo
echo "Repo hygiene checks passed."
