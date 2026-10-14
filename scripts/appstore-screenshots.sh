#!/usr/bin/env bash
# App Store screenshots (UX-19, REL-2): full-resolution captures of the demo screens, composed with captions
# into Design/AppStore/NN-<screen>.png at 1320 × 2868 (6.9"). Captions live in Design/AppStore/compose.swift.
# Lock Screen and Siri/Control Center shots (DESIGN.md §9, 1 and 6) need a real device and aren't produced here.
#
# Usage: scripts/appstore-screenshots.sh [--no-build] [--ipad]
#   --ipad: the 13" iPad set (2064 × 2752) into Design/AppStore/iPad, required for an app that runs natively on iPad.

set -euo pipefail
cd "$(dirname "$0")/.."

device="iPhone 17"
bundle="com.smartapps.TinyHabits"
app="/tmp/fledge-dd/Build/Products/Debug-iphonesimulator/TinyHabits.app"
raw="/tmp/fledge-appstore-raw"
screens="today detail graduation onboarding-health widgets flown"
build=1
ipad=0
for arg in "$@"; do
    case "$arg" in
        --no-build) build=0 ;;
        --ipad) ipad=1 ;;
    esac
done
out="Design/AppStore"
if (( ipad )); then
    device="iPad Pro 13-inch (M5)"
    raw="/tmp/fledge-appstore-raw-ipad"
    out="Design/AppStore/iPad"
    # On iPad the detail sits beside the nest, so Today already shows it; use the Add sheet instead.
    screens="today add graduation onboarding-health widgets flown"
fi
mkdir -p "$out"

if (( build )); then
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

scripts/watchdog.sh --timeout 300 --idle 120 --name compose -- \
    swift Design/AppStore/compose.swift "$raw" "$out" $( (( ipad )) && echo --ipad )
