#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
# Install the memhide-test in-tree skeleton into a kernel source tree.
# Usage: apply.sh <kernel-source-dir> android14-6.1
set -euo pipefail

KERNEL_DIR="${1:?Usage: $0 <kernel-source-dir> android14-6.1}"
TARGET="${2:?Usage: $0 <kernel-source-dir> android14-6.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KPATCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DRIVER_DIR="$KPATCH_DIR/security/memhide_test"
HEADER="$KPATCH_DIR/include/linux/memhide_test.h"
PATCH_DIR="$KPATCH_DIR/versions/$TARGET"

die() { echo "[memhide-test] ERROR: $*" >&2; exit 1; }
log() { echo "[memhide-test] $*"; }

[ -d "$KERNEL_DIR" ] || die "kernel source directory not found: $KERNEL_DIR"
[ -d "$DRIVER_DIR" ] || die "driver source not found: $DRIVER_DIR"
[ -f "$HEADER" ] || die "public header not found: $HEADER"
[ "$TARGET" = "android14-6.1" ] || die "unsupported target: $TARGET"
[ -d "$PATCH_DIR" ] || die "patch directory not found: $PATCH_DIR"

log "Copying security/memhide_test..."
rm -rf "$KERNEL_DIR/security/memhide_test"
cp -a "$DRIVER_DIR" "$KERNEL_DIR/security/memhide_test"

log "Copying include/linux/memhide_test.h..."
cp -a "$HEADER" "$KERNEL_DIR/include/linux/memhide_test.h"

for patch_file in "$PATCH_DIR"/*.patch; do
	[ -f "$patch_file" ] || die "no patches found in $PATCH_DIR"
	log "Applying $(basename "$patch_file")..."
	patch --forward --batch --fuzz=0 --no-backup-if-mismatch -p1 \
		-d "$KERNEL_DIR" < "$patch_file" || die "patch failed: $patch_file"
done

log "Audit-only skeleton installed; /proc maps output is unchanged."
