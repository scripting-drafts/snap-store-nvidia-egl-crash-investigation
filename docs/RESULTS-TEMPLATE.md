# Test results (copy per test run)

Upstream: https://github.com/ubuntu/app-center/issues/2271

| ID | Date/time (timezone) | Procedure | CPU affinity | Renderer **verified?** | Runs | Crashes | New dump/PID | Observations |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T0 | 2026-10-28 (earlier capture) | `coredumpctl info 40117` | N/A | N/A | N/A | 1 historical | 40117 | Core metadata reported present, 19.3 MB |
| T1 | 2026-10-28 (time not recorded) | Original `./scripts/analyze-core.sh 40117` (core export + unrestricted GDB) | N/A | N/A | 1 | N/A | No new dump confirmed | **System hung while script executed**; GDB installation did not hang; exact internal stage unknown. Limited retry not yet performed. |
| T2 | 2026-10-28 19:26–19:27 (console clock) | `snap run snap-store` | Default (not independently verified) | Impeller OpenGLESSDF reported; actual GPU unverified | 1 | **Not established** | Not checked | 98 gRPC `UNAVAILABLE` errors for ratings.ubuntu.com; 25 `UnmountedRefException`s; GTK and Flutter teardown warnings; no SIGSEGV in console. See [launch details](T2-LAUNCH-2026-10-28.md) and related issue [#2121](https://github.com/ubuntu/app-center/issues/2121). |
| T3 | Pending | Affinity A/B | Exclude 2,8 after topology check | Not verified | — | — | — | — |
| T4 | Pending | Renderer isolation | Default | Not verified | — | — | — | — |
| T5 | Pending | Kernel/RAS correlation | As recorded | N/A | — | — | — | — |
| T6 | Deferred | Version comparison | As recorded | Document | — | — | — | — |

## Reproduction checklist

- Snap Store was/not already open:
- Start and end timestamps with timezone:
- Exact UI steps:
- Snap Store revision/channel:
- GPU driver and kernel version:
- Desktop protocol (X11/Wayland):
- CPU affinity and topology:
- Rendering path verified by (method):
- Crash/exit status and reproduction count:
- New `coredumpctl` entry (PID, timestamp):
- `journalctl`/NVIDIA Xid/MCE/EDAC observations:
- GDB top frames, fault instruction and effective address:
- Confounders (version changes, other programs, reboot):
- Evidence sanitized for sharing (yes/no):
- Conclusion **supported** by observations:
- Remaining uncertainty:
