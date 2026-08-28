#!/bin/sh
set -eu

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null || true

TRACE=/sys/kernel/tracing/trace
if [ ! -w "$TRACE" ]; then
	echo 'MAPS_AUDIT=FAIL tracefs-unavailable'
	poweroff -f
fi

echo 0 > /sys/kernel/tracing/tracing_on
echo > "$TRACE"
echo 1 > /sys/kernel/tracing/tracing_on
/maps_audit_guest
echo 0 > /sys/kernel/tracing/tracing_on

if ! grep -q 'memhide_test_maps.*kind=0' "$TRACE"; then
	echo 'MAPS_AUDIT=FAIL missing-anon-private'
	poweroff -f
fi
if ! grep -q 'memhide_test_maps.*kind=1' "$TRACE"; then
	echo 'MAPS_AUDIT=FAIL missing-anon-shared'
	poweroff -f
fi
echo 'MAPS_AUDIT=PASS maps-output-unmodified'
poweroff -f
