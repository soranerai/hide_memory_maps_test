#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
# Build and run the Android 6.1 hard-coded UID maps-filter experiment.
#
# Required host tool: podman (or docker via MEMHIDE_CONTAINER_RUNTIME).
# Initramfs creation and QEMU both run in the ddk-qemu image used by
# vpnhide_next_private.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${MEMHIDE_LOG_DIR:-/tmp/memhide-ci-qemu}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ci-qemu-$(date +%Y%m%d-%H%M%S).log"

# Capture every build and QEMU message, including a failing `make`, while
# retaining the live console output.
exec > >(tee "$LOG_FILE") 2>&1
echo "[memhide-test] full log: $LOG_FILE"

require_command() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "ERROR: required command not found: $1" >&2
		exit 2
	}
}

RUNTIME="${MEMHIDE_CONTAINER_RUNTIME:-podman}"
QEMU_IMAGE="${MEMHIDE_QEMU_IMAGE:-ghcr.io/soranerai/vpnhide_next/ddk-qemu:android14-6.1}"

require_command "$RUNTIME"

echo '[memhide-test] building Android common android14-6.1 Image...'
MEMHIDE_CONTAINER_RUNTIME="$RUNTIME" "$HERE/build-kernel.sh"

echo '[memhide-test] running QEMU guest validation...'
MEMHIDE_CONTAINER_RUNTIME="$RUNTIME" \
MEMHIDE_QEMU_IMAGE="$QEMU_IMAGE" \
"$HERE/run-qemu.sh"

echo '[memhide-test] PASS: build and QEMU UID-filter validation completed'
