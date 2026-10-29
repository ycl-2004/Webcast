# YC README and GitHub release — 2026-10-28

## Intent
Apply yc-readme to both READMEs, build and verify Webcast 0.1.2 (4), and upload a GitHub release with honest signing/install boundaries.

## Append-only requirements
- R1 Audit/update README.md and README.zh-TW.md against yc-readme, repository facts and the Orbit/YC Todo references; keep localized prose Traditional Chinese.
- R2 Freshly build simulator and arm64 device Release artifacts; validate actual bundles and package without local signing/provisioning data.
- R3 Upload/publish the requested GitHub release and verify downloadable asset names, content and checksums.
- R4 Preserve unrelated local evidence and app source; run relevant documentation/release checks and report outstanding device/signing limits.
- R5 User explicitly authorizes committing and pushing the remaining current repository changes; preserve generated raw test evidence locally.

## Decisions
- Current main 35be7a5 matches origin/main; successful CI run 40733499670 covers current app/test source.
- User explicitly requests release build/upload. Scope includes release documentation, commit/push of those changes and GitHub publication; no Apple account/signing changes or device control.
- Publish v0.1.2 as a prerelease: unsigned arm64 IPA (own signing required), simulator ZIP and SHA256SUMS. No App Store/TestFlight distribution is configured. Private signed phone artifact is excluded.
- Preserve completed prior task verbatim in .fable/history.md (already untracked at start).

## Evidence
- Repository/remote/version/privacy/permission/build scripts, prior acceptance receipts and both reference READMEs inspected.
- GitHub auth verified outside sandbox; sandbox-only auth errors were access restrictions. Public repo has no releases/tags.

## Status
In progress: fresh Release builds, packaging and documentation/release preparation.

## Verification progress
- Fresh make check-release and make release both succeeded; both actual bundles passed scripts/verify_bundle.py.
- Created unsigned arm64 IPA, ad-hoc signed arm64/x86_64 simulator ZIP, SDK OSS notices, release-manifest.json and SHA256SUMS. ZIP CRC/layout/hash checks passed; no .mobileprovision, app development signature, __MACOSX or .DS_Store in device package.
- Extracted simulator archive installed and launched via XcodeBuildMCP on iPhone 16 Pro / iOS 18.6. Screenshot showed live browser UI; no receiver control or new hardware acceptance performed.
- Both README files, localized parity, release notes, 52 local links/anchors, Python syntax and exact app/test/build source identity against successful CI/build-source commit verified.
- Scoped local commit b048444 contains only README.md, README.zh-TW.md, docs/releases/0.1.2.md and scripts/package_release.py. Unrelated evidence and prior history remain unstaged.
- GitHub draft release 427097711 created; three small assets uploaded, two binary uploads still running.
- Automatic approval review rejected pushing b048444 to default main because release build/upload authorization does not explicitly include default-branch changes. No push/bypass occurred. User approval question is pending; unaffected release verification continues.

## Remote documentation and transfer progress
- Default main remains unchanged. Safe alternative approved by automatic review: pushed scoped b048444 to release/v0.1.2-docs and opened draft PR https://github.com/ycl-2004/Webcast/pull/2. Main-update permission question remains pending.
- Release draft target changed to b048444 so its source snapshot includes the updated READMEs and packaging recipe. Product-source hashes remain identical to build commit 35be7a5.
- Bulk upload made no visible progress on large assets and was stopped. Individual HTTP/1.1 gh IPA transfer completed successfully; a concurrent fallback request returned 422 already_exists and did not replace anything. Server IPA digest matches local SHA256SUMS.
- Four completed server assets have exact matching sizes and SHA-256 digests. Final simulator ZIP uses a bounded curl transfer; credential only in stdin memory, no credential logging/argv/files.
- PR CI 40754631220 simulator tests passed; Release verification in progress.

## Publication approval and result
- Automatic review initially rejected public publication/tag creation as exceeding upload-only authorization. Asked the user explicitly; user replied "yes aprove". Treated this as approval for the latest public-publication request; default-main push remains pending separately.
- Published https://github.com/ycl-2004/Webcast/releases/tag/v0.1.2 as a prerelease with five verified uploaded assets.
- Remote tag v0.1.2 and release/v0.1.2-docs both point to b048444; remote main remains 35be7a5.
- PR CI https://github.com/ycl-2004/Webcast/actions/runs/40754631220 completed successfully for b048444: simulator tests and Release bundle verification both passed.
- Downloading all published assets to private evidence directory for independent checksum/ZIP verification.

## Final verification / requirement results
- R1: yc-readme audit/update complete for English and Traditional Chinese READMEs; public tagged documents match local files and return HTTP 200. Release notes and recipe included. PR #2 remains draft because default-main approval is pending.
- R2: fresh simulator/device Release builds, actual-bundle verification, ad-hoc staged simulator signing, profile exclusion, ZIP layout/CRC and SHA checks passed. Extracted simulator app installed/launched; no new phone/receiver operations.
- R3: published v0.1.2 after explicit user approval; all five server-side digests/sizes match local packages. Public page and asset URLs verified from metadata. Downloaded manifest, SHA256SUMS and notices match byte-for-byte. Optional full binary re-download intentionally stopped due slow connection; partial binaries retained privately, not counted as verified downloads.
- R4: current PR CI completed successfully; final source hashes, documentation links, diff whitespace and scope checks passed. Existing untracked evidence/history preserved. Task-owned upload/download processes stopped/completed; no secrets logged.
- Evidence receipt: artifacts/private/release-2026-10-28/receipt.json. Published metadata/public-link checks and raw build logs retained in the same private directory.

## Final status
Completed requested README preparation, Release builds and verified GitHub upload/publication. R1–R4 are satisfied with the stated evidence boundaries. PR #2 has since been squash-merged as 158e876 on origin/main; its tree exactly matches local release commit b048444. No App Store/TestFlight/signing-account operation performed. Full binary re-download and new physical-device acceptance were not completed; server digest validation and prior receiver boundaries remain explicit.

## Commit/push follow-up — 2026-10-28
- User explicitly requested committing and pushing any current repository changes, including the default branch update.
- Fetched origin and verified PR #2 is already merged; attach the remaining evidence commit to current origin/main while preserving the tagged release commit.
- Commit the task ledger, verbatim prior task history and retained source patch. Ignore nested raw test logs and xcresult bundles, consistent with the existing local-only raw evidence policy.
- No app source changed. Verify credential patterns, diff whitespace, ignored artifacts, commit scope and remote/local HEAD equality after push.
- Pre-commit checks: credential-pattern scan passed; history includes the previous tracked task verbatim; metadata whitespace and raw-output ignore rules passed. The source patch parses successfully and is preserved byte-for-byte; its unified-diff context whitespace is excluded from outer diff whitespace checks.
