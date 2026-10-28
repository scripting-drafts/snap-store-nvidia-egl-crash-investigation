# Upstream issue draft: Riverpod provider disposed during ratings failures

**Target:** https://github.com/ubuntu/app-center/issues/new/choose

**Proposed title:** App Center: UnmountedRefException in ratingsModelProvider during repeated ratings API failures

## Is there an existing issue for this?

I searched the current app-center issues. The ratings-service connection errors are already reported in [#2121](https://github.com/ubuntu/app-center/issues/2121), but I did not find a report specifically for the Riverpod `UnmountedRefException`.

## Bug description

During a `snap run snap-store` launch on Ubuntu 22.04.5 LTS, App Center printed repeated errors indicating that its Riverpod `ratingsModelProvider` attempted to use a `Ref` after the provider had been disposed. The same run contained numerous gRPC connection-refused errors for `ratings.ubuntu.com`.

These are simultaneous observations; the log does not prove the network failures caused the provider lifecycle errors. Incomplete cancellation or mounted-state checking of asynchronous provider work is a possible explanation, not a confirmed cause.

## Steps to reproduce

1. On the environment described below, run `snap run snap-store` in a terminal.
2. Load or navigate app listings.
3. Watch the terminal for `ratingsModelProvider`, `GrpcError` and `UnmountedRefException`.

Observed in **one** captured run on 2026-10-28, around 19:26–19:27 local time. A deterministic minimal reproduction sequence and repetition rate are not yet known.

## Actual behavior: excerpts

```text
ERROR error_observer: Provider ratingsModelProvider(eclipse) failed
    UnmountedRefException: Cannot use the Ref of ratingsModelProvider(eclipse) after it has been disposed. This typically happens if:
    - A provider rebuilt, but the previous "build" was still pending and is still performing operations.

ERROR error_observer: Provider ratingsModelProvider(kubectl) failed
    UnmountedRefException: Cannot use the Ref of ratingsModelProvider(kubectl) after it has been disposed.

ERROR error_observer: Provider ratingsModelProvider(gimp) failed
    GrpcError: gRPC Error (code: 14, codeName: UNAVAILABLE, message: Error connecting: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = ratings.ubuntu.com, port = 38730, details: null, rawResponse: null, trailers: {})
```

The supplied console log included 25 `UnmountedRefException` occurrences and numerous ratings-service failures. Other messages included GDK `gdk_device_get_axis` assertions, cancelled snap downloads, and Flutter teardown warnings:

```text
embedder.cc (2615): 'FlutterEngineRemoveView' returned 'kInvalidArguments'. Remove view info was invalid. The implicit view cannot be removed.
WARNING: Attempted to set message handler on an FlBinaryMessenger without an engine
```

The relationship of these teardown warnings to the provider errors is not established.

## Expected behavior

Asynchronous provider work must not use disposed Riverpod references. If the ratings API is unavailable, App Center should handle this without `UnmountedRefException`, e.g. by cancelling stale work or checking `ref.mounted` after asynchronous gaps.

## Environment

- Ubuntu 22.04.5 LTS (Jammy), x86_64
- Kernel `6.8.0-138-generic`; X11
- Snap Store `0+git.5534399d`, revision `1468`, channel `latest/stable/ubuntu-22.04`
- GeForce RTX 2080 Ti, NVIDIA driver 550.163.01
- Flutter Impeller backend reported as `OpenGLESSDF`
- Launch command `snap run snap-store`

## Related issues and evidence

- [#2121](https://github.com/ubuntu/app-center/issues/2121): ratings API gRPC failures (possibly separate issue).
- [#2271](https://github.com/ubuntu/app-center/issues/2271): previous native NVIDIA EGL SIGSEGV on this host. No new native crash has been established from this launch.
- [Detailed T2 baseline analysis](https://github.com/scripting-drafts/snap-store-nvidia-egl-crash-investigation/blob/main/docs/T2-LAUNCH-2026-10-28.md).

The UI's final state (still usable, deliberately closed, or exited unexpectedly) is not established from the console output alone. No new coredump was confirmed.
