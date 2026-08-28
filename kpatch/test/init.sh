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
if ! /maps_audit_boundary; then
	echo 'MAPS_HIDE=FAIL uid-10000-boundary-check'
	poweroff -f
fi
if ! /maps_audit_guest; then
	echo 'MAPS_HIDE=FAIL guest-policy-check'
	poweroff -f
fi
echo 0 > /sys/kernel/tracing/tracing_on

if ! grep -q 'memhide_test_maps.*uid=0 .*kind=1.*hide=0' "$TRACE"; then
	echo 'MAPS_HIDE=FAIL missing-root-control'
	poweroff -f
fi
if ! grep -q 'memhide_test_maps.*uid=10000 .*kind=0.*anon_vma=0.*hide=0' "$TRACE"; then
	echo 'MAPS_HIDE=FAIL uid-10000-boundary-decision'
	poweroff -f
fi
if ! grep -q 'memhide_test_maps.*uid=10001 .*kind=0.*anon_vma=0.*hide=1' "$TRACE"; then
	echo 'MAPS_HIDE=FAIL missing-private-hide-decision'
	poweroff -f
fi
if ! grep -q 'memhide_test_maps.*uid=10001 .*kind=1.*hide=1' "$TRACE"; then
	echo 'MAPS_HIDE=FAIL missing-shared-hide-decision'
	poweroff -f
fi
if ! grep -q 'memhide_test_maps.*uid=10001 .*kind=2.*hide=0' "$TRACE"; then
	echo 'MAPS_HIDE=FAIL missing-file-control'
	poweroff -f
fi
echo 'MAPS_HIDE=PASS uid-threshold anonymous-hidden'
poweroff -f
