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
screens="today onboarding-reframe onboarding-plan configure freshstart graduation widgets"
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
    # Same story on iPad; Today already shows the detail beside the nest.
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
# Status bar: simctl shows the weekday a year on, so 2026-02-12 reads "Fri 12 Feb", matching the demo day 2027-02-12.
xcrun simctl status_bar "$device" override --time "$(TZ="$(readlink /etc/localtime | sed "s#.*/zoneinfo/##")" date -j -f "%Y-%m-%dT%H:%M:%S" "2026-02-12T09:41:00" +%s | xargs -I{} date -u -r {} +%Y-%m-%dT%H:%M:%S.000Z)" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

rm -rf "$raw" && mkdir -p "$raw"
rm -f "$out"/[0-9][0-9]-*.png   # the set is renumbered on every run
for screen in $screens; do
    # A resolution in progress in February 2027 (Friday 12 Feb), so the year on screen matches the listing's season.
    args=(-FledgeDemoData -FledgeDemoToday 2027-02-12 -AppleLanguages "(en)" -AppleLocale en_US)
    [[ "$screen" != "today" ]] && args+=(-FledgeDemoScreen "$screen")
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    xcrun simctl launch "$device" "$bundle" "${args[@]}" > /dev/null
    case "$screen" in
        graduation) sleep 9 ;;
        configure) sleep 9 ;;
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
