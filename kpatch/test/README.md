# QEMU test

`ci-qemu.sh` builds Android common 6.1 and boots it in QEMU. The guest verifies
that root sees private and shared-anonymous test VMAs, then switches to UID
12345 and verifies that only the shared-anonymous VMA is suppressed from
`/proc/self/maps`. Trace events independently verify both policy decisions.
