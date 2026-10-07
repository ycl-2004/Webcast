# Webcast

自用的 iPhone 网页视频投屏 App：打开网页、检测视频地址、手动连接 Chromecast，再用手机控制电视播放。App 本身不含广告；网站自身的广告仍会显示，过滤留在 Phase 2。

**当前状态：软件已构建并在 iPhone 模拟器运行，14 项测试通过，iyf《仙逆》第一集的原生 HLS 已成功检测并在手机页面播放。尚未安装到真实 iPhone，也未连接电视或验收电视播放。**

Chrome 扫描已显示 `Dining room TV — Available`。这只证明 Mac 的 Chrome 能发现设备，不能代替 iPhone 发现和播放验收。详细记录见 [可行性与验收](docs/FEASIBILITY.md)。

## 启动

需要 Xcode、iOS 平台 SDK 和 XcodeGen。最低 iOS 16；Google Cast 通过 `SRGSSR/google-cast-sdk` 精确固定在 4.8.6。首次构建需要联网下载 SDK。

```sh
make generate
open Webcast.xcodeproj
```

在 Xcode 选择 `Webcast` scheme 和一个 iPhone 模拟器，运行即可。新机器的模拟器名称可能不同，可用 `xcrun simctl list devices available` 查看。

### 只验证软件，不连接电视

在 Xcode 的 Edit Scheme → Run → Arguments → Environment Variables 中添加：

```text
WEBCAST_OFFLINE_VALIDATION = 1
WEBCAST_DEMO = 1
```

第一个变量会完全跳过 Cast SDK 初始化，因此设备发现、自动恢复会话、连接和遥控全部关闭。第二个打开内置的 Apple HLS 检测示例。需要验证真实网站时去掉第二个变量即可；浏览器菜单也可切换示例或 iyf。

```sh
make build
make test SIMULATOR='iPhone 16 Pro'
```

已经启动模拟器时，可用以下命令安装并启动离线示例：

```sh
make demo SIMULATOR_ID='<模拟器 UUID>'
```

Xcode 27 的本机模拟器界面位于 **Device Hub**；旧版 Xcode 使用 Simulator。当前 XcodeBuildMCP 的 `open_sim` / `snapshot_ui` 仍依赖旧入口，因此本次使用 Device Hub 检查实际界面。

### 安装到自己的 iPhone

1. 在 Xcode 的 Settings → Accounts 登录自己的 Apple Account。
2. 打开 `Webcast` target → Signing & Capabilities，选择自己的 Personal Team，保持自动签名。Bundle Identifier 如果冲突，改成自己唯一的标识。
3. 连接并信任 iPhone，按系统提示启用开发者模式，在 Xcode 选择手机并运行。
4. 仅在准备测试投屏时，移除 `WEBCAST_OFFLINE_VALIDATION`。点击右上角电视图标会扫描；**点选设备才会建立新连接**。已有投屏会话在正常模式下由 SDK 自动恢复。

Personal Team 的设备安装配置文件会在 7 天后过期，需要重新构建并安装。见 [Apple 的 Personal Team 说明](https://developer.apple.com/help/account/basics/about-your-developer-account#Enable-a-personal-team-in-Xcode)。本次没有选择签名团队、创建证书或向真实手机安装。

## 使用

1. 先连接同一 Wi-Fi 下的 Chromecast。在遥控页可手动投屏 Apple HLS 测试视频。
2. 浏览器打开 iyf，选集并播放；点击底部「视频」。
3. 优先选择主播放列表或带「当前视频」标记、时长与正片相符的条目，然后点「投到电视」。未连接时会先进入设备选择页。
4. 遥控页支持播放/暂停、进度、前后 15 秒、音量、静音和停止。「仅断开手机连接」与「停止并断开」是不同操作。

请求提交后界面显示加载状态；播放、暂停等状态以接收端的 SDK 回报为准。加载错误不会被显示成成功。视频地址可能带短期签名，过期后返回网页重新播放获取。

## 检测与限制

- `WKWebView` 在 document start 注入页面世界脚本，覆盖主页面和子框架。
- 原生路径：`video.src`、`setAttribute`、`source.src`、DOM 变化及媒体事件。MSE 路径：fetch/XHR 的 URL、MIME、HLS 响应正文。
- 保留所有签名 query；去掉 fragment 后去重，主列表优先。换页生成新的检测代次，旧页面上报被拒绝；SPA 路由会清空旧候选。
- `blob:` 和非 HTTP(S) 地址不会进入列表。MSE 的「播放器候选」只根据同框架的近期播放列表请求推断，不能保证它一定是正片；广告或预加载需要用户核对时长和来源。
- 已识别的 SAMPLE-AES / 非 identity KEYFORMAT / DASH ContentProtection 会标记 DRM 并禁止加载；这是初步检测，不能证明未标记的流没有 DRM。
- Default Media Receiver 直接从服务器拉流，无法使用网页的自定义 Referer、Cookie 或授权头。**iyf 能在手机播放，不等于电视能播。** 本地代理是否进入 MVP 仍待第 0 步实测决定；当前未加入代理或后台音频保活。
- 原生播放的无后缀 URL 若没有可观察的 `source.type`，公开 WKWebView API 无法取得它的子资源 Content-Type；网络 hook 被网站替换或使用特殊播放器时，也可能无法检测。

## 项目结构

```text
project.yml                    XcodeGen 工程和精确版本依赖
Webcast/Browser/                持久 WKWebView、导航和加载状态
Webcast/Sniffer/                JS hook、消息桥和换页隔离
Webcast/Models/                 地址校验、候选去重与排序
Webcast/Cast/                   SDK 会话状态、媒体请求与遥控
Webcast/Views/                  中文 SwiftUI 双 Tab、设备/视频浮层
Tests/Swift/                   数据规则与真实 WKWebView 集成测试
docs/FEASIBILITY.md             第 0 步发现、未完成项和真机验收表
artifacts/                     本次运行截图和本机诊断记录
```

工程可以随时重新生成；签名团队和个人 Xcode 运行设置没有写死在 `project.yml` 中。生成后如果需要长期保留个人设置，请用 Xcode 的用户 scheme，或自行设置运行环境变量。

## 实现依据

- [Google Cast iOS 接入、主线程调用与自动恢复会话](https://developers.google.com/cast/docs/ios_sender/integrate)
- [自定义设备选择器的发现启动和本地网络权限](https://developers.google.com/cast/docs/ios_sender/permissions_and_discovery)
- [媒体信息 Builder 和 HLS 分片格式](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_media_information_builder)
- [SDK 4.8.6 的 SPM 包定义](https://github.com/SRGSSR/google-cast-sdk/blob/4.8.6/Package.swift)
- [Apple WKUserScript](https://developer.apple.com/documentation/webkit/wkuserscript)

测试内容：签名 URL 保留、去重/排序、当前视频替换、MIME/正文识别、DRM 元数据、地址校验、离线模式、SDK 媒体构建和可选回调 selector；真实 WKWebView 的原生源、opaque-origin iframe、fetch 原始响应保留、blob 过滤、XHR 重用。
