# memhide-test kpatch skeleton

Minimal starting point for an in-tree Linux kernel research module. It contains
only Kconfig/Makefile wiring, a public no-op API, and a module initialisation
stub. It does not alter memory maps or install hooks.

`scripts/apply.sh <kernel-source-dir>` copies the driver and public header into
a kernel tree. It intentionally leaves integration into `security/Kconfig` and
`security/Makefile` as an explicit manual step, and applies no call-site patches.

Keep target-specific experimental patches under `versions/<target>/` and test
each target independently.
