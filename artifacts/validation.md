# Observed validation — 2026-10-07

Xcode 27.0; Google Cast SPM 4.8.6 (revision 887df6bfbae15e2887556a7268806649ead37fe9); iPhone 16 Pro simulator / iOS 18.6.

## Automated and build verification

Latest XcodeBuildMCP test summary after browser/dialog/data-clear fixes:

```text
Overall Result: Passed
Total: 20
Passed: 20
Failed: 0
Skipped: 0
Expected Failures: 0
```

Covers signed URLs, ranking, DRM metadata, media builders and SDK selectors; actual WKWebView native media, iframe, fetch/XHR; explicit localhost/Unicode URLs, reserved search characters, settings application, IndexedDB removal after document unload, once-only prompt completion, and bounded WebKit process recovery. Website-data tests used nonpersistent stores; user browsing data was not cleared.

- Debug tests used `WEBCAST_OFFLINE_VALIDATION=1`; Cast SDK initialization and TV commands were disabled.
- Final signed physical-device Release build: `BUILD SUCCEEDED`; no Swift compiler warnings.
- App metadata: `dev.yc.Webcast`, version `0.1.1`, build `2`, `WebcastBuildConfiguration=Release`, development region `zh_CN`.
- No `*.debug.dylib` or `*.xctest` in the Release package. Binary checks found no `WEBCAST_DEMO`, `WEBCAST_OFFLINE_VALIDATION`, `[GCK]`, `openDemo`, or `debugTools` markers.
- `codesign --verify --deep --strict`: passed outside the restricted sandbox. The first sandbox-only verification could not access certificate trust and was not a package defect.
- Signature Team ID: `BQYHJCCRMP`; Apple Development / Personal Team; profile expires **2026-10-14 14:28:29 UTC**. `get-task-allow=true` reflects development signing despite Release optimization; this is not App Store distribution.
- `devicectl device install app`: success. Exact-bundle query on the connected iPhone 15 reported `Webcast / dev.yc.Webcast / 0.1.1 / 2`.
- Old Xcode Debug session was stopped before replacement. **Release was not launched; no TV connection or command was sent.**
- Retained local installable package: `artifacts/Release/Webcast.app` (ignored by Git; not part of a checkout). Personal signing/device settings are local and ignored by Git.
- JS syntax, Info.plist lint, local documentation links, Makefile install-only recipe, and final diff whitespace checks passed.

## Earlier visual and feasibility evidence

Simulator launch used offline mode. Existing screenshots show the Apple HLS demo and 爱壹帆《仙逆》第一集 playing inside WKWebView, with the current HLS candidate and duration 25:42:

- [爱壹帆 detection](iyf-sniffer.jpg)
- [HLS demo](sniffer-demo.jpg)

Chrome displayed `Dining room TV — Available`; no device was selected. This proves Mac discovery only.

## User television test and read-only follow-up

On 2026-10-07, after installing Release, the user reported that television playback worked. This is user-observed success; the agent did not launch or control the television. The source video, receiver and individual remote actions were not identified, so this is not recorded as complete 爱壹帆 or recovery acceptance.

Read-only `devicectl` checks after the phone was reconnected:

- Exact-bundle query still reported `dev.yc.Webcast / 0.1.1 / 2`.
- Webcast-filtered process query returned no running process at inspection time; no relaunch was performed.
- `systemCrashLogs` filtered by Webcast returned **0 files**. This is a scoped absence of matching reports, not proof that every system diagnostic is error-free.
- Listing `Library/Logs` failed because no such directory was available; the parent Library listing filtered by Logs succeeded with **0 files**. Source confirms Release disables detailed GCK output and has no persistent application log writer, so the previous playback cannot be reconstructed from app logs.
- No source behavior changed in this follow-up; the existing 20/20 test result applies. JS syntax, plist lint, diff whitespace and documentation-link checks were repeated. A credential-pattern scan found no private keys or common access-token patterns in commit candidates. Local signing/device settings, the .app and temporary device JSON outputs remain outside Git.

## App icon phone update

On 2026-10-07 the user requested the new watercolor icon be installed on the phone. `make device-build` produced a signed Release successfully, and strict signature verification passed. The compiled device icon was decoded and visually confirmed as the new TV/play/casting artwork. `devicectl device install app` succeeded on the connected iPhone 15; an exact-bundle query confirmed `dev.yc.Webcast / 0.1.1 / 2`. The current installable package is `.build-device/Build/Products/Release-iphoneos/Webcast.app` (ignored by Git); the earlier `artifacts/Release/Webcast.app` package predates the icon change. Webcast was not launched and no TV commands were sent. The phone's home screen was not visually inspected. No source behavior changed, so the existing 20/20 test result was retained without rerunning the tests.

## README validation

The English and Traditional Chinese READMEs were rewritten using the YC README house style and verified against source/configuration, the signed Release build/install and existing 20/20 test evidence. Checked 32 local links/images/anchors; all documented Make targets passed dry-run checks, including install-only behavior. Both files rendered with GitHub's Markdown API, with navigation targets matching the rendered headings and all images carrying alt text. All five badge image URLs returned HTTP 200. Apple's current account overview confirmed Personal Team provisioning expiry. JS syntax, Info.plist lint, icon JSON parsing, diff hygiene and commit-candidate credential-pattern checks passed. No code tests were rerun for documentation and icon changes; setup on a clean Mac or another signing account remains unverified.

## Open acceptance

Individual remote controls, a specified 爱壹帆 episode, lock-screen and Wi-Fi recovery remain unverified. See [feasibility](../docs/FEASIBILITY.md) and [review / cleanup evidence](review-2026-10-07.md).
