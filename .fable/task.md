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
