# Webcast implementation

## Goal
Implement the iPhone browser → video detection → Chromecast → remote MVP from PLAN.md, with observable validation and honest device acceptance status.

Current follow-up: save the stabilized Release and user-confirmed television playback after read-only phone checks; resolve the missing Git remote, then commit and push.

## Acceptance criteria and append-only requirements
1. Follow PLAN.md: iOS 16+, SwiftUI, Chinese, Google Cast 4.8.6, Default Media Receiver, XcodeGen.
2. Investigate iyf playback feasibility before deciding whether a proxy belongs in the MVP.
3. Implement real browser, native and MSE detection across frames, deduplication/ranking, Cast session/load/control and errors.
4. Build and run the software; provide reproducible setup and validation evidence. Do not equate simulation with TV playback.
5. Added 2026-10-07: Do not connect to Chromecast or send any playback/control commands during agent work. Physical acceptance is deferred.
6. Added 2026-10-07: Scan only for Dining Room TV. Complete: Chrome's Cast device picker displayed “Dining room TV — Available”; no device was selected.
7. Added 2026-10-07: Review the latest uncommitted changes for regressions and long-term stability; fix confirmed issues and run appropriate checks.
8. Added 2026-10-07: Use the correct Chinese site name “爱壹帆”.
9. Added 2026-10-07: Investigate the interrupted pi agent run and identify leftover processes without accessing Claude CLI or unrelated sessions.
10. Added 2026-10-07: Delete confirmed project temporary files and stop obsolete task processes; preserve source, session history, and current tool services.
11. Added 2026-10-07: Make Release the normal build/run configuration, verify production compilation, and exclude debug-only behavior.
12. Added 2026-10-07: Keep app wording focused on browsing, finding a video, casting, and controlling playback; retain only actionable explanations.
13. Added 2026-10-07: Preserve the no-TV-command requirement. Report the actual signing/install status separately from production compilation, without treating an unsigned build as an installed app.
14. Added 2026-10-07: The user authorized using the existing yichen.lin.2004@gmail.com Xcode account, inspecting/editing its project signing settings, and replacing the iPhone app with the signed Release build. Do not launch it or connect to the TV.

15. Added 2026-10-07: Record the user's successful television playback report without expanding it to untested source/control/recovery scenarios.
16. Added 2026-10-07: Read relevant logs/status from the connected phone without restarting the App or controlling the television.
17. Added 2026-10-07: Commit and push the reviewed current state; preserve local credentials, signing/device settings and binaries outside Git. Push destination must be resolved because no remote is configured.

## Decisions
- No existing source or Git repository; PLAN.md is the approved spec.
- Source-pinned dependency confirmed: SRGSSR/google-cast-sdk tag 4.8.6 (GoogleCast product, iOS 16 minimum).
- Step 0 is unresolved: desktop Chrome plays 仙逆-01 through blob/MSE; observed chunklist URL returns Cloudflare HTTP 403 to independent curl. This does not prove Referer rejection, DRM, or proxy necessity.
- Proceed with independent sender/browser work. No speculative local proxy or background-audio workaround. iyf production acceptance remains open.
- Validation uses an explicit offline launch environment that does not initialize the Cast SDK, preventing automatic reconnection as well as deliberate connection.

## Evidence
- 2026-10-07: Xcode 27.0 and XcodeGen available. XcodeBuildMCP lists iOS 18.6 and 26.5 simulators.
- Browser page https://www.iyf.tv/play/qXvszbfSdq5: title 仙逆-01; video currentSrc is blob. Observed playlist host sss8-e1.pipecdn.vip; signed query is intentionally not committed.
- curl response: HTTP 403, Server cloudflare, HTML response; /private/tmp/webcast-iyf-headers.txt (temporary local evidence).
- Simulator build and launch succeeded with Google Cast 4.8.6. Final Swift source produced no compiler warnings in the XcodeBuildMCP build/test output.
- Earlier baseline tests: 14 passed, 0 failed, 0 skipped, iPhone 16 Pro / iOS 18.6. Includes real WKWebView opaque-origin iframe, fetch and XHR, and SDK optional selector checks. The latter caught and corrected a silently missing session-resume callback.
- Native Device Hub UI: demo HLS candidate shown, Cast action disabled in offline mode. artifacts/sniffer-demo.jpg.
- Native Device Hub UI: real iyf 仙逆-01 plays in App; current chunklist.m3u8 (25:42) appears separately from an MP4. artifacts/iyf-sniffer.jpg.
- Earlier device builds hit sandbox/cache/macro restrictions; resolved using scoped build access. Obsolete raw logs were summarized and removed in the follow-up cleanup.

- 2026-10-07 follow-up: 20 tests passed / 0 failed / 0 skipped after address, settings, all-type data removal, dialog and crash-recovery fixes; no Swift warnings.
- Signed Release 0.1.1 (2), dev.yc.Webcast: build and strict signature verification passed; no debug dylib/test bundle/offline-demo markers. devicectl confirmed installation on iPhone 15; app was not launched.
- Existing Xcode Personal Team is BQYHJCCRMP; the previous 5AGX9CFNPL value was the certificate identity suffix. Signing is preserved in ignored local xcconfig; profile expires 2026-10-14 14:28:29 UTC.
- pi transcript ends with stopReason=aborted / Operation aborted, without evidence identifying the abort trigger. All seven registered tasks ended; four failures were masked by shell exit handling. Terminal-owned caffeinate and an obsolete simulator app were stopped, followed by the old device Debug session.
- Follow-up evidence and cleanup inventory: artifacts/review-2026-10-07.md. Existing source/screenshots and global pi session history retained.

- 2026-10-07 user follow-up: television playback succeeded according to the user's test. No specific video/receiver/control matrix supplied; do not equate this with full source/recovery acceptance.
- Read-only connected-phone checks: app 0.1.1 (2); no Webcast process at inspection time; Webcast-filtered crash report query returned 0 files; no Library/Logs directory. Release has no persistent detailed GCK logs. No App launch or TV command by agent.
- Follow-up changes are documentation only; reused the unchanged 20/20 code test result and repeated scoped static/package/diff checks before saving.

## Outstanding
- Software implementation and simulator validation complete. make generate, JS syntax, plist lint, local documentation links and file whitespace checks passed; final regenerated project simulator build passed.
- Follow-up requirements 7–14 complete: regression review/fixes, 爱壹帆 copy, pi investigation, scoped cleanup, signed Release install, focused UI text, and preserved no-TV-command boundary.
- User has confirmed one actual television playback. Specific 爱壹帆 source, individual remote actions and lock-screen/Wi-Fi acceptance remain open; no-TV-command boundary remains for agent work. Personal Team weekly re-signing remains a maintenance constraint.
- Commit/push follow-up: local commit is being prepared; destination confirmation pending because no Git remote exists.
