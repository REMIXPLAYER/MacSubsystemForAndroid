#!/bin/bash
# Bundle QEMU for the Mac app: Homebrew's qemu-system-aarch64 and qemu-img, their
# libraries (install names rewritten to point inside the app), and the arm64 UEFI
# firmware. Output: build/payload/qemu/{Helpers,Frameworks/qemu,share}
#
#   core/scripts/bundle-qemu.sh
#
# Run on an Apple-silicon Mac (or macOS runner) with Homebrew. QEMU runs as its
# own process, so its GPLv2 licence sits beside the app's GPLv3 one; NOTICE.md
# says where its source comes from.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${ROOT}/build/payload/qemu"

command -v brew >/dev/null || { echo "Homebrew is required"; exit 1; }
brew list --formula qemu >/dev/null 2>&1 || brew install qemu
brew list --formula dylibbundler >/dev/null 2>&1 || brew install dylibbundler
QEMU="$(brew --prefix qemu)"
echo "Bundling $(${QEMU}/bin/qemu-system-aarch64 --version | head -1)"

rm -rf "${OUT}"
mkdir -p "${OUT}/Helpers" "${OUT}/Frameworks/qemu" "${OUT}/share"
cp "${QEMU}/bin/qemu-system-aarch64" "${QEMU}/bin/qemu-img" "${OUT}/Helpers/"
chmod u+w "${OUT}/Helpers/"*

# Copy every non-system dylib next to the app and point the binaries at it.
dylibbundler --overwrite-files --bundle-deps --create-dir \
    --fix-file "${OUT}/Helpers/qemu-system-aarch64" \
    --fix-file "${OUT}/Helpers/qemu-img" \
    --dest-dir "${OUT}/Frameworks/qemu" \
    --install-path "@executable_path/../Frameworks/qemu/" \
    --search-path "$(brew --prefix)/lib"

cp "${QEMU}/share/qemu/edk2-aarch64-code.fd" "${OUT}/share/"
# QEMU's licence travels with it.
cp "${QEMU}/share/doc/qemu/LICENSE" "${OUT}/share/QEMU-LICENSE" 2>/dev/null \
    || cp "${QEMU}/LICENSE" "${OUT}/share/QEMU-LICENSE" 2>/dev/null || true
"${QEMU}/bin/qemu-system-aarch64" --version | head -1 > "${OUT}/share/QEMU-VERSION"

du -sh "${OUT}"
echo "Wrote ${OUT}"
