#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Mac App Store screenshots (2880 × 1800; a 1120 × 700 window scaled up, so the text is readable) of a Debug build, with demo data in a throwaway store
# (--scratch-store), so the data of an installed Vzato on this Mac is not touched. Quits a
# running Vzato first. Needs Screen Recording permission for the terminal. The app's clock is moved
# to CLOCK (default 10:30) with Scripts/faketime.c, as for the simulator.
#
#   [CLOCK=HH:MM] Scripts/screenshots-mac.sh <path to Vzato.app for macOS> <output folder>
set -e
APP="$1"; OUT="$2"
CLOCK="${CLOCK:-10:30}"
FAKETIME="${TMPDIR:-/tmp}/vzato-faketime-mac.dylib"
clang -dynamiclib -o "$FAKETIME" "$(dirname "$0")/faketime.c"
codesign -s - -f "$FAKETIME" 2>/dev/null
offset_to() { echo $(( $(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) $1:00" +%s) - $(date +%s) )); }
WINID="${TMPDIR:-/tmp}/vzato-winid"
cat > "$WINID.swift" <<'SWIFT'
import CoreGraphics
import Foundation
// Prints the window number of Vzato's largest normal window.
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var best: (Int, String)?
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Vzato" && (w[kCGWindowLayer as String] as? Int) == 0 {
    guard let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
    let width = (b["Width"] as? NSNumber)?.intValue ?? 0
    let number = (w[kCGWindowNumber as String] as? NSNumber)?.intValue ?? 0
    if width > (best?.0 ?? 0) { best = (width, String(number)) }
}
if let best { print(best.1) }
SWIFT
swiftc -O -o "$WINID" "$WINID.swift"

for LANG in cs sk en hu; do
    case "$LANG" in cs) LOC=cs_CZ ;; sk) LOC=sk_SK ;; en) LOC=en_GB ;; hu) LOC=hu_HU ;; esac
    DIR="$OUT/$LANG"; mkdir -p "$DIR"
    # shot <file> <HH:MM> <launch arguments>...
    shot() {
        FILE="$1"; AT="$2"; shift 2
        osascript -e 'if application id "app.vzato" is running then tell application id "app.vzato" to quit' >/dev/null 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "Vzato.app/Contents/MacOS/Vzato" >/dev/null || break; sleep 1; done
        pkill -f "Vzato.app/Contents/MacOS/Vzato" 2>/dev/null && sleep 2 || true
        # AppKit reads "-key value" pairs from the command line; a lone value left over is taken
        # as a file to open, and the app then opens no window. So pairs first, plain flags last.
        open -n -a "$APP" --env DYLD_INSERT_LIBRARIES="$FAKETIME" --env FAKE_OFFSET="$(offset_to "$AT")" \
            --args --window-size 1120x700 -AppleLanguages "($LANG)" -AppleLocale "$LOC" \
            "$@" --sample-data --no-onboarding --scratch-store
        WIN=""
        for _ in $(seq 1 25); do sleep 1; WIN=$("$WINID"); [ -n "$WIN" ] && break; done
        [ -n "$WIN" ] || { echo "no window for $LANG $FILE"; return 1; }
        sleep 3   # let the content settle
        # Capture the window itself (-l), not a screen area: other windows may lie on top of it.
        screencapture -x -o -l"$WIN" "$DIR/$FILE.png"
        sips -z 1800 2880 "$DIR/$FILE.png" >/dev/null
    }
    # Pairs (--tab x, --search x) before the plain flags.
    shot 01-today "$CLOCK" --tab today --sample-profiles
    shot 02-organizer 09:00 --tab today --sample-organizer
    shot 03-profiles "$CLOCK" --tab settings --sample-profiles --open-profiles
    shot 04-database "$CLOCK" --tab medications --search ibal
    shot 05-medications "$CLOCK" --tab medications --sample-profiles
    shot 06-fill "$CLOCK" --tab settings --sample-organizer --fill-organizer
    shot 07-history "$CLOCK" --tab history --sample-profiles
    echo "mac $LANG done"
done
pkill -f "Vzato.app/Contents/MacOS/Vzato" 2>/dev/null || true
