# Media ownership, selection-time handoff and official SDK

Status: implemented in source; receiver acceptance pending. Date: 2026-10-24.

This supplements [ADR 001](001-confirm-cast-before-pausing.md) and supersedes its load-start origin capture. Assigning a media URL is discovery, not evidence of playback. Only playback events activate a connected video element. A source change, ended/emptied event or removed element invalidates its active state. Pause preserves it. MSE association remains a labelled inference.

Each frame owns its observations. A route clears only that frame; an unchanged child frame keeps its candidates. Parent/child registration and removal events retire detached or navigated frame subtrees. Hash routes beginning with `#/` or `#!` are treated as navigation; ordinary anchors retain candidates. Full document navigation still invalidates prior generations. State and traversal are bounded to 100 frames/candidates; the last 200 retired frame IDs reject delayed reports until an explicit cache restore. Frame IDs are page-world bookkeeping, not a trust boundary; bridge messages cannot connect to or control a TV.

A cast intent now captures document identity, media revision and page URL at **selection time**, before connection. Media revisions change on source/current-video/lifecycle transitions, so returning to the same document URL cannot recreate the old context. Only the current candidate can arm local pause; a normally paused player can still be current. Pending connection and retry retain the original context. Receiver confirmation consumes the matching attempt once; any mismatch leaves local playback alone. Dismissing the picker or pressing Cancel cast clears queued media; it does not claim to cancel a command already sent to the receiver.

The tradeoff favors preserving phone playback when context is uncertain. An unrelated frame change can invalidate the global media revision and leave the phone playing after successful casting. Exact signed URL matching is unchanged. This is safer than pausing new media on a late event, and physical acceptance must assess audio overlap and receiver content identifiers.

The Cast SDK explicitly suspends in the background. Foreground recovery is supported by the SDK path but not yet accepted on hardware. System media information is cleared on suspension. No background audio mode, silent audio or relay is introduced.

Failures keep a 20-entry in-memory log: stage, numeric error code when available, timestamp, build, receiver model and URL hostname. No complete URL, title, raw NSError/userInfo, cookies or page contents enter this log. Cancelled/superseded requests are omitted. The log is manually clearable, never uploaded, and disappears with the app process. Detailed SDK logging remains Debug-only.

Dependency source moves from SRGSSR's wrapper to Google's official 4.8.6 dynamic archive, with the exact SHA-256 pinned in `Packages/GoogleCast/Package.swift`. We evaluated the official GitHub SPM wrapper first. It links GTMSessionFetcher 3.5.0 even though GoogleCast's dynamic binary already contains those Objective-C classes. Runtime logs reported duplicate classes, and inspection of the Release executable/framework confirmed them. Successful compilation alone did not catch this defect.

Use a small local binary-only SPM manifest with product `GoogleCastDynamic`; this downloads the unchanged official archive and removes the duplicate dependency. No vendor checkout is patched and no alternate binary is produced. `Package.resolved` has no remote source dependencies because the local manifest's versioned URL/checksum locks the binary. This adds responsibility for one small manifest, in exchange for avoiding the observed runtime ambiguity. Re-evaluate the official wrapper when its dependency graph changes. Release validation now compares Objective-C runtime class metadata across the app and embedded frameworks, including stripped symbols; the rejected upstream-wrapper bundle demonstrably fails this check.

`Makefile` uses a separate package cache to preserve an already modified legacy checkout. Override `PACKAGE_DIR` when needed. CI explicitly selects Xcode 26.3 and iOS 18.6 on macos-15; local validation uses Xcode 27.1. Remote CI results remain pending until a pushed workflow runs. iOS 16 is the deployment target, not a claimed tested runtime.

Sources inspected on 2026-10-24:

- [Official Cast SPM setup](https://developers.google.com/cast/docs/ios_sender)
- [Pinned official package manifest](https://github.com/googlecast/google-cast-ios-sdk/blob/4.8.6/Package.swift)
- [Background suspension option](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_cast_options)
- [GitHub macOS 15 toolchains and simulator inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
