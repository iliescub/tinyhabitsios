#!/usr/bin/env bash
# Runs a command and kills it when it hangs, so nobody waits on a build that will never finish.
#
# Usage: scripts/watchdog.sh [--timeout SEC] [--idle SEC] [--log FILE] [--name LABEL] -- command [args...]
#   --timeout  hard limit for the whole run (default 900 s)
#   --idle     kill when the command prints nothing for this long (default 240 s; 0 disables)
#   --log      full output goes here (default /tmp/watchdog-<label>-<pid>.log)
#   --name     label for messages and the log name (default: the command's basename)
#
# Exit codes: the command's own code; 124 = hard timeout; 125 = no output for --idle seconds; 2 = usage error.
# On timeout, stall or failure, the last 40 log lines are printed. macOS ships no `timeout`, hence this script.
# Example:
#   scripts/watchdog.sh --timeout 900 --idle 300 --name build -- \
#     xcodebuild -project TinyHabits.xcodeproj -scheme TinyHabits -destination 'platform=iOS Simulator,name=iPhone 17' \
#     -derivedDataPath /tmp/fledge-dd build

set -u

timeout=900
idle=240
log=""
name=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) timeout="$2"; shift 2 ;;
        --idle) idle="$2"; shift 2 ;;
        --log) log="$2"; shift 2 ;;
        --name) name="$2"; shift 2 ;;
        --) shift; break ;;
        *) echo "watchdog: unknown option $1 (put the command after --)" >&2; exit 2 ;;
    esac
done

if [[ $# -eq 0 ]]; then
    echo "usage: scripts/watchdog.sh [--timeout SEC] [--idle SEC] [--log FILE] [--name LABEL] -- command [args...]" >&2
    exit 2
fi

name="${name:-$(basename "$1")}"
log="${log:-/tmp/watchdog-${name}-$$.log}"
: > "$log"

# Job control puts the command in its own process group, so a kill reaches every child
# (xcodebuild spawns swift-frontend, ibtool, simctl…).
set -m
"$@" > "$log" 2>&1 &
pid=$!
set +m

kill_group() {
    kill -TERM -- "-$pid" 2>/dev/null
    for _ in 1 2 3 4 5; do
        kill -0 "$pid" 2>/dev/null || return
        sleep 1
    done
    kill -KILL -- "-$pid" 2>/dev/null
}

trap 'echo "watchdog: interrupted, stopping $name"; kill_group; exit 130' INT TERM

start=$(date +%s)
last_size=0
last_change=$start
reason=""

while kill -0 "$pid" 2>/dev/null; do
    sleep 2
    now=$(date +%s)
    size=$(stat -f %z "$log" 2>/dev/null || echo 0)
    if [[ "$size" != "$last_size" ]]; then
        last_size=$size
        last_change=$now
    fi
    if (( now - start >= timeout )); then
        reason="timeout"
        break
    fi
    if (( idle > 0 && now - last_change >= idle )); then
        reason="stalled"
        break
    fi
done

elapsed=$(( $(date +%s) - start ))

if [[ -n "$reason" ]]; then
    kill_group
    echo "watchdog: $name $([[ $reason == timeout ]] && echo "hit the ${timeout}s limit" || echo "printed nothing for ${idle}s") after ${elapsed}s; killed. Log: $log"
    echo "----- last 40 lines -----"
    tail -n 40 "$log"
    [[ $reason == timeout ]] && exit 124 || exit 125
fi

wait "$pid"
status=$?
if (( status == 0 )); then
    echo "watchdog: $name finished in ${elapsed}s. Log: $log"
    tail -n 5 "$log"
else
    echo "watchdog: $name failed with exit $status after ${elapsed}s. Log: $log"
    echo "----- last 40 lines -----"
    tail -n 40 "$log"
fi
exit "$status"
