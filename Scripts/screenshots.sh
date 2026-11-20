#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# App Store screenshots from the simulator, in every language, with demo data in a throwaway
# store (--scratch-store). The app's clock is moved to CLOCK (default 10:30) with Scripts/faketime.c,
# so the demo doses sit around the middle of the day at any hour. Needs a Debug simulator build and notifications already allowed on
# each simulator (run NotificationPermissionUITests on a fresh install once), otherwise Today
# shows the "Reminders are off" warning.
#
#   [CLOCK=HH:MM] Scripts/screenshots.sh <path to Vzato.app for the simulator> <output folder> <udid>...
set -e
APP="$1"; OUT="$2"; shift 2
LANGS="cs sk en hu"
CLOCK="${CLOCK:-10:30}"
FAKETIME="${TMPDIR:-/tmp}/vzato-faketime.dylib"
xcrun -sdk iphonesimulator clang -target arm64-apple-ios17.0-simulator -dynamiclib \
    -o "$FAKETIME" "$(dirname "$0")/faketime.c"
codesign -s - -f "$FAKETIME" 2>/dev/null
# Seconds from now to HH:MM today.
offset_to() { echo $(( $(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) $1:00" +%s) - $(date +%s) )); }

locale_for() {
    case "$1" in cs) echo cs_CZ ;; sk) echo sk_SK ;; en) echo en_GB ;; hu) echo hu_HU ;; esac
}

for UDID in "$@"; do
    NAME=$(xcrun simctl list devices | grep "$UDID" | sed -E 's/^ *(.*) \(.*/\1/' | tr ' ' '-')
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" >/dev/null
    xcrun simctl install "$UDID" "$APP"
    xcrun simctl status_bar "$UDID" override --time "$CLOCK" --batteryState charged \
        --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
    for LANG in $LANGS; do
        DIR="$OUT/$NAME/$LANG"; mkdir -p "$DIR"
        # shot <file> <HH:MM> <launch arguments>...
        shot() {
            FILE="$1"; AT="$2"; shift 2
            xcrun simctl status_bar "$UDID" override --time "$AT" 2>/dev/null || true
            xcrun simctl terminate "$UDID" app.vzato 2>/dev/null || true
            SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$FAKETIME" SIMCTL_CHILD_FAKE_OFFSET="$(offset_to "$AT")" \
                xcrun simctl launch "$UDID" app.vzato --scratch-store --sample-data --no-onboarding "$@" \
                -AppleLanguages "($LANG)" -AppleLocale "$(locale_for "$LANG")" >/dev/null
            sleep 6
            xcrun simctl io "$UDID" screenshot "$DIR/$FILE.png" >/dev/null 2>&1
        }
        # The organizer card shows the morning compartment best at 9:00.
        shot 01-today "$CLOCK" --sample-profiles --tab today
        shot 02-organizer 09:00 --sample-organizer --tab today
        shot 03-profiles "$CLOCK" --sample-profiles --tab settings --open-profiles
        shot 04-database "$CLOCK" --tab medications --search ibal
        shot 05-medications "$CLOCK" --sample-profiles --tab medications
        shot 06-fill "$CLOCK" --sample-organizer --tab settings --fill-organizer
        shot 07-history "$CLOCK" --sample-profiles --tab history
        echo "$NAME $LANG done"
    done
    xcrun simctl terminate "$UDID" app.vzato 2>/dev/null || true
    xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
done
