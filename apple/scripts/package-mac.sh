#!/bin/bash
# Sign the app (inside out) and wrap it in a DMG.
#
#   apple/scripts/package-mac.sh "<path/to/Mac Android Subsystem.app>" <output.dmg>
#
# Without secrets everything is signed ad hoc (people right-click › Open the first
# time). With these environment variables it is signed with Developer ID and
# notarized, so it opens with a normal double-click:
#   MAC_SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID1234)"
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD (an app-specific password)
set -euo pipefail

APP="${1:?app path}"
OUTPUT="${2:?output dmg}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$(basename "${APP}" .app)"
IDENTITY="${MAC_SIGN_IDENTITY:--}"
APP_ENTITLEMENTS="${HERE}/Subsystem/Subsystem.entitlements"
QEMU_ENTITLEMENTS="${HERE}/Subsystem/QEMU.entitlements"

SIGN=(codesign --force --sign "${IDENTITY}" --options runtime)
if [ "${IDENTITY}" != "-" ]; then
    SIGN+=(--timestamp)
    echo "Signing with ${IDENTITY}"
else
    echo "Signing ad hoc (no MAC_SIGN_IDENTITY)"
fi

# 1. QEMU's libraries.
if [ -d "${APP}/Contents/Frameworks" ]; then
    find "${APP}/Contents/Frameworks" -type f \( -name '*.dylib' -o -perm -111 \) -print0 |
        while IFS= read -r -d '' library; do "${SIGN[@]}" "${library}"; done
    find "${APP}/Contents/Frameworks" -maxdepth 1 -name '*.framework' -print0 |
        while IFS= read -r -d '' framework; do "${SIGN[@]}" "${framework}"; done
fi
# 2. QEMU itself, with the Hypervisor entitlement.
for tool in qemu-system-aarch64 qemu-img; do
    if [ -f "${APP}/Contents/Helpers/${tool}" ]; then
        "${SIGN[@]}" --entitlements "${QEMU_ENTITLEMENTS}" "${APP}/Contents/Helpers/${tool}"
    fi
done
# 3. The window host that launchers copy.
"${SIGN[@]}" "${APP}/Contents/Helpers/AndroidAppHost"
# 4. The app.
"${SIGN[@]}" --entitlements "${APP_ENTITLEMENTS}" "${APP}"
codesign --verify --deep --strict "${APP}"

# Disk image: styled when create-dmg is available, plain otherwise.
rm -rf "${HERE}/build/dmg" "${OUTPUT}"
mkdir -p "${HERE}/build/dmg"
cp -R "${APP}" "${HERE}/build/dmg/"
if command -v create-dmg >/dev/null && create-dmg \
        --volname "${NAME}" \
        --background "${HERE}/dmg/background.png" \
        --window-pos 200 120 --window-size 600 400 --icon-size 112 \
        --icon "${NAME}.app" 165 200 --hide-extension "${NAME}.app" \
        --app-drop-link 435 200 \
        "${OUTPUT}" "${HERE}/build/dmg/"; then
    echo "Styled disk image created"
else
    rm -f "${OUTPUT}"
    ln -s /Applications "${HERE}/build/dmg/Applications"
    hdiutil create -volname "${NAME}" -srcfolder "${HERE}/build/dmg" -ov -format UDZO "${OUTPUT}"
fi

if [ "${IDENTITY}" != "-" ]; then
    codesign --force --sign "${IDENTITY}" --timestamp "${OUTPUT}"
    if [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ]; then
        xcrun notarytool submit "${OUTPUT}" --apple-id "${NOTARY_APPLE_ID}" --team-id "${NOTARY_TEAM_ID}" \
            --password "${NOTARY_PASSWORD}" --wait
        xcrun stapler staple "${OUTPUT}"
    fi
fi
echo "Wrote ${OUTPUT}"
