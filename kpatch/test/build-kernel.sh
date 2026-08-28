#!/usr/bin/env bash
set -euo pipefail

TARGET=android14-6.1
EXPECTED_COMMIT=14162556ede8fd41c08ac4b44ffe3709343e8755
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.cache/$TARGET"
RUNTIME="${MEMHIDE_CONTAINER_RUNTIME:-podman}"
IMAGE="${MEMHIDE_DDK_IMAGE:-ghcr.io/ylarod/ddk-min:${TARGET}-20260313}"

mkdir -p "$OUT"
"$RUNTIME" run --rm -v "$REPO:/repo:ro" -v "$OUT:/out" "$IMAGE" \
	bash -euo pipefail -c '
set -euo pipefail
git clone --depth=1 -b android14-6.1 https://android.googlesource.com/kernel/common /tmp/linux
cd /tmp/linux
test "$(git rev-parse HEAD)" = "'"$EXPECTED_COMMIT"'" || {
  echo "unexpected Android common revision: $(git rev-parse HEAD)"; exit 1;
}
bash /repo/kpatch/scripts/apply.sh /tmp/linux android14-6.1
make ARCH=arm64 LLVM=1 gki_defconfig
./scripts/kconfig/merge_config.sh -m .config /repo/kpatch/test/qemu.config
scripts/config --enable MEMHIDE_TEST --enable MEMHIDE_TEST_AUDIT
make ARCH=arm64 LLVM=1 olddefconfig
grep -qx "CONFIG_MEMHIDE_TEST_AUDIT=y" .config
make ARCH=arm64 LLVM=1 -j"$(nproc)" Image
CLANG_BIN="$(dirname "$(command -v clang)")"
"$CLANG_BIN/clang" --target=aarch64-linux-gnu -ffreestanding -nostdlib -static -fuse-ld=lld \
  -fno-stack-protector -Wl,-e,_start /repo/kpatch/test/maps_audit_guest.c \
  -o /out/maps_audit_guest
cp arch/arm64/boot/Image /out/Image
printf "%s\\n" "$(git rev-parse HEAD)" > /out/kernel.commit
'
