# Diagnostic test plan — Snap Store NVIDIA EGL SIGSEGV

Related upstream ticket: https://github.com/ubuntu/app-center/issues/2271

**Current status: all tests below are pending unless explicitly marked confirmed.** Preserve baseline system state and record each action, timestamp and outcome. Do not change GPU drivers, kernel parameters, or CPU topology in the same experiment.

## T0 — Validate stored incident metadata (confirmed by earlier log)

```bash
coredumpctl info 40117 --no-pager
```

Expected existing evidence: `snap-store`, signal 11, 2026-10-27 16:04:13 CET, `Storage: ... (present)`, compressed size 19.3 MB. Storage could be purged later; recheck before extraction.

## T1 — Extract and inspect the core (pending)

\`\`\`bash
# Safe default: metadata ONLY; does not export the core or start GDB.
./scripts/analyze-core.sh 40117

# Optional, only when system health is good and explicit resource limits work:
# ./scripts/analyze-core.sh 40117 --extract
# ./scripts/analyze-core.sh 40117 --gdb
\`\`\`

**Incident update (2026-10-28):** Running `sudo apt install gdb` followed by the previous `./scripts/analyze-core.sh 40117` reportedly hung the host. It has not been determined whether package installation, core extraction, or GDB caused the hang. Record this as a separate observed outcome, not a confirmed defect in GDB. The new script defaults to metadata only, uses time/resource-limited user scopes for opt-in stages, disables GDB auto-loading and debuginfod, and takes a shallow fault-thread trace. Do not automatically increase limits or rerun the previous workflow. A separate disposable VM with a copy of the core is preferable for intensive analysis.

If the opt-in GDB stage completes, inspect the private report for:

- A shallow backtrace of the faulting thread; do not request all-thread full-variable backtraces on this host.
- `$pc`, `$sp`, fault-related registers and disassembly around the faulting instruction.
- Whether the limited trace contains symbol names; defer complete shared-object inventory to offline analysis.
- Whether the effective memory address can be calculated from the faulting instruction and registers.
- Consistency with the original `0x1278` fault address; do **not** infer the pointer base from the address alone.

**Caution:** NVIDIA user-space libraries are proprietary and may have limited public symbols. A mostly unsymbolicated NVIDIA backtrace is possible. Do not claim the stack is diagnostic if frames are missing/unreliable.

## T2 — Capture a baseline reproduction (pending)

From an X11 desktop terminal:

```bash
snap run snap-store
```

Before launching, check whether Snap Store is already running (single-instance behavior can affect testing). Capture a precise action sequence (launch, navigation, updates, idle, close), exact start/end times, and whether the app crashes. After a crash:

```bash
coredumpctl list snap-store --no-pager
journalctl -k --since '10 minutes ago' --no-pager | grep -Ei 'nvrm|xid|nvidia|mce|edac|segfault' || true
```

Record the PID and timestamp for any **new** dump; do not assume it is PID 40117.

## T3 — CPU-affinity controlled comparison (pending)

The earlier Ubuntu CPU topology showed 12 logical CPUs, with CPUs 2 and 8 as siblings on a separate physical core implicated in Firefox investigation. **Verify topology on the day of the test**:

```bash
lscpu -e=CPU,CORE,SOCKET,ONLINE
cat /sys/devices/system/cpu/cpu2/topology/thread_siblings_list
```

Then compare T2 with a launch excluding the suspect siblings:

```bash
./scripts/launch-with-affinity.sh 0,1,3-7,9-11
```

Try comparable actions and run counts. If a crash ceases, this is **correlation only**: CPU selection also changes scheduling/timing and workload distribution. A crash on CPU 9 in the original dump argues against assuming that only the suspect siblings can trigger failures. Do not run a destructive CPU stress test as part of this GUI comparison.

## T4 — Graphics-path isolation (pending, exploratory)

Compare the ordinary launch with an exploratory software-rendering request:

```bash
LIBGL_ALWAYS_SOFTWARE=1 snap run snap-store
```

`LIBGL_ALWAYS_SOFTWARE=1` is a Mesa setting and **may not force Snap Store's rendering pipeline away from NVIDIA**, particularly through EGL/GLVND/snap confinement. A non-crash under this setting does not prove the driver is faulty; a crash does not prove software rendering was used. **Verify the actual renderer first** using appropriate application/runtime diagnostics before labeling the result "software-rendered." A separate X11 vs Wayland comparison, if available, should be its own controlled experiment.

## T5 — Kernel, GPU and hardware error correlation (pending)

Capture around each reproducible attempt:

```bash
START=$(date --iso-8601=seconds)
# Perform the test in a separate terminal.
sudo journalctl -k --since "$START" --no-pager \
  | grep -Ei 'nvrm|xid|nvidia|mce|machine check|edac|hardware error|segfault' || true
nvidia-smi
```

NVIDIA `Xid` errors may be informative but are not guaranteed. `MCE`/`EDAC` absence does not exclude transient CPU or RAM faults. Do not interpret GPU ECC availability on the RTX 2080 Ti as a general CPU/RAM integrity test.

## T6 — Compare driver/runtime versions (deferred)

Only after T1–T5, and after making a system recovery plan, consider comparing another officially supported NVIDIA driver or snap revision. Record **one changed variable at a time** and avoid making an unsupported causal claim from a single success. The repository contains no automated driver installation/replacement commands.

## Reporting criteria

Record every attempt in [RESULTS-TEMPLATE.md](RESULTS-TEMPLATE.md), including negative results, reboots, existing app processes, and version changes. The strongest upstream evidence is a reproducible path plus a useful backtrace; if neither is available, report verified environment and honest uncertainty.

**Do not upload core files** to GitHub or Canonical without explicit review of sensitive process memory and a suitable private diagnostic channel.
