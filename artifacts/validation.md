# Observed validation — 2026-10-07

Xcode 27.0; Google Cast SPM 4.8.6 (revision 887df6bfbae15e2887556a7268806649ead37fe9); iPhone 16 Pro simulator / iOS 18.6.

Final XcodeBuildMCP test summary:

```text
Test Summary: Test - Webcast
Overall Result: Passed
Total: 14
Passed: 14
Failed: 0
Skipped: 0
Expected Failures: 0
```

Simulator build and run: succeeded for Webcast, dev.yc.Webcast. Every agent launch explicitly set WEBCAST_OFFLINE_VALIDATION=1. Cast SDK initialization and TV commands were disabled.

Observed in Device Hub:
- Demo: master.m3u8 detected; disabled “选择电视后投屏” button.
- iyf 仙逆-01: actual video picture in webpage; current HLS chunklist.m3u8; duration 25:42; another MP4 listed separately.

Chrome Cast menu: “Dining room TV — Available”. Device was not selected.

Syntax/resources: node --check sniff.js passed; Info.plist lint passed; sniff.js and sniffer-demo.html exist in built App bundle.

Not passed: iPhone device compilation (sandbox blocked cache/macro execution), signing/install, actual receiver loading/control, lock-screen/reconnection. See ../docs/FEASIBILITY.md.
