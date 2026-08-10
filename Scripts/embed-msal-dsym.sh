#!/bin/bash
#
# Supply MSAL's dSYM to the archive.
#
# MSAL ships as a *binary* SPM target — a prebuilt, stripped MSAL.xcframework —
# so Xcode has no debug info to generate a dSYM from, and the archive goes up
# without one. App Store Connect then answers every upload with:
#
#   Upload Symbols Failed — The archive did not include a dSYM for the
#   MSAL.framework with the UUIDs [...]
#
# Microsoft does publish the matching dSYM as a GitHub release asset, just not
# inside the xcframework. This fetches the one for the exact resolved version,
# caches it, checks its UUID actually matches the binary we linked, and drops it
# where Xcode collects dSYMs for the archive.
#
# Only runs for builds that produce dSYMs at all (Release / archive), so normal
# Debug builds are untouched and never hit the network.

set -euo pipefail

[ "${DEBUG_INFORMATION_FORMAT:-}" = "dwarf-with-dsym" ] || exit 0

REPO="AzureAD/microsoft-authentication-library-for-objc"
RESOLVED="${SRCROOT}/Workshop.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
CACHE="${SRCROOT}/.dsyms"

warn() { echo "warning: [MSAL dSYM] $*"; }

[ -f "$RESOLVED" ] || { warn "no Package.resolved at $RESOLVED; skipping."; exit 0; }

VERSION=$(/usr/bin/python3 -c '
import json, sys
pins = json.load(open(sys.argv[1])).get("pins", [])
for p in pins:
    if p.get("identity") == "microsoft-authentication-library-for-objc":
        print(p.get("state", {}).get("version", ""))
        break
' "$RESOLVED")

[ -n "$VERSION" ] || { warn "MSAL not found in Package.resolved; skipping."; exit 0; }

# Device and simulator are separate builds of the framework with separate UUIDs.
if [ "${EFFECTIVE_PLATFORM_NAME:-}" = "-iphonesimulator" ]; then
    ASSET="MSAL-iOS-Sim.framework.dSYM.zip"
    SLICE="sim"
else
    ASSET="MSAL-iOS.framework.dSYM.zip"
    SLICE="device"
fi

DEST_DIR="${CACHE}/${VERSION}-${SLICE}"
DSYM="${DEST_DIR}/MSAL.framework.dSYM"

if [ ! -d "$DSYM" ]; then
    URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"
    echo "note: [MSAL dSYM] fetching ${VERSION} (${SLICE}) from ${URL}"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    if ! /usr/bin/curl -fsSL --retry 2 -o "$TMP/dsym.zip" "$URL"; then
        warn "could not download $ASSET for $VERSION — the archive will upload without MSAL symbols."
        exit 0
    fi
    /usr/bin/unzip -qq -o "$TMP/dsym.zip" -d "$TMP/x"
    # The zip preserves Microsoft's full CI path
    # (Users/runner/work/1/b/iOS.xcarchive/dSYMs/...), so search unbounded.
    FOUND=$(/usr/bin/find "$TMP/x" -type d -name "*.framework.dSYM" -print -quit)
    [ -n "$FOUND" ] || { warn "no .framework.dSYM inside $ASSET; skipping."; exit 0; }
    mkdir -p "$DEST_DIR"
    rm -rf "$DSYM"
    cp -R "$FOUND" "$DSYM"
fi

# A dSYM whose UUID doesn't match the linked binary is worse than none — Apple
# would reject it and we'd have hidden the real problem behind a stale file.
BINARY="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH:-}/MSAL.framework/MSAL"
if [ -f "$BINARY" ]; then
    want=$(/usr/bin/dwarfdump --uuid "$BINARY" | /usr/bin/awk '{print $2}' | sort -u)
    have=$(/usr/bin/dwarfdump --uuid "$DSYM" | /usr/bin/awk '{print $2}' | sort -u)
    for u in $want; do
        if ! echo "$have" | grep -qx "$u"; then
            warn "dSYM for MSAL $VERSION is missing UUID $u (has: $(echo $have)). Delete ${CACHE} and rebuild."
            exit 0
        fi
    done
fi

mkdir -p "${DWARF_DSYM_FOLDER_PATH}"
rm -rf "${DWARF_DSYM_FOLDER_PATH}/MSAL.framework.dSYM"
cp -R "$DSYM" "${DWARF_DSYM_FOLDER_PATH}/MSAL.framework.dSYM"
echo "note: [MSAL dSYM] staged MSAL $VERSION ($SLICE) in ${DWARF_DSYM_FOLDER_PATH}"
