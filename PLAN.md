# Webcast — 自用无广告的网页视频投屏 App（iPhone → Chromecast）

## Context（为什么做）

用户家里电视通过 Chromecast 观看视频，但 iPhone 上目前只有 YouTube 能投。
市面上的「Web Video Cast」能投网页视频，但广告太多、连接不稳。
目标：给自己做一个干净、稳定的替代品——内置浏览器打开网页 → 嗅探视频地址 → 投到 Chromecast → 手机变遥控器。

**主要目标站点：iyf.tv（动漫站，HLS 流）。投屏目标：仅 Chromecast。**

## 已确认的决策（用户拍板）

| 决策点 | 结论 |
|---|---|
| 主要目标站 | iyf.tv，先保证它 100% 好用 |
| 投屏目标 | 仅 Chromecast（Default Media Receiver），架构留扩展口 |
| MVP 范围 | 最小闭环：打开网页 → 投屏 → 遥控。字幕/队列/广告过滤后加 |
| 开发者账号 | 免费 Apple ID（7 天有效期重签，Xcode 免费签名即可） |
| UI 语言 | 中文 |

## 技术现实与风险（先说清楚）

- Chromecast 播放时**电视端自己拉流**（不是手机转发），URL 必须电视可直接访问。
- **DRM 流投不了**：Chromecast 本身支持 Widevine，但网页里的授权（license）流程拿不出来，同类 App 一样做不到。
- **⚠️ 头号风险：iyf.tv 的流能不能被 Default Media Receiver 直接播。** 下面三项任一不过就播不了：
  1. **Referer 校验 / 短时效 token**：Default Media Receiver 不能带自定义请求头。
  2. **CORS**：DMR 播 HLS/DASH 时在电视端用 XHR 拉播放列表和分片，服务器必须返回 `Access-Control-Allow-Origin`（渐进式 MP4 不需要）。CDN 若只放行 iyf.tv 来源，电视端直接失败。bipbop 返回的是 `ACAO: *`，所以 bipbop 能播不代表 iyf 能播。
  3. **分片格式**：部分站把 TS 分片伪装成 `.png/.jpg`（前面加图片头），站内播放器会剥掉，DMR 不会。若是 AES-128 加密，密钥地址也要满足上面两条。
- 「Web Video Cast 能投 iyf」**不能**当证据：它有自家的 custom receiver 和经手机转发的代理选项，它能投不代表 DMR 能投。
- **验证方式**：实施第 0 步不写代码，用 `curl` + `catt` 直接测，结论决定 MVP 范围：

  | 第 0 步结果 | MVP 怎么做 |
  |---|---|
  | `catt` 直投 iyf 的 m3u8 能播 | 按原方案，不做代理 |
  | 被 Referer / CORS / 伪装分片挡住 | 本地代理**进 MVP**（iyf 是主目标，必须 100% 好用） |
  | DRM 加密 | 停下来，重新评估目标站 |

- **本地代理的代价**（若进 MVP）：
  - 要改写 m3u8，把所有分片地址也改成走手机，流量全部经手机转发，不再是电视自己拉流；
  - iOS 锁屏/切后台后 App 会被挂起，本地服务器跟着停 → 电视断流。需要后台保活方案（自用可考虑后台音频模式），并单独验证锁屏场景。
- YouTube 不做——Chromecast 原生支持。

## Approach（推荐方案）

**官方 Google Cast iOS Sender SDK + Chromecast 自带 Default Media Receiver，我们只做「浏览器 + 嗅探 + 遥控器」。**

- Google Cast SDK 4.8.6（要求 iOS 15+）：设备发现（mDNS）、TLS 连接、心跳、会话恢复全托管——「连接稳定」交给 Google 的协议栈，不自己撸 CASTV2/protobuf。
  - 接入方式：推荐 SPM 包 `SRGSSR/google-cast-sdk`（xcodegen 原生支持 SPM），备选 CocoaPods `google-cast-sdk`。版本钉死 4.8.6。
  - SDK 本身是官方的，但 Google 没发 SPM 包，上面的 SPM 包是第三方封装。`castlabs/google-cast-spm` 只更新到 4.8.4，不用它。
- 嗅探：WKWebView + documentStart 注入 `sniff.js`，**`forMainFrameOnly: false`**（播放器常在跨域 iframe 里）。两条路都要覆盖：
  - **原生播放路**：hook `HTMLMediaElement.src` setter、`setAttribute('src')`、`<source>` 子元素。iPhone 上很多站不走 MSE（iOS 17.1 前没有 MSE，之后是 ManagedMediaSource，要看站点 hls.js 版本），直接 `video.src = xxx.m3u8`，这个请求由系统媒体栈发出，XHR/fetch hook 抓不到。
  - **MSE 路**：hook `XMLHttpRequest`/`fetch`（hls.js 拉播放列表走这里）。此时 `video.src` 是 `blob:`，必须过滤掉。
  - 识别：URL 后缀（`.m3u8/.mp4/.mpd`，允许带 query）+ 响应 Content-Type（`application/vnd.apple.mpegurl`、`application/x-mpegURL`）+ 响应内容以 `#EXTM3U` 开头。
  - 去重排序：主列表（含 `#EXT-X-STREAM-INF`）优先于各清晰度子列表；标记挂在当前 `<video>` 上的那条，和片头广告区分开。
  - WKWebView 没有观察子资源请求的公开 API，嗅探只能靠 JS hook。
- UI：SwiftUI，iOS 16+，双 Tab（浏览器 / 投屏遥控）。广告过滤（WKContentRuleList + EasyList China）放 Phase 2。

## Files to create（全新项目）

```text
webcast/
├── project.yml                 # xcodegen 工程定义（避免手写 pbxproj）
├── Webcast/
│   ├── WebcastApp.swift        # 入口 + GCKCastContext 初始化
│   ├── Info.plist              # NSLocalNetworkUsageDescription + NSBonjourServices（_googlecast._tcp、_CC1AD845._googlecast._tcp）
│   ├── Views/
│   │   ├── BrowserView.swift   # Tab1: WKWebView + 地址栏 + 后退/刷新
│   │   ├── RemoteView.swift    # Tab2: 遥控器（播放/暂停/进度/音量/断开）
│   │   ├── DevicePicker.swift  # Chromecast 设备列表 + 连接状态
│   │   └── SniffSheet.swift    # 嗅探到的视频列表 + 一键投屏
│   ├── Cast/
│   │   ├── CastManager.swift   # GCKCastContext/SessionManager 封装 + 状态机
│   │   └── MediaLoader.swift   # GCKMediaInformation 构建（HLS 用 application/x-mpegurl，TS 分片按需设 hlsSegmentFormat/hlsVideoSegmentFormat）+ load/play/pause/seek/volume
│   ├── Sniffer/
│   │   ├── VideoSniffer.swift  # WKScriptMessageHandler：接收 sniff.js 上报 + 去重排序
│   │   └── sniff.js            # 注入脚本（video src / XHR / fetch hook，过滤 blob:，上报）
│   └── Proxy/                  # 仅当第 0 步判定需要代理时才建
│       └── LocalProxy.swift    # NWListener：改写 m3u8 + 分片转发补请求头
└── PLAN.md
```

## Reuse（不重复造轮子）

- **Google Cast iOS SDK** — 发现/连接/协议/重连全托管
- **Default Media Receiver** — 电视端播放器零开发（支持 HLS/MP4/DASH，无需注册，App ID `CC1AD845`）
- **`catt`**（Cast All The Things，Python CLI）— 第 0 步在 Mac 上直接把 URL 投到电视，默认走 Default Media Receiver，不写代码就能验证可行性
- **Apple bipbop 公开测试流**（`devstreaming-cdn.apple.com/.../bipbop...m3u8`）— App 的第一个投屏验证目标（只证明投屏链路通，不证明 iyf 能播）
- EasyList China 规则 — Phase 2 广告过滤

## Steps（实施清单）

- [ ] 0. ⚠️ 可行性验证（不写代码，先做）：
  - Mac 浏览器打开 iyf.tv 某一集，DevTools Network 记下主列表、子列表、分片地址；
  - `curl` 测：带/不带 Referer；加 `-H "Origin: https://www.gstatic.com"` 看有没有 `Access-Control-Allow-Origin`；隔 10 分钟重试看 token 时效；看分片 Content-Type 和开头字节（TS 以 `0x47` 开头，PNG 头说明是伪装分片）；看有没有 `EXT-X-KEY`；
  - `catt cast <主列表地址>` 投到电视实测；
  - iOS 模拟器 Safari + Mac Safari Web Inspector 打开 iyf，看 iPhone 上播放器走的是 MSE 还是原生 `video.src`（决定嗅探主力是哪条路）；
  - 按「技术现实与风险」里的表格出结论：不做代理 / 代理进 MVP / 停下重评。
- [ ] 1. 骨架 + 真机跑通：project.yml + xcodegen 生成工程，SPM 接入 Cast SDK（钉 4.8.6），Info.plist 本地网络权限 + 两条 Bonjour 声明；iPhone 打开开发者模式，免费签名装上空壳 App
- [ ] 2. CastManager：设备发现 → 连接 → 断开，状态机（未连接/已连接/播放中），中文化错误提示
- [ ] 3. 最小投屏闭环：真机投 bipbop 测试流 → 电视出画面（同时确认本地网络权限弹窗和设备发现正常）
- [ ] 4. RemoteView 遥控器：播放/暂停/Seek/音量/停止断开，UI 中文
- [ ] 5. BrowserView：WKWebView + 地址栏 + 后退/刷新 + 加载进度
- [ ] 6. 嗅探：sniff.js 注入（video src / XHR / fetch 两路 hook，覆盖 iframe）→ 原生去重排序列表
- [ ] 7. （仅当第 0 步判定需要）本地代理：NWListener 起服务，改写 m3u8 让分片也走代理并补请求头，加后台保活
- [ ] 8. ⚠️ 关键实测：iyf.tv 真实视频 → 嗅探 → 投屏 → 电视播放（在 App 里复现第 0 步的结论）
- [ ] 9. 打磨：嗅探结果浮层交互、锁屏回来自动恢复会话、投屏中顶部常驻状态条
- [ ] 10. 真机全流程验收（注意免费签名 7 天到期要重签）

## Verification（怎么验收）

所有验收都在真机（免费签名）上做。

0. 第 0 步有明确结论：`catt` 直投 iyf 能播，或已确定被哪一项挡住、代理已进 MVP
1. 启动 App → 弹出本地网络权限 → 列出家里电视的 Chromecast 设备名
2. 投 bipbop 测试流 → 电视出画面，播放/暂停/拖进度/调音量全部正常
3. **真实场景**：App 内打开 iyf.tv → 选集 → 嗅探列表出现 m3u8（主列表排在前面、没有 `blob:`、能和片头广告区分）→ 点投屏 → 电视播放，手机遥控正常
4. 稳定性：投屏中锁屏 30s 回来 → 会话自动恢复；Wi-Fi 短暂波动 → SDK 自动重连
5. 若启用了本地代理：投屏中锁屏 5 分钟，电视不断流

## Phase 2（MVP 之后， backlog）

- 广告过滤（WKContentRuleList + EasyList China 规则）
- 外挂字幕（SRT → VTT 转换 + text track）
- 播放队列（连播选集）
- 书签/历史、桌面模式 UA 切换
- 本地代理：是否进 MVP 由第 0 步决定；若 iyf 不需要，留给以后接其他站点时再做

## 实施状态（2026-10-07）

- 用户追加边界：不得直接连接 Chromecast；仅扫描设备。Chrome 已显示 `Dining room TV — Available`，未选择设备。
- 工程、Cast 接入/遥控、浏览器、双路嗅探、中文浮层与会话状态条已实现；SDK 固定 4.8.6。
- iPhone 16 Pro / iOS 18.6 模拟器构建、启动和 14 项测试通过。App 内《仙逆》第一集实际出画面，并检测到当前 HLS（25:42），与 MP4 条目分开。
- 第 0 步未关闭：独立流请求被 Cloudflare 403 拦截，电视播放尚未授权测试；代理必要性未确定。
- 原清单中的真机、电视播放和稳定性验收仍保持未勾选。iPhone 构建尝试被执行环境沙箱阻断，未签名、未安装真机。
- 运行方式见 [README.md](README.md)，逐项证据和待验收项见 [docs/FEASIBILITY.md](docs/FEASIBILITY.md)。
