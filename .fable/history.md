# Webcast task history


## Archived implementation/publication ledger (2026-10-07)

The prior software/publication work is complete; receiver acceptance remains deferred and is carried forward. Original ledger follows verbatim.

# Webcast implementation

## Goal
Implement the iPhone browser → video detection → Chromecast → remote MVP from PLAN.md, with observable validation and honest device acceptance status.

README/publication follow-up complete: the YC-style English and Traditional Chinese READMEs, app icon and validation records were committed and pushed to the user-specified repository, preserving existing history. Remaining receiver acceptance is listed below and is separate from this completed publication task.

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
18. Added 2026-10-07: Generate a phone-ready Webcast app icon matching the user's FoldPeek, Wisp, NoType and Orbit visual family, and wire it into the project.
19. Added 2026-10-07: Update the connected phone with the newly generated app icon; retain the no-launch/no-TV-command boundary.
20. Added 2026-10-07: Apply yc-readme, complete the README, and commit/push to https://github.com/ycl-2004/Webcast.git on main. Preserve existing commits and keep credentials, local signing/device settings and binary build products outside Git.

## Decisions
- No existing source or Git repository; PLAN.md is the approved spec.
- Source-pinned dependency confirmed: SRGSSR/google-cast-sdk tag 4.8.6 (GoogleCast product, iOS 16 minimum).
- Step 0 is unresolved: desktop Chrome plays 仙逆-01 through blob/MSE; observed chunklist URL returns Cloudflare HTTP 403 to independent curl. This does not prove Referer rejection, DRM, or proxy necessity.
- Proceed with independent sender/browser work. No speculative local proxy or background-audio workaround. iyf production acceptance remains open.
- Validation uses an explicit offline launch environment that does not initialize the Cast SDK, preventing automatic reconnection as well as deliberate connection.

## Evidence
- Publication follow-up (requirements 17 and 20): commit db0937150aa1d38fe29dda32f5907ffba3f67a87 (user-requested message: first commit) was pushed to origin/main at https://github.com/ycl-2004/Webcast.git. Remote main matched local HEAD; the worktree was clean and main tracked origin/main. GitHub contents API returned both READMEs with blob SHAs matching local Git. Existing commits ff47504 and 98c1874 were preserved. Local signing/device settings, credentials and binary build products remain ignored. This record is committed separately after verification.
- README follow-up (requirement 20): completed English README.md and Traditional Chinese README.zh-TW.md from current source/configuration and existing validation evidence. Checked 32 local links/images/anchors; verified version, dependency, platform and all eight documented Make targets; validated GitHub HTML formatting and navigation targets; five badge URLs returned HTTP 200. Apple Personal Team expiration was checked against Apple's current account overview. JS syntax, Info.plist, icon JSON, diff whitespace and credential-pattern checks passed. No app behavior changed, so the recorded 20/20 tests and this session's signed Release build/install evidence were reused.
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
- Phone icon update (requirement 19) complete: signed Release build and strict signature verification passed; the compiled icon was visually confirmed; devicectl installed the updated package on iPhone 15 successfully and exact-bundle query confirmed 0.1.1 (2). No App launch or TV command was performed. Current local package: .build-device/Build/Products/Release-iphoneos/Webcast.app. The home screen was not visually inspected.
- App icon follow-up (requirement 18) complete: inspected all four local reference icons; generated a cream-paper watercolor TV/play/casting icon with the built-in image tool; integrated the opaque 1024 × 1024 PNG into AppIcon. Xcode asset compilation passed (exit 0), 60 px preview inspected, original icon preserved byte-for-byte, and diff hygiene passed. Prompt and evidence: artwork/appicon-prompt.md. No phone rebuild/install or App launch was performed.
- Software implementation and simulator validation complete. make generate, JS syntax, plist lint, local documentation links and file whitespace checks passed; final regenerated project simulator build passed.
- Follow-up requirements 7–14 complete: regression review/fixes, 爱壹帆 copy, pi investigation, scoped cleanup, signed Release install, focused UI text, and preserved no-TV-command boundary.
- User has confirmed one actual television playback. Specific 爱壹帆 source, individual remote actions and lock-screen/Wi-Fi acceptance remain open; no-TV-command boundary remains for agent work. Personal Team weekly re-signing remains a maintenance constraint.
- README/publication requirements 17 and 20 are complete. The target is https://github.com/ycl-2004/Webcast.git, main, with the existing local history preserved. Both README files were verified on GitHub; publication introduced no release tag or binary distribution.


## Completed local foundation review (2026-10-18)

# Webcast foundation review — in progress

Goal: strengthen the current app's foundation and UX without receiver E2E access; implement evidence-backed improvements and preserve existing edits.

Original implementation ledger is preserved verbatim in `.fable/history.md`; its receiver/control/recovery acceptance remains deferred under the current no-E2E constraint.

Prior requirements and evidence: `artifacts/audit-2026-10-18.md` R1–R7 and `artifacts/fixes-2026-10-18.md`. Those fixes passed 34 tests on iOS 18.6 and 26.5 plus Release build before this task.

Appended user requirement R8: continue researching and implementing useful optimizations and details; verify design and foundations locally because E2E testing is unavailable.

Acceptance:
- [x] R8.1 Separate load request acknowledgement from matching receiver playback; pause only the original browser document after confirmation.
- [x] R8.2 Ignore stale/replaced/cancelled callbacks; preserve retry and loading consistency; cover state transitions without a TV.
- [x] R8.3 Prioritize current media and improve accessible layouts/touch targets without changing the visual system.
- [x] R8.4 Avoid loading unvisited browser pages at startup; isolate the test host from automatic homepage networking.
- [x] R8.5 Bundle app privacy reasons; strengthen CI with Release verification and retained test evidence.
- [x] R8.6 Run local tests on both runtimes, Release build, configuration/resource checks, and inspect local UI renders where feasible; report E2E limits.

Decisions:
- Preserve Chromecast-only direct playback; no bookmarks/subtitles/queue/proxy scope expansion.
- Use a small value-type load state and the SDK's application-created request factory for callback tests. Do not initialize a Cast context or issue receiver commands in tests.
- Delay browser pause until the load request was acknowledged AND receiver status matches the requested signed URL and is playing/paused.
- Keep handoff identity tied to browser document and URL so delayed confirmation cannot pause unrelated new content.
- Keep generic UI recovery text; no inference that all playback failures mean CORS/DRM/token expiry.

Work state: complete. Final 50 tests passed on both iOS 18.6 and 26.5; Release build and actual bundle verification passed. Three narrow/large-text component renders were exported and inspected; scrollable long content remains reachable.

Sources:
- https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_request
- https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_remote_media_client
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- https://developer.apple.com/design/human-interface-guidelines/buttons

Evidence observed: `/tmp/webcast-foundation-2026-10-18-ios18.log` passed 49 tests, SDK factory/callback naming verified by compilation. First compile failure was only the Swift spelling `failWithError`, corrected before passing run. UI renders exported from `.build/Logs/Test/Test-Webcast-2026.10.18_13-16-43--0700.xcresult` to `/tmp/webcast-foundation-renders` and visually inspected.

Final evidence: `artifacts/foundation-2026-10-18.md` and its companion directory contain both 50/50 summaries, Release bundle verification, component renders and model/sniffer outputs. CI selector smoke check and workflow parse passed locally; remote Actions were not triggered. README, decision record and final diff checked. No receiver E2E, physical-device installation, commit, push or publication performed.


---

# Webcast task status

No active implementation task.

Completed 2026-10-18: R8 local foundation improvements; both iOS runtimes passed 50/50 tests and Release bundle verification passed. See `artifacts/foundation-2026-10-18.md`.

The original implementation ledger and completed foundation requirements are preserved verbatim in `.fable/history.md`.

Deferred receiver acceptance: actual TV playback/handoff, remote controls, lock-screen and Wi-Fi recovery, minimum iOS 16 and physical iPad acceptance. These require future device conditions and explicit device-operation authorization; they are outside the completed local review.

Current source changes remain uncommitted and are not installed on the phone. No receiver command, commit, push or publication was performed in this review.


# Webcast stability and public UI review — 2026-10-18

## Intent and deliverable
Reduce avoidable work during sustained browsing, preserve correct media state across page changes, verify Cast request quality metadata locally, and simplify public-facing screens. Deliver code, regression evidence, Release verification, and an honest physical-device acceptance boundary.

## Append-only requirements
- R9.1 Bound script caches and response-reading work; do not consume or cancel the website’s original response.
- R9.2 Exercise repeated navigation, old asynchronous responses and stale document messages; preserve current-page detection.
- R9.3 Verify HLS master/signed URLs and segment metadata reach Cast without imposing a low quality variant.
- R9.4 Remove redundant product explanations and technical badges; retain actionable errors and destructive-action confirmations.
- R9.5 Run meaningful local regressions on both available iOS runtimes, inspect affected UI renders and verify the Release bundle. Do not claim actual TV quality or long-duration Wi-Fi stability from local tests.

## Decisions and evidence
- Preserve the current native SwiftUI design and all earlier uncommitted changes.
- No real receiver commands, phone install, commit, push or publication in this review.
- Confirmed inspection: `parents` cache unbounded; fetch inspection currently clones generic text/JSON/octet-stream responses without concurrency or time limits; page identity is URL-only, so A→B→A can admit an old response.
- Existing 50-test foundation baseline is recorded in `artifacts/foundation-2026-10-18.md`.

## Status
Completed locally. R9.1–R9.5 verified within the stated local scope.

## Final evidence
- iOS 18.6 and 26.5: 62 passed / 0 failed / 0 skipped on each runtime.
- Final component-only render rerun: 1 passed; six original component screenshots opened and inspected.
- `make check-release`: build and actual Release bundle verification passed; compiled English/Traditional Chinese UI copy verified.
- 200 SPA route changes, 20 document switches, 500 uncommitted navigation attempts, 260 playlist requests and hung/oversized response regressions passed.
- Source record and limitations: `artifacts/stability-2026-10-18.md`.
- Diff hygiene, structured files, local documentation links and preserved original task ledger checked.

## Remaining acceptance boundary
Actual TV long-duration playback, Wi-Fi/background recovery, measured receiver resolution/bitrate, minimum iOS 16, physical iPad and VoiceOver remain unverified. No receiver commands, phone install, commit, push or publication performed.


# Webcast remaining review fixes — 2026-10-24

## Intent
Resolve the actionable findings of artifacts/review-2026-10-24.md while preserving the existing app and uncommitted work; deliver verified source and an explicit physical-receiver acceptance boundary.

## Append-only requirements
- R10.1 Correct current-video activation, removal, source changes and frame ownership (F1).
- R10.2 Preserve surviving iframe candidates across parent routes; retire removed/navigated frames and hash-router media (F2).
- R10.3 Capture selection-time origin through connection, load and retry; provide pending-cast cancellation (F3).
- R10.4 Make foreground recovery/system-control capability explicit without adding background keep-alive (F4).
- R10.5 Increment build identity and prepare receiver acceptance; do not claim unavailable physical results (F5).
- R10.6 Add bounded local failure diagnostics without URL queries, cookies or page contents (F6).
- R10.7 Evaluate and migrate to the official pinned Cast Dynamic SPM package; verify actual bundle (F7).
- R10.8 Localize app-owned dynamic statuses/errors; preserve site titles/device names (F8).
- R10.9 Improve candidate distinction and discovery recovery; update CI/toolchain and historical docs.
- R10.10 Convert reproductions into correctness tests, run relevant regressions and Release validation; review final diff.

## Decisions
- Use the current working tree as baseline; backup at /tmp/webcast-before-fixes-2026-10-24.
- No receiver control, physical installation, commit, push or publication.
- Retain SwiftUI/WKWebView/receiver-direct playback. No proxy or feature expansion.
- The official 4.8.6 SPM wrapper produced duplicate GTMSessionFetcher runtime classes. Use a minimal local binary-only manifest pinned to Google’s archive/checksum; keep upstream-wrapper adoption deferred with evidence.
- Each frame owns its observations; parent routes do not erase surviving child frames.

## Evidence / completion
Final local verification: 2026-10-25. Source build 0.1.2 (3); Xcode 27.1; Cast 4.8.6.

| Requirements | Completion evidence |
| --- | --- |
| R10.1–R10.2 | MediaLifecycleTests, SnifferIntegrationTests and CandidateStoreTests pass; frame/media identity fixes in source. |
| R10.3 | CastIntentTests and CastLoadStateTests pass; selection origin retained through pending connection and retry; UI cancellation present. |
| R10.4 | Explicit SDK background suspension; foreground-only control boundary documented in README, ADR and acceptance checklist. |
| R10.5 | Both actual Release bundles identify 0.1.2 (3); docs/ACCEPTANCE.md distinguishes all physical checks as Pending. |
| R10.6 | CastDiagnosticTests pass; 20-entry memory limit and host-only fields verified; diagnostics render inspected. |
| R10.7 | Official binary-only package builds for simulator/device; duplicate-class gate rejects upstream wrapper and passes final bundles. |
| R10.8 | English/Traditional translations cover all 136 UI keys and the permission prompt; packaged resources and localization tests pass. |
| R10.9 | Candidate detail/recovery UI inspected; pinned CI configuration and historical docs updated. Remote workflow not run. |
| R10.10 | iOS 18.6 and 26.5 full suites each 78/78 passed; final fixture adjustment passed focused tests on both; both Release builds/bundle checks pass; final source/diff/static checks pass. |

- Results: artifacts/fixes-2026-10-24.md and artifacts/fixes-2026-10-24/.
- Failed/interrupted intermediate runs retained and explained in the report; no failure is relabelled as a pass.
- iOS 26.5 full suite predates the final test-only foreground fixture adjustment; product code and dependency unchanged. Its final focused rerun passed.
- Source/test/config snapshot and changed-file list recorded relative to the preserved task baseline.

## Status
Completed: all 10 local implementation/verification requirements addressed. Physical receiver, signing/install, iOS 16, physical iPad, full accessibility and remote CI acceptance remain external; no such actions performed. No commit, push or publication.


# Current-code review and TV connectivity assessment — 2026-10-26

## Intent
Assess security, optimization, feature expansion and sustainable testing against the current working tree; deliver an evidence-backed report and a concrete Chromecast/Wi-Fi recommendation without changing business code.

## Append-only requirements
- R1. Inspect actual source, dependency/configuration and existing test/acceptance evidence.
- R2. Identify attack surfaces, distinguish reproduced findings from unverified threats, and propose scoped fixes.
- R3. Prioritize stability/performance improvements and useful feature additions.
- R4. Evaluate and strengthen the testing plan for long-term operation.
- R5. Compare Chromecast, same-LAN Wi-Fi and peer-to-peer Wi-Fi; give implementation and hardware acceptance steps.
- R6. Continue after user interruption; retain incomplete runs honestly and preserve all pre-existing work.

## Decisions
- Existing working-tree changes are the baseline; no business source, configuration, signing, installation or receiver control changes.
- Current source/config/test snapshot (38 files) exactly matches the 2026-10-24 fix snapshot.
- Use real offline simulator regressions plus a separate macOS WKWebView probe; do not equate either with physical Cast acceptance.
- Previous completed task archived verbatim in .fable/history.md before this task record.

## Evidence
- artifacts/review-2026-10-26/tests-ios26.json: 78 passed, 0 failed/skipped.
- tests-ios18.log was interrupted by the user and is not a successful run; rerun recorded separately as tests-ios18-resumed.
- Isolated bridge probe source and build/runtime evidence in artifacts/review-2026-10-26/.
- artifacts/review-2026-10-26/tests-ios18-resumed.json: 78 passed, 0 failed/skipped.
- Probe confirmed arbitrary restored generation/current-candidate acceptance and retention of two 1 MiB metadata fields. It did not contact any receiver or demonstrate RCE/crash/automatic casting.
- Both existing Release bundles passed verify_bundle.py again; this was not a fresh Release rebuild.
- artifacts/review-2026-10-26.md delivers security findings, optimization/features, layered test gates and Chromecast/Wi-Fi implementation recommendations with source links.
- Final report local links, 38-file source/config/test hash comparison, JavaScript syntax and git diff whitespace checks passed.

## Requirement verification
- R1–R2: inspected source, configuration, dependency pins and tests; isolated reproduction results and limits recorded.
- R3–R4: prioritized improvements/features and five-layer test plan with proposed measurable release criteria recorded.
- R5: compared network transport versus playback protocol, current Wi-Fi Aware limits and concrete Cast rollout/hardware acceptance steps.
- R6: retained interrupted/initial harness failure evidence; business code unchanged; previous completed record archived verbatim.

## Status
Completed: all six review deliverables verified. Proposed fixes/features are not implemented. Current-release receiver acceptance, soak/network recovery, iOS 16, physical iPad, accessibility and remote CI remain unexecuted validation items, explicitly identified in the report. No commit, push, installation, publication or receiver control.


---

# Input hardening and authorized Chromecast acceptance — 2026-10-26

## Intent
Implement the review's first security/stability changes, verify regressions, and attempt authorized real Chromecast playback/control against current working-tree code.

## Append-only requirements
- R1 Preserve all existing changes and implement bounded, typed native media/bridge input validation.
- R2 Restrict forged restoration and cross-origin frame bookkeeping; retain explicit user casting and document any page-world trust limits.
- R3 Add native message budgets/coalesced publication and targeted security/lifecycle regressions.
- R4 Add bounded connection/recovery waiting with cancellation and truthful states, preserving SDK reconnection.
- R5 Discover the home Chromecast, attempt actual connection and safe public-media playback/control; distinguish receiver-only, simulator, and physical iPhone evidence.
- R6 Run relevant/full tests and Release validation; update usage/decision/acceptance docs and report untested hardware limits.
- R7 User approved installation in direct response to the explicit provisioning/signing/install request; use the existing team to sign/install build 4 on the newly connected iPhone, then attempt physical receiver acceptance.
- R8 User reports the trusted app now opens and authorizes relevant real computer/device operations for testing; run physical iPhone-to-Cast acceptance and restore the signed Release afterward.

## Decisions
- Work in place because current uncommitted working tree is the requested baseline; backup: /tmp/webcast-before-hardening-2026-10-26. No commits/pushes.
- User explicitly authorized connecting/testing Chromecast in this request. Use public test streams, inspect existing playback before taking over, restore volume/mute and stop own test media.
- Do not run superpowers workflows, per user instruction; existing reviewed design authorizes direct implementation.
- Detected one Cast receiver and paired iPhone 15. Discovery is not playback evidence.

## Evidence
Baseline file hashes: artifacts/hardening-2026-10-26/baseline.json.

## Evidence / work log
- Isolated bridge now uses WKContentWorld.defaultClient; page-world collector forwards only validated observations. Native typed/byte limits, separate control/media budgets, bounded deferred latest observations and coalesced publication are implemented.
- Added 30-second foreground connection/recovery wait and cancellation of pending media on timeout. Build identity is now 0.1.2 (4).
- Added seven offline security tests and a separate opt-in receiver suite, excluded from ordinary Webcast/CI tests.
- Mac Python receiver protocol test passed HLS playback, advancing position, pause, seek, resume, volume, mute/unmute and stop; original volume/mute restored. First Google MP4 URL returned HTTP 403 and was not counted as a successful playback.
- Security fixture initially mutated the controller script collection during enumeration; caused crash/resource growth. Stopped those task-owned processes, retained failure logs, replaced fixture with setup + fixed source. Seven tests subsequently passed on iOS 18.6.
- Full regression found cache-commit replay ordering, detached preload and block-scoped scan/announce regressions after isolation. Corrected native post-commit handshake, lightweight page source hooks and global helper scope; targeted verification ongoing.
- Receiver runner initially needed explicit Products paths and legacy xctestrun format support. First actual native discovery check used the wrong SDK ID; corrected to deviceID per official headers/docs.
- Physical iPhone build failed due missing provisioning profile. Auto-review rejected -allowProvisioningUpdates because developer-account signing resource changes need explicit user approval. No retry/bypass; script does not enable provisioning updates. Simulator and receiver-only verification continue.

## Final verification
- R1–R3: typed/byte-limited input, isolated native bridge, known generation restore, route-safe observations, budgets/coalescing and immediate selection context implemented. Eight added offline tests; all existing correctness assertions retained.
- R4: 30-second foreground connection/recovery deadline, error/cancellation and background timer suspension implemented/localized.
- R5: Python receiver HLS protocol test passed; final source's iOS CastManager passed the same real Chromecast using an iOS 26.5 simulator sender. Final read-only state: standby, original volume/mute restored. Phone build attempt failed for missing profile; auto provisioning update rejected, no bypass/installation.
- R6: final full suites each 86/86 passed on iOS 18.6 and 26.5; simulator and arm64 unsigned Release builds/bundle checks passed. Both bundle scripts match final source. Final locale-format restoration preserved JSON semantics and freshly compiled locale data matches verified Release resources. Report links, JS/plist syntax, diff whitespace and final source hash checks passed.
- Final receiver retest: artifacts/hardening-2026-10-26/receiver-final.json and receiver-final-summary.json. Test/source snapshot and relative-baseline patch retained.
- Raw logs/xcresult and generated bytecode moved to git-ignored artifacts/private/hardening-2026-10-26; task-owned discovery processes stopped; temporary authorized xctestrun removed.

## Status
Completed: R1–R8 core changes, installation and physical receiver acceptance. Signed Release 0.1.2 (4) is installed/developer-trusted and launch-verified on iPhone 15. Physical iPhone 15 / iOS 26.5 -> physical Chromecast core HLS controls passed; Release restored after Debug QA and receiver cleanup verified. Browser full UI, human picture/sound confirmation, lock/Wi-Fi recovery, soak, iOS 16/iPad/accessibility remain unaccepted and are documented. No commit, push or publication.

## Physical iPhone continuation
- The preceding permission question explicitly asked to update the current Apple team's development provisioning configuration, install on iPhone 15, and continue receiver tests. User replied: “允许安装，我刚才连上我的手机了，然后你可以帮我弄”. Treat this as approval for that scoped installation/signing workflow, not unrelated account changes.
- iPhone 15 is currently available/paired. Preserve the verified business source; use a separate signed build directory and private raw logs.
- R7 in progress: signed Release build, installation/version verification, then separate hardware acceptance if possible.

### R7 installation progress
- Signed Release 0.1.2 (4) built successfully using the existing team; codesign and bundle verification passed. Profile contains the connected phone and expires 2026-11-02T15:17:50Z.
- Installed version changed from 0.1.1 (2) to 0.1.2 (4), confirmed via devicectl target-app metadata.
- Launch was denied by iOS security/profile trust. User reports “Untrust”; developer trust is the immediate user action, not a failed installation. Do not automate acceptance of the trust prompt.

### Physical receiver QA start
- User reports developer trust completed and Webcast can be opened/used. Paired iPhone remains available.
- Read-only receiver preflight: standby, original volume 1.0, unmuted.
- Dedicated phone test suite was already signed/built successfully with existing configuration. Run scoped low-volume HLS controls; restore signed Release 0.1.2 (4) after the debug test host is used.

### R7–R8 completion evidence
- User completed developer trust; Release launch verified successfully after restoring final install.
- Physical iPhone 15 / iOS 26.5 -> real Chromecast: 1 test passed, 0 failed/skipped; discovery, connection, HLS matching confirmation/position, pause/seek/resume, mute, stop, restored volume and disconnect all passed.
- artifacts/iphone-2026-10-26.json records installed/reopened Release; artifacts/iphone-receiver-2026-10-26.json records core acceptance; artifacts/iphone-receiver-cleanup-2026-10-26.json confirms standby and restored volume/mute.
- App/test/config source hashes unchanged; documentation links and diff whitespace checked. Raw phone/device logs and xcresult remain git-ignored under artifacts/private/iphone-2026-10-26. Temporary authorized test specification removed.
