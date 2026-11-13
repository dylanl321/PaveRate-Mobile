#!/usr/bin/env bash
# Archive PaveRate and upload it to App Store Connect / TestFlight.
# Run on a Mac with Xcode 15+ signed in to the Apple ID that owns the team
# (Xcode > Settings > Accounts), or pass an App Store Connect API key.
#
#   TEAM_ID=ABCDE12345 scripts/testflight.sh
#   TEAM_ID=... ASC_KEY_PATH=~/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX ASC_ISSUER_ID=uuid scripts/testflight.sh
#
# Bump the build first if this number was already uploaded:
#   BUMP=1 TEAM_ID=... scripts/testflight.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${TEAM_ID:?Set TEAM_ID to your 10-character Apple Developer Team ID}"
BUILD_DIR="${BUILD_DIR:-build}"
ARCHIVE="$BUILD_DIR/PaveRate.xcarchive"

if [[ "${BUMP:-0}" == "1" ]]; then
  current=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);.*/\1/p' PaveRate.xcodeproj/project.pbxproj | head -1)
  next=$((current + 1))
  sed -i '' "s/CURRENT_PROJECT_VERSION = $current;/CURRENT_PROJECT_VERSION = $next;/g" PaveRate.xcodeproj/project.pbxproj
  echo "Build number $current -> $next"
fi

auth=()
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
  auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

rm -rf "$ARCHIVE"
xcodebuild archive \
  -project PaveRate.xcodeproj \
  -scheme PaveRate \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates ${auth[@]+"${auth[@]}"} \
  DEVELOPMENT_TEAM="$TEAM_ID"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$BUILD_DIR/export" \
  -allowProvisioningUpdates ${auth[@]+"${auth[@]}"}

echo "Uploaded. The build appears in App Store Connect > TestFlight after processing (usually 5 to 30 minutes)."
