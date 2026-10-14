#!/usr/bin/env bash
# App Store screenshots (UX-19, REL-2): full-resolution captures of the demo screens, composed with captions
# into Design/AppStore/NN-<screen>.png at 1320 × 2868 (6.9"). Captions live in Design/AppStore/compose.swift.
# Lock Screen and Siri/Control Center shots (DESIGN.md §9, 1 and 6) need a real device and aren't produced here.
#
# Usage: scripts/appstore-screenshots.sh [--no-build]

set -euo pipefail
cd "$(dirname "$0")/.."

device="iPhone 17"
bundle="com.smartapps.TinyHabits"
app="/tmp/fledge-dd/Build/Products/Debug-iphonesimulator/TinyHabits.app"
raw="/tmp/fledge-appstore-raw"
screens="today detail graduation onboarding-health widgets flown"

if [[ "${1:-}" != "--no-build" ]]; then
    scripts/watchdog.sh --timeout 900 --idle 300 --name build -- \
        xcodebuild -project TinyHabits.xcodeproj -scheme TinyHabits \
        -destination "platform=iOS Simulator,name=$device" -derivedDataPath /tmp/fledge-dd build
fi

scripts/watchdog.sh --timeout 180 --idle 0 --name boot -- bash -c \
    "xcrun simctl boot '$device' 2>/dev/null || true; xcrun simctl bootstatus '$device' -b"
xcrun simctl install "$device" "$app"
xcrun simctl ui "$device" appearance light
xcrun simctl ui "$device" content_size large
xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

rm -rf "$raw" && mkdir -p "$raw"
for screen in $screens; do
    args=(-FledgeDemoData)
    [[ "$screen" != "today" ]] && args+=(-FledgeDemoScreen "$screen")
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    xcrun simctl launch "$device" "$bundle" "${args[@]}" > /dev/null
    case "$screen" in
        graduation) sleep 9 ;;
        today) sleep 6 ;;
        *) sleep 8 ;;
    esac
    xcrun simctl io "$device" screenshot "$raw/$screen.png" > /dev/null 2>&1
    echo "  captured $screen"
done

xcrun simctl status_bar "$device" clear || true
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl shutdown "$device"

scripts/watchdog.sh --timeout 300 --idle 120 --name compose -- swift Design/AppStore/compose.swift "$raw" Design/AppStore
