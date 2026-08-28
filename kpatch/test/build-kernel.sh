#!/usr/bin/env bash
set -euo pipefail

TARGET=android14-6.1
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.cache/$TARGET"
RUNTIME="${MEMHIDE_CONTAINER_RUNTIME:-podman}"
IMAGE="${MEMHIDE_DDK_IMAGE:-ghcr.io/soranerai/vpnhide_next/ddk-qemu:${TARGET}}"
BUILD_JOBS="${MEMHIDE_BUILD_JOBS:-$(nproc)}"
BUILD_MEMORY="${MEMHIDE_BUILD_MEMORY:-11g}"

mkdir -p "$OUT"
"$RUNTIME" run --rm \
	--memory "$BUILD_MEMORY" --memory-swap "$BUILD_MEMORY" \
	-v "$REPO:/repo:ro" -v "$OUT:/out" \
	-e MEMHIDE_BUILD_JOBS="$BUILD_JOBS" \
	"$IMAGE" \
	bash -euo pipefail -c '
set -euo pipefail
CLANG_BIN="$(ls -d /opt/ddk/clang/*/bin | head -1)"
export PATH="$CLANG_BIN:$PATH"
KSRC="${VPNHIDE_QEMU_KSRC:-/opt/qemu/linux}"
test -d "$KSRC" || { echo "QEMU kernel tree not found: $KSRC"; exit 1; }

# Match vpnhide_next_private for modern KMIs: patch and rebuild the kernel tree
# already prepared in ddk-qemu instead of starting a clean ddk-min build.
bash /repo/kpatch/scripts/apply.sh "$KSRC" android14-6.1
cd "$KSRC"
./scripts/kconfig/merge_config.sh -m .config /repo/kpatch/test/qemu.config
scripts/config --enable MEMHIDE_TEST --enable MEMHIDE_TEST_AUDIT
scripts/config --disable MODULE_SIG
scripts/config --disable UAPI_HEADER_TEST || true
scripts/config --disable LTO || true
scripts/config --disable LTO_CLANG || true
scripts/config --disable THINLTO || true
scripts/config --enable LTO_NONE || true
make ARCH=arm64 LLVM=1 olddefconfig
grep -qx "CONFIG_MEMHIDE_TEST_AUDIT=y" .config
grep -qx "# CONFIG_MODULE_SIG is not set" .config
make ARCH=arm64 LLVM=1 -j"$MEMHIDE_BUILD_JOBS" Image
"$CLANG_BIN/clang" --target=aarch64-linux-gnu -ffreestanding -nostdlib -static -fuse-ld=lld \
  -fno-stack-protector -Wl,-e,_start /repo/kpatch/test/maps_audit_guest.c \
  -o /out/maps_audit_guest
cp arch/arm64/boot/Image /out/Image
printf "%s\\n" "$(git rev-parse HEAD)" > /out/kernel.commit
'
