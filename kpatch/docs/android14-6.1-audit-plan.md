# Android 14 / Linux 6.1 maps filtering experiment

## Scope and boundary

This QEMU experiment adds one deliberately narrow hard-coded policy: a reader
with UID 12345 does not receive private or shared anonymous VMA entries from
`/proc/<pid>/maps`. It does not alter VMA flags or process memory.

Target: the prepared `android14-6.1` kernel tree in the matching `ddk-qemu`
image. The tree commit is recorded with the test artifacts.

## Confirmed observation path

In Android common 6.1, maps output is produced in `fs/proc/task_mmu.c`:

1. `proc_pid_maps_operations` selects `pid_maps_open()`.
2. `pid_maps_open()` calls `do_maps_open()` with the maps seq operations.
3. The seq `show` callback is `show_map()`.
4. `show_map()` calls `show_map_vma()` once for each VMA.

The policy point is immediately before `show_map_vma()`. At that point the VMA
being emitted is known. The test helper records an audit decision and may skip
the output call only for UID 12345 and an anonymous VMA.

## Event contract

Emit one kernel trace event for each VMA only when the test feature is enabled.
The current implementation uses `trace_printk()` so events are collected from
the QEMU trace buffer; it is compiled only with `CONFIG_MEMHIDE_TEST_AUDIT=y`.
The event fields are:

- reader TGID and UID;
- target TGID and UID, obtained from the existing proc maps private context;
- VMA start and end addresses;
- `vm_flags`;
- whether `vm_file` is present;
- whether an anonymous VMA has an anon-vma association;
- an enum classification: anonymous-private, anonymous-shared, file-backed,
  special, or unknown.

Do not log mapping contents, file paths, VMA names, user data, or raw pointers
other than the address range already exposed by `maps` to the authorised reader.
Use tracefs rather than printk so collection is explicit and bounded.

## Configuration and integration

Add a test-only `CONFIG_MEMHIDE_TEST_AUDIT` option below `CONFIG_MEMHIDE_TEST`.
It depends on `TRACEPOINTS` and defaults to `n`. The production-neutral module
remains inert when the option is off.

The target-tree patch has two deliberate parts:

1. Wire `security/memhide_test` into `security/Kconfig` and
   `security/Makefile`.
2. Add the audit callback at the `show_map()` observation point in
   `fs/proc/task_mmu.c`.

The patch must be version-pinned under `versions/android14-6.1/`; it must not
be applied to a different Android common branch by filename inference.

## QEMU matrix

The guest test program creates and reads these mappings from its own
`/proc/self/maps`:

1. private anonymous RW mapping;
2. shared anonymous RW mapping;
3. private file-backed mapping;
4. memfd-backed mapping, when available;
5. ordinary heap and stack baseline.

For every case the test records the expected mapping interval, collects the
trace events, and verifies exactly one matching audit event with the expected
classification. It also snapshots `maps` before and after tracing and requires
byte-for-byte identical output except for normal address randomisation between
separate process launches.

Run the guest with `panic_on_warn=1`, KASAN/KCSAN when the selected build
supports them, and a fixed serial timeout. The runner reports the pinned kernel
commit, config fragment checksum, and a PASS/FAIL summary.

## Exit criteria for this phase

- Android 6.1 Image boots in QEMU with `CONFIG_MEMHIDE_TEST_AUDIT=y`.
- All five map classes produce the expected audit classification.
- The feature-off build emits no events.
- Root sees both anonymous VMAs; UID 12345 loses both while retaining a
  file-backed control mapping.
- No warning, lockdep report, KASAN report, or kernel panic occurs.

## Explicit non-goals

- General-purpose or configurable filtering policy.
- Target selection by arbitrary PID ranges.
- Product/runtime identification or integration.
- Coverage of `smaps`, `numa_maps`, `pagemap`, or external-process reads in
  this first experiment.
