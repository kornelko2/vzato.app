#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Mac App Store screenshots (2880 × 1800) of a Debug build, with demo data in a throwaway store
# (--scratch-store), so the data of an installed Vzato on this Mac is not touched. Quits a
# running Vzato first. Needs Screen Recording permission for the terminal.
#
#   Scripts/screenshots-mac.sh <path to Vzato.app for macOS> <output folder>
set -e
APP="$1"; OUT="$2"
WINID="${TMPDIR:-/tmp}/vzato-winid"
cat > "$WINID.swift" <<'SWIFT'
import CoreGraphics
import Foundation
// Prints "x,y,width,height" of Vzato's largest normal window, in points.
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var best: (Int, String)?
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Vzato" && (w[kCGWindowLayer as String] as? Int) == 0 {
    guard let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
    let v = ["X", "Y", "Width", "Height"].map { (b[$0] as? NSNumber)?.intValue ?? 0 }
    if v[2] > (best?.0 ?? 0) { best = (v[2], v.map(String.init).joined(separator: ",")) }
}
if let best { print(best.1) }
SWIFT
swiftc -O -o "$WINID" "$WINID.swift"

for LANG in cs sk en hu; do
    case "$LANG" in cs) LOC=cs_CZ ;; sk) LOC=sk_SK ;; en) LOC=en_GB ;; hu) LOC=hu_HU ;; esac
    DIR="$OUT/$LANG"; mkdir -p "$DIR"
    shot() {
        FILE="$1"; shift
        osascript -e 'if application id "app.vzato" is running then tell application id "app.vzato" to quit' >/dev/null 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "Vzato.app/Contents/MacOS/Vzato" >/dev/null || break; sleep 1; done
        pkill -f "Vzato.app/Contents/MacOS/Vzato" 2>/dev/null && sleep 2 || true
        # AppKit reads "-key value" pairs from the command line; a lone value left over is taken
        # as a file to open, and the app then opens no window. So pairs first, plain flags last.
        TAB="$1"; MODE="$2"
        open -n -a "$APP" --args --window-size 1440x900 -AppleLanguages "($LANG)" -AppleLocale "$LOC" \
            --tab "$TAB" --sample-data "$MODE" --scratch-store
        RECT=""
        for _ in $(seq 1 25); do sleep 1; RECT=$("$WINID"); [ -n "$RECT" ] && break; done
        [ -n "$RECT" ] || { echo "no window for $LANG $FILE"; return 1; }
        sleep 3   # let the content settle
        screencapture -x -R"$RECT" "$DIR/$FILE.png"
        sips -z 1800 2880 "$DIR/$FILE.png" >/dev/null
    }
    shot 01-today today --no-onboarding
    shot 02-medications medications --no-onboarding
    shot 03-history history --no-onboarding
    shot 04-guide today --onboarding
    echo "mac $LANG done"
done
pkill -f "Vzato.app/Contents/MacOS/Vzato" 2>/dev/null || true
