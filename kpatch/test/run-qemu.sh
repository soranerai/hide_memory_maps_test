#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="$HERE/.cache/android14-6.1"
QEMU="${MEMHIDE_QEMU_BIN:-qemu-system-aarch64}"
IMAGE="$CACHE/Image"
GUEST="$CACHE/maps_audit_guest"

command -v "$QEMU" >/dev/null || { echo "QEMU unavailable: $QEMU"; exit 2; }
[ -f "$IMAGE" ] || { echo "Run $HERE/build-kernel.sh first"; exit 2; }
[ -f "$GUEST" ] || { echo "Guest test binary missing"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"
mkdir -p "$ROOT"/{proc,sys,dev}
cp "$GUEST" "$ROOT/maps_audit_guest"
cp "$HERE/init.sh" "$ROOT/init"
chmod 0755 "$ROOT/init" "$ROOT/maps_audit_guest"
(cd "$ROOT" && find . -print | cpio -o -H newc | gzip > "$WORK/initramfs.cpio.gz")

timeout 120 "$QEMU" -machine virt -cpu cortex-a57 -smp 1 -m 512M \
	-kernel "$IMAGE" -initrd "$WORK/initramfs.cpio.gz" \
	-append 'console=ttyAMA0 panic=-1 rdinit=/init' -nographic -no-reboot \
	2>&1 | tee "$WORK/serial.log" || true
grep -q 'MAPS_AUDIT=PASS maps-output-unmodified' "$WORK/serial.log"
