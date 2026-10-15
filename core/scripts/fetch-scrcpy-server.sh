#!/bin/bash
# Download the scrcpy server (Apache 2.0) that app windows run inside Android,
# and check it against the SHA-256 published in scrcpy's doc/build.md.
#
#   core/scripts/fetch-scrcpy-server.sh
#
# The client protocol in apple/Shared/Scrcpy is written for this exact version;
# change SCRCPY_VERSION in apple/Config/Base.xcconfig together with it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="5.0.1"
SHA256="764eb6f79811d5211fe9df341120882ba9994c7a61b897d7bf3fb662e53bc536"
OUT="${ROOT}/build/payload/scrcpy-server.jar"

CONFIGURED="$(awk -F' *= *' '/^SCRCPY_VERSION/ {print $2}' "${ROOT}/apple/Config/Base.xcconfig")"
if [ "${CONFIGURED}" != "${VERSION}" ]; then
    echo "SCRCPY_VERSION in Base.xcconfig (${CONFIGURED}) doesn't match ${VERSION}"
    exit 1
fi

mkdir -p "$(dirname "${OUT}")"
curl -fsSL -o "${OUT}" "https://github.com/Genymobile/scrcpy/releases/download/v${VERSION}/scrcpy-server-v${VERSION}"
ACTUAL="$(shasum -a 256 "${OUT}" 2>/dev/null | cut -d' ' -f1 || sha256sum "${OUT}" | cut -d' ' -f1)"
if [ "${ACTUAL}" != "${SHA256}" ]; then
    rm -f "${OUT}"
    echo "Checksum mismatch for scrcpy-server v${VERSION}"
    exit 1
fi
echo "Wrote ${OUT}"
