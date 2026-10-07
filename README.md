# Webcast

iPhone 网页视频投屏 App：打开网页，播放视频，再投到 Chromecast；手机可控制播放、进度和音量。

**当前版本：0.1.1 (2)，签名 Release 已安装到 iPhone 15。20 项测试通过；用户已在电视上实测播放成功。遥控、锁屏和 Wi-Fi 恢复仍待逐项验收。** 详见 [验证记录](artifacts/validation.md) 和 [本轮检查](artifacts/review-2026-10-07.md)。

## 使用

1. 手机与电视连接同一 Wi-Fi。
2. 在「浏览器」打开爱壹帆或其他网站，选集并播放。
3. 点底部「视频」，选择「当前视频」或时长、来源相符的条目，再点「投到电视」。未连接时会先选择电视。
4. 在「投屏遥控」控制播放、进度、音量和停止；「断开连接」只断开手机，「停止并断开」同时停止电视播放。

投屏失败时，回到网页重新播放，再获取视频地址。部分网站需要 Cookie、请求头或 DRM 授权，电视无法直接使用这些条件；手机网页能播放不代表电视一定能播。MSE 的「可能是正片」是推断结果，请核对时长和来源。[接收端待验收事项](docs/FEASIBILITY.md)。

「设置」可调整主页、搜索引擎、桌面网站和启动位置；清除网站数据后需重新登录。

## 构建与安装

需要 Xcode、iOS SDK 和 XcodeGen。最低 iOS 16；Google Cast 固定为 `SRGSSR/google-cast-sdk` 4.8.6。首次构建需联网下载依赖。

```sh
make generate
open Webcast.xcodeproj
make build    # 模拟器 Release
make release  # 真机 Release 编译，不签名、不安装
```

工程默认 Run、Profile、Archive 均使用 Release；测试明确使用 Debug。

### 自己的 iPhone

在 Xcode Settings → Apple Accounts 登录账号，选择 Personal Team，并保持自动签名。手机需信任此 Mac、启用开发者模式。

本机配置已保存在 Git 忽略的 `Config/Signing.local.xcconfig` 和 `.device.mk`；重新生成工程不会丢失团队。其他机器可分别写入：

在 `Config/Signing.local.xcconfig` 写入 `DEVELOPMENT_TEAM = <Xcode 中的 Team ID>`，在 `.device.mk` 写入 `DEVICE_UDID := <手机 UDID>`。

```sh
make device-build    # 仅构建签名 Release
make device-install  # 构建并安装，不启动
make device          # 构建、安装并启动；请自行确认已准备使用电视
```

Personal Team 的安装配置有效期为 7 天，到期需重新构建安装。Release 是编译配置；本次使用 Apple Development 签名，并未发布 App Store。需要免每周重签的分发方式时，另行配置相应的开发者账号与分发签名。[Apple 说明](https://developer.apple.com/help/account/basics/about-your-developer-account#Enable-a-personal-team-in-Xcode)。

### 本地验证

```sh
make test SIMULATOR='iPhone 16 Pro'
make demo SIMULATOR_ID='<已启动模拟器 UUID>'
```

测试使用 Debug 和 `WEBCAST_OFFLINE_VALIDATION=1`，跳过 Cast SDK 初始化，避免自动重连或控制电视。`make demo` 额外打开内置 HLS 示例。上述环境开关、WebKit 检查和 SDK 调试日志均不在 Release 中生效。

## 实现与限制

- WKWebView 覆盖主页面与子框架；原生媒体源、fetch/XHR、MIME 和 HLS 正文用于检测。
- 保留签名 query，按去除 fragment 的地址去重；换页隔离旧候选，SPA 导航重置列表。
- `blob:` 和非 HTTP(S) 地址不进入列表；已识别的 DRM 条目禁用投屏，未标记不代表一定没有 DRM。
- Default Media Receiver 直接拉流；当前没有本地代理或后台音频保活。网站替换网络 hook、特殊播放器或缺少类型的无后缀地址可能无法检测。
- 字幕、队列、广告过滤、历史和书签保留为后续范围。

项目入口：`project.yml`（工程）、`Webcast/Browser`（浏览器）、`Webcast/Sniffer`（检测）、`Webcast/Cast`（会话与遥控）、`Webcast/Views`（界面）、`Tests/Swift`（单元与真实 WebKit 集成测试）。

实现依据：[Google Cast 接入](https://developers.google.com/cast/docs/ios_sender/integrate)、[设备发现与权限](https://developers.google.com/cast/docs/ios_sender/permissions_and_discovery)、[SDK 包版本](https://github.com/SRGSSR/google-cast-sdk/blob/4.8.6/Package.swift)、[WKUserScript](https://developer.apple.com/documentation/webkit/wkuserscript)。
