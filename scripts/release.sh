#!/usr/bin/env bash
# Archive and upload to App Store Connect, signed with the App Store Connect API key (no Xcode account needed).
# Bump CURRENT_PROJECT_VERSION in both targets first (app + widget must match). Never prints the key or issuer ID.
#
# Usage: scripts/release.sh            archive + upload
#        scripts/release.sh --archive  archive only
# Then: swift scripts/asc.swift builds  (wait for VALID)  →  swift scripts/asc.swift attach-build <number>

set -euo pipefail
cd "$(dirname "$0")/.."

key_dir="$HOME/APIkeys/appstoreconnect"
key_path=$(ls "$key_dir"/AuthKey_*.p8 | head -1)
key_id=$(basename "$key_path" .p8); key_id=${key_id#AuthKey_}
issuer=$(grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' "$key_dir"/*ssuer*.rtf | head -1)
[[ -n "$issuer" ]] || { echo "release: no issuer ID found next to the key" >&2; exit 1; }
auth=(-allowProvisioningUpdates -authenticationKeyPath "$key_path" -authenticationKeyID "$key_id" -authenticationKeyIssuerID "$issuer")

archive=/tmp/Fledge.xcarchive
rm -rf "$archive" /tmp/fledge-export
scripts/watchdog.sh --timeout 1800 --idle 600 --name archive -- \
    xcodebuild archive -project TinyHabits.xcodeproj -scheme TinyHabits -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$archive" "${auth[@]}"

[[ "${1:-}" == "--archive" ]] && exit 0

scripts/watchdog.sh --timeout 1800 --idle 900 --name upload -- \
    xcodebuild -exportArchive -archivePath "$archive" -exportPath /tmp/fledge-export \
    -exportOptionsPlist Configuration/ExportOptions-AppStore.plist "${auth[@]}"
