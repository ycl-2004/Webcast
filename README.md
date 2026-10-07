<p align="center">
  <img src="Webcast/Assets.xcassets/AppIcon.appiconset/appicon-watercolor.png" alt="Webcast watercolor television and casting icon" width="120" height="120">
</p>

<h1 align="center">Webcast</h1>

<p align="center">
  <strong>Open a web video on your iPhone, cast it to Chromecast, and control it from your phone.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-source%20build-111111" alt="Source build; no public binary release">
  <img src="https://github.com/ycl-2004/Webcast/actions/workflows/ci.yml/badge.svg" alt="CI unit tests">
  <img src="https://img.shields.io/badge/iOS-16.0%2B-111111?logo=apple&amp;logoColor=white" alt="iOS 16.0 or later">
  <img src="https://img.shields.io/badge/version-0.1.1%20%282%29-111111" alt="Current build 0.1.1 (2)">
  <img src="https://img.shields.io/badge/SwiftUI-WKWebView-F05138?logo=swift&amp;logoColor=white" alt="Built with SwiftUI and WKWebView">
  <img src="https://img.shields.io/badge/Google%20Cast-4.8.6-111111" alt="Google Cast SDK 4.8.6">
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#features">Features</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="https://github.com/ycl-2004/Webcast/issues">Feedback</a> ·
  <a href="README.zh-TW.md">繁體中文</a>
</p>

Webcast is a native iOS browser and Chromecast remote for watching web videos on a larger screen. Open a website, play a video, and choose a detected stream to send to the TV. The TV fetches the stream directly; the phone handles browsing and playback controls.

> **Current distribution:** source build only, with no App Store, TestFlight, or downloadable binary release. Release **0.1.1 (2)** with the new watercolor icon was built, signed with an Apple Development / Personal Team account, and installed on an iPhone 15 on **2026-10-07**. The user reported successful TV playback. Individual controls, lock-screen behavior, and Wi-Fi recovery still need acceptance testing. [Validation record](artifacts/validation.md).

## Quick start

First [build and install Webcast](#build-from-source) using your own Apple signing account. For an installed copy:

1. Connect your iPhone and Chromecast or Google Cast-enabled TV to the same Wi-Fi. Allow Webcast's **Local Network** permission.
2. Open the **`浏览器`** tab, enter a website, and start playing a video. The default home page is 爱壹帆; you can change it in **`设置`**.
3. Tap **`视频`** at the bottom. Prefer **`当前视频`**, or compare the title, duration, and source before selecting a candidate.
4. Tap **`投到电视`** and choose your TV if it is not connected yet.
5. Open **`投屏遥控`** for playback, seeking, volume, mute, and stopping.

If a stream fails, replay the video in the browser and select a fresh candidate. A video working on the phone does not guarantee that the TV can fetch it.

### System requirements

- iOS 16.0 or later; the current signed build was installed on an iPhone 15.
- Chromecast or a Google Cast-enabled receiver, connected to the same Wi-Fi.
- Local Network permission for device discovery and casting.
- Internet access for web pages and remote video sources.
- The current interface uses Simplified Chinese. An iPad target is configured, but physical iPad acceptance has not been recorded.

## Why Webcast

- **Browse where the video lives.** Use a native web view instead of copying stream URLs into a separate player.
- **Choose what reaches the TV.** Inspect detected candidates and their source before casting.
- **Keep the phone useful.** Browsing, video selection, and the remote share one app.

## Features

**Browser**

- URL entry and Google or Bing search, back/forward navigation, refresh, and a configurable home page.
- Desktop-site requests, new-window blocking, and startup choices.
- Local website data with a setting to clear it and sign out of websites.

**Video detection**

- Detect native media and media requests in the page and its frames.
- Identify HLS and MP4 candidates; display current-video status, source, duration, and live information when available.
- Preserve signed URL parameters, remove duplicate candidates, and disable candidates identified as DRM-protected.
- Label inferred MSE candidates separately; **`可能是正片`** is an estimate, so check the source and duration.

**Chromecast remote**

- Discover receivers and select a TV.
- Play/pause, seek, jump 15 seconds, change volume, mute, stop, and disconnect.
- Show connection and playback status, including loading and interrupted sessions. These controls are implemented; complete physical-device acceptance is still pending.

## How it works

`Website → detected media URL → selected Chromecast receiver → direct stream playback`

Webcast sends the chosen URL and media metadata to Google's Default Media Receiver. It does not mirror the phone's screen or proxy the video through the phone.

**`断开连接`** disconnects the phone without requesting a playback stop. **`停止并断开`** requests that the TV stop and then disconnects. The two actions are kept separate.

## Screenshots

<table>
  <tr>
    <td align="center"><strong>Apple HLS detection demo</strong><br><img src="artifacts/sniffer-demo.jpg" alt="Earlier simulator build detecting Apple's HLS demo with casting disabled in validation mode" width="260"></td>
    <td align="center"><strong>Web video candidates</strong><br><img src="artifacts/iyf-sniffer.jpg" alt="Earlier simulator build showing a playing 爱壹帆 video and separate HLS and MP4 candidates" width="260"></td>
  </tr>
</table>

These checked-in captures came from an earlier simulator build on 2026-10-07. They show real WebKit video detection; some browser controls and copy have since changed. They are not evidence of TV playback. Casting was disabled for these validation captures. [Capture context](docs/FEASIBILITY.md).

## Privacy

- Webcast has no app account or project-operated backend. Settings, the last visited URL, and the last selected tab are stored locally.
- WebKit stores website cookies, cache, and other website data on the device. **`设置 → 清除网站数据`** clears that data and the saved last URL; websites then require login again.
- Opening pages and searching contacts the chosen website or search engine. Casting sends the selected media URL, title, and source host to the receiver, which fetches the media from its origin.
- Google Cast SDK analytics logging is disabled in the app configuration. Release builds also disable detailed SDK debug logging.
- Websites, search providers, media hosts, and Google Cast components have their own network and data behavior. Webcast is not an offline app and does not make their traffic private.

## Current build

**0.1.1 (2)** is the current version in [`project.yml`](project.yml). It includes the browser, video detection, Chromecast remote, settings, and watercolor app icon.

| Evidence | Result |
| --- | --- |
| Signed iPhone Release build | Built and signature-verified; installed on iPhone 15 |
| Automated validation | 20 passed, 0 failed, 0 skipped; recorded before the icon-only change |
| Actual TV playback | User-reported success; source and individual control results were not recorded |
| Public distribution | No published binary, App Store, or TestFlight release |

See the [validation record](artifacts/validation.md), [implementation review](artifacts/review-2026-10-07.md), and [receiver acceptance checklist](docs/FEASIBILITY.md). The icon update did not change app behavior; tests were not rerun for that asset-only update.

## FAQ

<details>
<summary>Why does the video play on my phone but fail on the TV?</summary>

The receiver fetches the URL independently. A website may require browser cookies, request headers, a current signed URL, or DRM authorization that the receiver does not have. Replay the video and try a fresh candidate. Webcast currently has no relay or proxy for these cases.

</details>

<details>
<summary>Why is my TV missing?</summary>

Confirm that it supports Google Cast, is powered on, and shares the phone's Wi-Fi. In iOS Settings, allow Webcast to access the local network, then reopen the device picker. AirPlay-only and DLNA-only receivers are not supported.

</details>

<details>
<summary>Why does a Personal Team installation expire?</summary>

Personal Team provisioning profiles expire after seven days. Rebuild and reinstall with your signing account when needed. Release is the build configuration, not an App Store distribution certificate. [Apple's Personal Team explanation](https://developer.apple.com/help/account/basics/about-your-developer-account/).

</details>

## Build from source

<details>
<summary>Requirements, local signing, build, and validation commands</summary>

Use a Mac with Xcode and the iOS SDK, plus XcodeGen on your `PATH`. This project has been built with Xcode 27.0. Google Cast is pinned to `SRGSSR/google-cast-sdk` **4.8.6**; the first build needs network access for dependencies.

```sh
git clone https://github.com/ycl-2004/Webcast.git
cd Webcast
make generate
open Webcast.xcodeproj
```

For device installation, sign in under **Xcode Settings → Apple Accounts**, select your team, and leave automatic signing enabled. Pair and trust the phone, and enable Developer Mode.

Create `Config/Signing.local.xcconfig` with your Xcode Team ID:

```text
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
```

Create `.device.mk` with your phone's UDID:

```make
DEVICE_UDID := <YOUR_DEVICE_UDID>
```

Both files are ignored by Git. Replace the placeholders with your own values. Regenerating the Xcode project preserves these local settings.

```sh
make build           # Unsigned simulator Release
make release         # Unsigned physical-device Release; does not install
make device-build    # Signed physical-device Release; does not install
make device-install  # Build and install; does not launch the app
make device          # Build, install, and launch the app
```

Run tests using an installed iPhone simulator:

```sh
make test SIMULATOR='iPhone 16 Pro'
```

To open the bundled HLS demo, first boot a simulator and use its UUID:

```sh
make demo SIMULATOR_ID='<BOOTED_SIMULATOR_UUID>'
```

The default build, Run, Profile, and Archive configurations are Release; tests explicitly use Debug. Tests and the demo use `WEBCAST_OFFLINE_VALIDATION=1` to skip Cast SDK initialization and TV commands. This disables casting, not web-page networking. Demo and inspection tools are compiled out of Release.

The existing records verify simulator builds/tests and signed device build/install on the development machine. Setup with another Apple account or a clean Mac has not been tested.

</details>

## Project layout

| Path | Responsibility |
| --- | --- |
| `project.yml`, `Makefile`, `Package.resolved` | Xcode generation, builds, and pinned dependencies |
| `Webcast/Browser/`, `Webcast/Views/` | Browser state and native interface |
| `Webcast/Sniffer/`, `Webcast/Models/` | Media detection, candidate ranking, and URL rules |
| `Webcast/Cast/` | Device discovery, sessions, media loading, and remote controls |
| `Webcast/Assets.xcassets/`, `artwork/` | App icon, preserved original, and generation brief |
| `Tests/Swift/` | Unit and real WebKit integration tests |
| `docs/`, `artifacts/` | Feasibility, acceptance, screenshots, and validation evidence |

## Versioning and releases

Update `CFBundleShortVersionString` and `CFBundleVersion` in `project.yml`, then run `make generate` to refresh `Webcast/Info.plist` and the generated project. Keep documentation aligned with the actual build.

There are currently no release tags or published install artifacts. Local signing files, device identifiers, generated projects, and app bundles stay outside Git. Public iOS distribution requires a separate signing and release setup.

## Contributing

[Report an issue](https://github.com/ycl-2004/Webcast/issues) with the iOS version, receiver model, website, steps, and expected result. Remove cookies and temporary signed media URLs from reports. See [License](#license) before reusing or distributing the source.

## Known limitations

- Direct receiver playback only: no screen mirroring, AirPlay, DLNA, local proxy, or background audio keep-alive.
- Some sites and special players cannot be detected or played; supported candidates may still fail receiver authentication or format checks.
- DRM detection is best-effort. An unmarked candidate is not proof that a stream is DRM-free.
- Subtitles, queues, ad filtering, browsing history, and bookmarks are not implemented.
- Individual remote actions, specified 爱壹帆 episodes, lock-screen recovery, Wi-Fi recovery, and physical iPad use are not fully verified.
- Personal Team installations need periodic re-signing; no automatic updater or public binary release is provided.

## License

No project license has been selected, and this repository contains no `LICENSE` file. Public source availability does not grant permission to copy, modify, redistribute, rebrand, or sell the project. Dependencies retain their own licenses.
