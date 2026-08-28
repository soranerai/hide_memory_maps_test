# QEMU test

`ci-qemu.sh` builds Android common 6.1 and boots it in QEMU. The guest verifies
that root sees private and shared-anonymous test VMAs, then switches to UID
12345 and verifies that both anonymous VMAs are suppressed while the
file-backed executable remains visible. Trace events verify all decisions.
