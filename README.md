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
sudo apt update
sudo apt install gdb

# 1. Capture current metadata and crash details in a private local directory.
./scripts/collect-evidence.sh

# 2. Extract the existing core and create a GDB report.
./scripts/analyze-core.sh 40117
```

The analysis script searches `coredumpctl` for the specified PID, uses the executable reported for the saved crash, and writes both the core and GDB output to `./artifacts/` (ignored by Git). A missing or inaccessible core produces an error rather than a fabricated report.

Read **the entire** `artifacts/snap-store-40117-gdb.txt` and the [test plan](docs/TEST-PLAN.md). If GDB has no NVIDIA function symbols, a backtrace may show only addresses; this is still useful evidence but limits conclusions.

## Planned experiments (not yet performed)

1. **Core forensics:** faulting thread, registers, mapped libraries, disassembly, and full backtrace; check whether a null-derived dereference can be demonstrated.
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
