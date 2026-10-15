#!/bin/bash
# Build the Android image the Subsystem downloads: LineageOS for its
# virtio_arm64only target (the one LineageOS made for QEMU and UTM on Apple
# silicon), as a UTM package zip.
#
#   rom/build-rom.sh [output-dir]
#
# Environment:
#   LINEAGE_BRANCH   default lineage-24.0 (Android 17)
#   BUILD_VARIANT    default userdebug
#   WORKDIR          where the ~300 GB source tree lives (default ./lineage)
#
# Needs Ubuntu (22.04 or later), about 300 GB of disk, 32 GB of RAM and several
# hours. Based on LineageOS's "Building and installing for UTM virtual machine on
# Apple Silicon Mac" guide and jqssun/android-lineage-qemu's build script.
#
# What we change from stock LineageOS, and why:
#   * ADB doesn't ask "Allow USB debugging?". The VM has no screen anyone sees,
#     and its adbd is only reachable through 127.0.0.1 on the Mac (QEMU forwards
#     127.0.0.1:58526 to it), so the prompt protects nothing and blocks everything.
#   * No Google apps: the image is the lightest one LineageOS offers.
set -euo pipefail

OUT_DIR="$(mkdir -p "${1:-$PWD/out}" && cd "${1:-$PWD/out}" && pwd)"
BRANCH="${LINEAGE_BRANCH:-lineage-24.0}"
VARIANT="${BUILD_VARIANT:-userdebug}"
TARGET="virtio_arm64only"
WORKDIR="${WORKDIR:-$PWD/lineage}"

echo "Building LineageOS ${BRANCH} ${TARGET} (${VARIANT}) in ${WORKDIR}"

if command -v apt-get >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs \
        gnupg gperf imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev \
        libelf-dev lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
        squashfs-tools xsltproc zip zlib1g-dev python-is-python3 python3-yaml qemu-utils \
        glslang-tools python3-mako meson
fi
git config --global user.name >/dev/null || git config --global user.name "Mac Subsystem for Android"
git config --global user.email >/dev/null || git config --global user.email "build@localhost"
git config --global color.ui false
git lfs install

mkdir -p "${WORKDIR}/bin"
if [ ! -x "${WORKDIR}/bin/repo" ]; then
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "${WORKDIR}/bin/repo"
    chmod a+x "${WORKDIR}/bin/repo"
fi
export PATH="${WORKDIR}/bin:${PATH}"
export USE_CCACHE=1 CCACHE_EXEC="$(command -v ccache)"
ccache -M 50G >/dev/null || true

mkdir -p "${WORKDIR}/android"
cd "${WORKDIR}/android"
repo init -u https://github.com/LineageOS/android.git -b "${BRANCH}" --git-lfs --no-clone-bundle --depth 1
repo sync -c --prune --force-sync --no-tags --retry-fetches=8 -j"$(nproc)"

# ADB without the authorization prompt (see above). vendor/lineage/config/common.mk
# sets ro.adb.secure=0 when WITH_ADB_INSECURE is defined.
export WITH_ADB_INSECURE=true

# shellcheck disable=SC1091
source build/envsetup.sh
breakfast "${TARGET}" "${VARIANT}"
m vm-utm-zip

ZIP="$(ls out/target/product/${TARGET}/VirtualMachine/UTM/UTM-VM-lineage-*.zip | head -1)"
cp "${ZIP}" "${OUT_DIR}/"
echo "Wrote ${OUT_DIR}/$(basename "${ZIP}")"
