# Snap Store / NVIDIA EGL crash investigation

A reproducible investigation workspace for a Snap Store `SIGSEGV` observed on Ubuntu 22.04.5 LTS with the NVIDIA 550.163.01 graphics driver.

**Upstream Canonical issue:** [ubuntu/app-center#2271 — Snap Store crashes with SIGSEGV in NVIDIA EGL library 550.163.01](https://github.com/ubuntu/app-center/issues/2271)

> **Status:** The crash and retained core dump have been confirmed. Root cause and deterministic reproduction are **not yet established**. This is a diagnostic companion repository, not a proposed upstream fix.

## Confirmed observations

| Item | Evidence |
| --- | --- |
| Crash | 2026-10-27 16:04:13 CET; process `snap-store`, PID `40117`, signal `SIGSEGV` (11) |
| Fault | Address `0x1278`, x86 page-fault error code `4` (user-mode read of non-present page) |
| Faulting mapped module | `libnvidia-eglcore.so.550.163.01` (kernel report) |
| Running CPU | Reported CPU 9 (core 4, socket 0); does **not** establish hardware causation |
| Core | `coredumpctl info 40117` reported **Storage: ... (present)**, compressed size 19.3 MB |
| Application | `snap-store` `0+git.5534399d`, revision `1468`, track `latest/stable/ubuntu-22.04` |
| System | Ubuntu 22.04.5 LTS, kernel `6.8.0-138-generic`, x86_64, X11 |
| GPU | NVIDIA GeForce RTX 2080 Ti, driver 550.163.01 |

The kernel fault site is not proof that the driver contains the original defect: upstream callers, toolkit integration, memory corruption, or hardware can also be involved.

See [case details](docs/CASE-2271.md), [test plan](docs/TEST-PLAN.md), and [results template](docs/RESULTS-TEMPLATE.md).

## Quick start

Run these commands **on the affected Ubuntu system** (not on another computer). Required tools: `systemd-coredump` utilities (`coredumpctl`), `gdb`, and standard Linux utilities.

```bash
# Metadata-only, no GDB or decompression (recommended after a hang).
./scripts/analyze-core.sh 40117

# Optional: collect system metadata; may invoke nvidia-smi and journal queries.
./scripts/collect-evidence.sh

# ONLY if the host is responsive and you accept resource-limited processing:
# ./scripts/analyze-core.sh 40117 --extract
# ./scripts/analyze-core.sh 40117 --gdb
```

**Safety update (2026-10-28, user-confirmed):** Running the **previous** `./scripts/analyze-core.sh 40117` caused the system to become unresponsive. The preceding `sudo apt install gdb` did **not** cause the hang. The exact point inside the script (core export versus GDB startup/analysis) remains undetermined. Do not rerun the old script. The updated default only reads `coredumpctl info` with a 15-second timeout and does not start GDB or extract a core. `--extract` and `--gdb` are opt-in, require memory/CPU/time/file-size caps in a systemd user scope, and refuse to fall back to unbounded execution when resource controls are unavailable. The core can expand far beyond the 19.3 MB compressed file. These controls reduce risk, **not guarantee** responsiveness. If the machine becomes unresponsive again, stop immediately rather than increasing limits.

The opt-in analysis writes files under `artifacts/` (ignored by Git). It uses a shallow fault-thread backtrace, not `thread apply all bt full`. Collect basic evidence first and use a separate noncritical host for deeper debugging if necessary.

If an opt-in GDB run succeeds, inspect and redact `artifacts/snap-store-40117-gdb.txt` before sharing. No GDB report from the hanging run has been verified. See the [test plan](docs/TEST-PLAN.md).

## Planned experiments (not yet performed)

1. **Core forensics:** metadata first; only if safe, opt-in shallow backtrace, registers, and faulting instruction. Defer all-thread/full-variable traces to a separate analysis environment.
2. **Reproduction:** record the exact UI action and frequency, or establish that no deterministic procedure exists.
3. **CPU-affinity A/B:** compare normal launch with a launch excluding the *previously suspected* logical CPUs 2 and 8, after rechecking topology. This is **correlation**, not a hardware diagnosis.
4. **Graphics isolation:** compare the normal NVIDIA EGL path with a *verified* alternative rendering path; setting `LIBGL_ALWAYS_SOFTWARE=1` is only an exploratory attempt and may **not** change the backend for a snap.
5. **Kernel/RAS evidence:** check for NVIDIA Xid events and MCE/EDAC records correlated to each attempt.
6. **Escalation:** attach a **reviewed, sanitized** trace and result matrix to the upstream issue; avoid uploading a full core publicly.

See the [test matrix and interpretation rules](docs/TEST-PLAN.md) before running experiments.

## Privacy and scope

Core dumps can contain process memory, usernames, environment variables, tokens, downloaded content, and other sensitive information. **Never commit or publicly upload raw cores.** Outputs in `artifacts/` are git-ignored; inspect and redact any backtrace/log before sharing it. A private GitHub repository is still not an automatic guarantee that a raw core is safe to upload.

A coredump's presence does not imply the associated `journalctl -k` lines are still available after reboot or journal rotation; in the supplied diagnostic output, a later time-window kernel journal query returned `-- No entries --` while `coredumpctl` retained the crash.

## Upstream interaction

Record new findings in [ubuntu/app-center#2271](https://github.com/ubuntu/app-center/issues/2271), ideally as a small, redacted summary plus steps to reproduce. Reference this repository as the investigation log, not as proof of a driver or hardware defect.

## Project layout

```text
.
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   ├── CASE-2271.md
│   ├── TEST-PLAN.md
│   └── RESULTS-TEMPLATE.md
└── scripts/
    ├── analyze-core.sh
    ├── collect-evidence.sh
    ├── gdb-commands.gdb
    ├── launch-with-affinity.sh
    └── publish-to-github.sh
```

License: MIT. This repository provides investigation procedures; it does not distribute NVIDIA drivers or Ubuntu application binaries.
