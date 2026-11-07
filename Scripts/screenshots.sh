#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# App Store screenshots from the simulator, in every language, with demo data in a throwaway
# store (--scratch-store). Needs a Debug simulator build and notifications already allowed on
# each simulator (run NotificationPermissionUITests on a fresh install once), otherwise Today
# shows the "Reminders are off" warning.
#
#   Scripts/screenshots.sh <path to Vzato.app for the simulator> <output folder> <udid>...
set -e
APP="$1"; OUT="$2"; shift 2
LANGS="cs sk en hu"

locale_for() {
    case "$1" in cs) echo cs_CZ ;; sk) echo sk_SK ;; en) echo en_GB ;; hu) echo hu_HU ;; esac
}

for UDID in "$@"; do
    NAME=$(xcrun simctl list devices | grep "$UDID" | sed -E 's/^ *(.*) \(.*/\1/' | tr ' ' '-')
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" >/dev/null
    xcrun simctl install "$UDID" "$APP"
    xcrun simctl status_bar "$UDID" override --time "$(date +%H:%M)" --batteryState charged \
        --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
    for LANG in $LANGS; do
        DIR="$OUT/$NAME/$LANG"; mkdir -p "$DIR"
        shot() {
            FILE="$1"; shift
            xcrun simctl terminate "$UDID" app.vzato 2>/dev/null || true
            xcrun simctl launch "$UDID" app.vzato --scratch-store --sample-data "$@" \
                -AppleLanguages "($LANG)" -AppleLocale "$(locale_for "$LANG")" >/dev/null
            sleep 6
            xcrun simctl io "$UDID" screenshot "$DIR/$FILE.png" >/dev/null 2>&1
        }
        shot 01-today --no-onboarding --tab today
        shot 02-medications --no-onboarding --tab medications
        shot 03-history --no-onboarding --tab history
        shot 04-guide --onboarding
        echo "$NAME $LANG done"
    done
    xcrun simctl terminate "$UDID" app.vzato 2>/dev/null || true
    xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
done
