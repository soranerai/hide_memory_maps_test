# memhide-test kpatch skeleton

Minimal in-tree Linux kernel research experiment. In the current test-only
policy, readers with UID greater than 10000 do not receive private or shared
anonymous VMA entries from `/proc/*/maps`; file-backed mappings and UIDs up to
and including 10000 are unchanged.

`scripts/apply.sh <kernel-source-dir> android14-6.1` copies the driver and public
header, wires the Kconfig/Makefile integration, and applies the target-specific
`show_map()` call-site patch.

Keep target-specific experimental patches under `versions/<target>/` and test
each target independently.
