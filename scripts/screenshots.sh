#!/usr/bin/env bash
# Screenshot harness (UX-4): every demo screen × light/dark × default/AX3 text, plus a contact sheet.
#
# Usage: scripts/screenshots.sh [LABEL] [--no-build] [--keep-booted] [--screens "today detail …"] [--sizes "default ax3"]
#                               [--device "iPad Pro 13-inch (M5)"]
#   LABEL         output folder name under Design/review/screens/ (default: the short git commit)
#   --no-build    reuse the last build in /tmp/fledge-dd
#   --keep-booted leave the simulator running afterwards (default: shut it down)
# Output: Design/review/screens/LABEL/<screen>-<light|dark>-<default|ax3>.jpg (half size) and index.html.
# Builds and boots go through scripts/watchdog.sh, so a hung step fails instead of blocking.

set -euo pipefail
cd "$(dirname "$0")/.."

label=""
build=1
keep=0
screens="today detail add configure flown settings paywall onboarding onboarding-pick onboarding-health onboarding-headstart onboarding-reminders graduation sharecard widgets"
sizes="default ax3"
device="iPhone 17"
bundle="com.smartapps.TinyHabits"
app="/tmp/fledge-dd/Build/Products/Debug-iphonesimulator/TinyHabits.app"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build) build=0; shift ;;
        --keep-booted) keep=1; shift ;;
        --screens) screens="$2"; shift 2 ;;
        --sizes) sizes="$2"; shift 2 ;;
        --device) device="$2"; shift 2 ;;
        -*) echo "unknown option $1" >&2; exit 2 ;;
        *) label="$1"; shift ;;
    esac
done
label="${label:-$(git rev-parse --short HEAD)}"
out="Design/review/screens/$label"
mkdir -p "$out"

if (( build )); then
    scripts/watchdog.sh --timeout 900 --idle 300 --name build -- \
        xcodebuild -project TinyHabits.xcodeproj -scheme TinyHabits \
        -destination "platform=iOS Simulator,name=$device" -derivedDataPath /tmp/fledge-dd build
fi

scripts/watchdog.sh --timeout 180 --idle 0 --name boot -- bash -c \
    "xcrun simctl boot '$device' 2>/dev/null || true; xcrun simctl bootstatus '$device' -b"
xcrun simctl install "$device" "$app"
xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null || true

content_size() {
    case "$1" in
        ax3) echo "accessibility-extra-large" ;;
        ax5) echo "accessibility-extra-extra-extra-large" ;;
        *) echo "large" ;;
    esac
}

shoot() {  # screen appearance size
    local screen=$1 appearance=$2 size=$3
    local args=(-FledgeDemoData)
    [[ "$screen" != "today" ]] && args+=(-FledgeDemoScreen "$screen")
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    xcrun simctl launch "$device" "$bundle" "${args[@]}" > /dev/null
    # A cold launch takes ~3 s; sheets open 0.7 s after Today appears; onboarding and graduation then animate
    # (ring fills, then the bird). Wait for each screen's end state.
    case "$screen" in
        onboarding|graduation) sleep 9 ;;
        configure|onboarding-*) sleep 7 ;;
        today) sleep 5 ;;
        *) sleep 6 ;;
    esac
    local png="$out/.tmp.png"
    xcrun simctl io "$device" screenshot "$png" > /dev/null 2>&1
    sips -s format jpeg -s formatOptions 80 -Z 1300 "$png" --out "$out/$screen-$appearance-$size.jpg" > /dev/null
    rm -f "$png"
    echo "  $screen-$appearance-$size"
}

for appearance in light dark; do
    xcrun simctl ui "$device" appearance "$appearance"
    for size in $sizes; do
        xcrun simctl ui "$device" content_size "$(content_size "$size")"
        for screen in $screens; do
            shoot "$screen" "$appearance" "$size"
        done
    done
done

# Leave the simulator as we found it.
xcrun simctl ui "$device" appearance light
xcrun simctl ui "$device" content_size large
xcrun simctl status_bar "$device" clear 2>/dev/null || true
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
(( keep )) || xcrun simctl shutdown "$device"

# Contact sheet: one row per screen, one column per variant.
{
    echo "<!doctype html><meta charset=utf-8><title>Fledge screens · $label</title>"
    echo "<style>body{font:14px -apple-system,system-ui;background:#eee;margin:20px}h1{font-size:20px}"
    echo "table{border-collapse:collapse}td,th{padding:6px;vertical-align:top;text-align:center}img{width:200px;border-radius:18px;display:block}</style>"
    echo "<h1>Fledge screens · $label · $(date '+%Y-%m-%d %H:%M')</h1><table><tr><th></th>"
    for appearance in light dark; do for size in $sizes; do echo "<th>$appearance · $size</th>"; done; done
    echo "</tr>"
    for screen in $screens; do
        echo "<tr><th>$screen</th>"
        for appearance in light dark; do for size in $sizes; do
            echo "<td><img src=\"$screen-$appearance-$size.jpg\" alt=\"$screen $appearance $size\"></td>"
        done; done
        echo "</tr>"
    done
    echo "</table>"
} > "$out/index.html"

echo "screenshots: $(ls "$out"/*.jpg | wc -l | tr -d ' ') images in $out (open $out/index.html)"
