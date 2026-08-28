#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="$HERE/.cache/android14-6.1"
QEMU="${MEMHIDE_QEMU_BIN:-qemu-system-aarch64}"
RUNTIME="${MEMHIDE_CONTAINER_RUNTIME:-podman}"
QEMU_IMAGE="${MEMHIDE_QEMU_IMAGE:-}"
IMAGE="$CACHE/Image"
GUEST="$CACHE/maps_audit_guest"
BOUNDARY_GUEST="$CACHE/maps_audit_boundary"
LOG="$CACHE/serial.log"

if [ -z "$QEMU_IMAGE" ]; then
	command -v "$QEMU" >/dev/null || { echo "QEMU unavailable: $QEMU"; exit 2; }
else
	command -v "$RUNTIME" >/dev/null || { echo "Container runtime unavailable: $RUNTIME"; exit 2; }
fi
[ -f "$IMAGE" ] || { echo "Run $HERE/build-kernel.sh first"; exit 2; }
[ -f "$GUEST" ] || { echo "Guest test binary missing"; exit 2; }
[ -f "$BOUNDARY_GUEST" ] || { echo "Boundary guest test binary missing"; exit 2; }
mkdir -p "$CACHE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"
mkdir -p "$ROOT"/{proc,sys,dev}
cp "$GUEST" "$ROOT/maps_audit_guest"
cp "$BOUNDARY_GUEST" "$ROOT/maps_audit_boundary"
cp "$HERE/init.sh" "$ROOT/init"
chmod 0755 "$ROOT/init" "$ROOT/maps_audit_guest" "$ROOT/maps_audit_boundary"
cp "$IMAGE" "$WORK/Image"

if [ -n "$QEMU_IMAGE" ]; then
	# Keep QEMU aligned with vpnhide_next_private: it lives in ddk-qemu,
	# which also supplies cpio and gzip for initramfs creation.
	# The generated kernel and initramfs are mounted read-only for QEMU.
	"$RUNTIME" run --rm -v "$WORK:/work" "$QEMU_IMAGE" \
		bash -euo pipefail -c '
			ROOTFS_TAR="${VPNHIDE_QEMU_ROOTFS:-/opt/qemu/alpine-minirootfs.tar.gz}"
			test -f "$ROOTFS_TAR" || {
				echo "Alpine minirootfs not found: $ROOTFS_TAR" >&2
				exit 1
			}
			tar -xzf "$ROOTFS_TAR" -C /work/root
			cd /work/root
			find . -print | cpio -o -H newc | gzip > /work/initramfs.cpio.gz
		'
	"$RUNTIME" run --rm -v "$WORK:/work:ro" "$QEMU_IMAGE" \
		timeout 120 qemu-system-aarch64 \
		-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi,tb-size=1024 \
		-smp 1 -m 512M \
		-kernel /work/Image -initrd /work/initramfs.cpio.gz \
		-append 'earlycon=pl011,mmio32,0x09000000 console=ttyAMA0 panic=-1 rdinit=/init' \
		-netdev user,id=n0 -device virtio-net-pci,netdev=n0,romfile= \
		-nographic -no-reboot \
		2>&1 | tee "$LOG" || true
else
	command -v cpio >/dev/null || { echo 'cpio unavailable'; exit 2; }
	command -v gzip >/dev/null || { echo 'gzip unavailable'; exit 2; }
	(cd "$ROOT" && find . -print | cpio -o -H newc | gzip > "$WORK/initramfs.cpio.gz")
	timeout 120 "$QEMU" \
		-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi,tb-size=1024 \
		-smp 1 -m 512M \
		-kernel "$IMAGE" -initrd "$WORK/initramfs.cpio.gz" \
		-append 'earlycon=pl011,mmio32,0x09000000 console=ttyAMA0 panic=-1 rdinit=/init' \
		-netdev user,id=n0 -device virtio-net-pci,netdev=n0,romfile= \
		-nographic -no-reboot \
		2>&1 | tee "$LOG" || true
fi
grep -q 'MAPS_HIDE=PASS uid-threshold anonymous-hidden' "$LOG" || {
	echo "QEMU validation failed; serial log retained at: $LOG" >&2
	exit 1
}
