# Webcast implementation

## Goal
Implement the iPhone browser → video detection → Chromecast → remote MVP from PLAN.md, with observable validation and honest device acceptance status.

## Acceptance criteria and append-only requirements
1. Follow PLAN.md: iOS 16+, SwiftUI, Chinese, Google Cast 4.8.6, Default Media Receiver, XcodeGen.
2. Investigate iyf playback feasibility before deciding whether a proxy belongs in the MVP.
3. Implement real browser, native and MSE detection across frames, deduplication/ranking, Cast session/load/control and errors.
4. Build and run the software; provide reproducible setup and validation evidence. Do not equate simulation with TV playback.
5. Added 2026-10-07: Do not connect to Chromecast or send any playback/control commands during agent work. Physical acceptance is deferred.
6. Added 2026-10-07: Scan only for Dining Room TV. Complete: Chrome's Cast device picker displayed “Dining room TV — Available”; no device was selected.

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
- Final tests: 14 passed, 0 failed, 0 skipped, iPhone 16 Pro / iOS 18.6. Includes real WKWebView opaque-origin iframe, fetch and XHR, and SDK optional selector checks. The latter caught and corrected a silently missing session-resume callback.
- Native Device Hub UI: demo HLS candidate shown, Cast action disabled in offline mode. artifacts/sniffer-demo.jpg.
- Native Device Hub UI: real iyf 仙逆-01 plays in App; current chunklist.m3u8 (25:42) appears separately from an MP4. artifacts/iyf-sniffer.jpg.
- iPhone device builds were attempted without signing; sandbox rejected SwiftPM cache writes and macro plugin sandbox execution. No device compile/installation acceptance is claimed; diagnostics in artifacts/device-*.log.

## Outstanding
- Software implementation and simulator validation complete. make generate, JS syntax, plist lint, local documentation links and file whitespace checks passed; final regenerated project simulator build passed.
- Step 0 receiver playback, iPhone signing/install, real television flow and lock-screen/Wi-Fi acceptance: deferred by requirement 5.
