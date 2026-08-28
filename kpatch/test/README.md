# QEMU test

`ci-qemu.sh` builds Android common 6.1 and boots it in QEMU. The guests verify
that root sees touched and untouched private-anonymous VMAs plus a
shared-anonymous VMA. UID 10000 must retain all three mappings, while UID 10001
must lose all three and retain the file-backed executable mapping. Trace events
verify the boundary and include the untouched `anon_vma=0` case.
