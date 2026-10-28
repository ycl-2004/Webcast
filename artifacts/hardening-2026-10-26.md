# Webcast 输入加固与真实 Chromecast 验证

日期：2026-10-26。终态版本：**0.1.2 (4)**。基准为包含上轮未提交修改的工作区；未回退既有修改。备份位于 `/tmp/webcast-before-hardening-2026-10-26`。本轮未提交、推送或发布。

## 已完成的改动

1. **隔离原生检测桥。** 网页环境保留 fetch/XHR 和媒体 source 观察；DOM 播放状态、生命周期与原生 handler 移至 `WKContentWorld.defaultClient`。网页无法直接读取 generation 或调用该 handler。页面转发消息不能携带 current、frame ID、generation 或生命周期命令，只能提供校验后的媒体观察。
2. **原生字段和资源预算。** 白名单校验键名、类型、枚举、UTF-8 字节与总长度，拒绝嵌套/未知字段；签名 URL 参数保持原样。全局和各 frame 的媒体预算与生命周期预算分开；100 个 frame 预算、100 条延迟最新观察和既有 100 个候选上限。列表以 50 ms 合并刷新，超预算只保留各 frame 最新观察，清理事件会撤销延迟数据。
3. **保留正确的媒体语义。** SPA 路由从真实 location 同步，拒绝旧路由转发；保留 detached preload、iframe、缓存返回等识别。缓存提交后通过原生查询隔离环境中的已签发 generation，再重放观察，避免提交/恢复事件顺序丢失候选。选片权限与暂停上下文从即时模型读取，避免使用延迟显示的旧列表状态。
4. **连接等待有明确出口。** 前台连接/恢复等待 30 秒后显示错误并取消排队投屏；SDK 仍负责恢复，不伪造“已断开”。后台停止等待，回前台可重新计时；保留“停止并断开”恢复入口。新增状态已本地化。
5. **可重复的接收端验收。** 增加独立 `WebcastReceiverAcceptance` scheme 与 [手动运行脚本](../scripts/run_receiver_acceptance.py)。普通 `Webcast`/CI 测试保持离线；真实设备套件没有指定 receiver ID 时跳过，脚本要求 `--allow-control`，不自动更新 Apple 账户签名资源。

实现与取舍见 [ADR 003](../docs/decisions/003-isolated-detection-and-receiver-qa.md)。涉及 `VideoSniffer`、`SnifferPayload`、`BrowserModel`、`CastManager`、`CastConnectionWait` 及少量状态界面；本轮没有添加字幕、队列、代理、后台保活、Wi-Fi Direct 或新电视协议。

## 本轮终态验证

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| iOS 18.6 / iPhone 16 Pro 模拟器 | **86 passed / 0 failed / 0 skipped** | [最终摘要](hardening-2026-10-26/full-ios18-final.json) |
| iOS 26.5 / iPhone 17 Pro 模拟器 | **86 passed / 0 failed / 0 skipped** | [最终摘要](hardening-2026-10-26/full-ios26-final.json) |
| 模拟器 Release 编译与实际包检查 | **Passed，0.1.2 (4)** | [包检查](hardening-2026-10-26/release-bundle.json) |
| arm64 设备 Release 编译与实际包检查 | **Passed，未签名、未安装** | [包检查](hardening-2026-10-26/device-release-bundle.json) |
| 当前 CastManager → 真实 Chromecast | **通过 HLS 播放与遥控；发送端为 iOS 26.5 模拟器** | [原生验收](hardening-2026-10-26/receiver-final.json)、[测试摘要](hardening-2026-10-26/receiver-final-summary.json) |
| Mac Python → 同一真实 Chromecast | **HLS 播放、时间推进、暂停、seek、恢复、音量、静音、停止通过** | [协议测试](hardening-2026-10-26/receiver-hls.json) |
| 清理后接收端只读检查 | 待机背景、音量恢复到 1.0、非静音，无测试媒体播放 | [状态](hardening-2026-10-26/receiver-final-state.json) |
| 安全/生命周期定向回归 | 31 passed，在修复隔离改造带来的回归后通过；最终全量已覆盖 | [摘要](hardening-2026-10-26/lifecycle-fixed-ios18.json) |
| 源码与范围核对 | 最终源文件哈希、相对本轮基准的变更清单保留 | [快照](hardening-2026-10-26/source-snapshot.json)、[变更](hardening-2026-10-26/changed-files.json) |

测试环境为 Xcode 27.1。新增八项安全/状态测试覆盖超长和嵌套字段、枚举/类型校验、URL 参数保留、全局与 frame 预算、清理预算、连接等待、网页桥不可达、转发消息不能提升 current、未知恢复代次拒绝、跨 world fetch 和即时选片状态（部分项目在同一用例中）。普通回归使用受控 HTML 和模拟事件，不能替代真实解码或电视画面观察。

Release 包检查覆盖实际版本、脚本/隐私清单/语言资源、无重复 Objective-C 类以及无离线验证/调试标记和测试包。构建未签名，不表示 iPhone 可直接安装。终态脚本、测试、配置与包内 `sniff.js` 哈希需保持一致；最终收尾核对记录在任务文件中。

## 电视端实际验证到了什么

本机发现并连接了一台真实 Chromecast；测试前它处于待机背景。首先通过独立 Python 客户端测接收端，再通过当前 iOS `CastManager` / `MediaLoader` 测实际 SDK 会话和命令。后者依次确认：发现、连接、匹配 HLS 加载确认、媒体位置推进、暂停、seek 到约 30 秒、恢复、静音切换、停止、还原音量和断开。测试使用低音量，结束后清理自己的播放。

这验证了真实 receiver 的协议状态和当前代码的投屏核心；尚没有用户对画面/声音的确认，也没有通过手机 UI 从网页选片到投屏的完整实机流程。不能据此宣称所有站点、iPhone 锁屏、短断网、长时间播放均通过。待逐项完成 [ACCEPTANCE.md](../docs/ACCEPTANCE.md)。

第一次 MP4 使用 Google 官方示例地址，接收端保持 IDLE；独立 HTTP 检查两个 Google 存储地址均返回 **403**。改用返回 200 的 Apple HLS 后成功。这是具体片源失败证据，不是“MP4 不支持”或“App 不能投屏”的证据。本轮未找到可用替代 MP4 后继续投放，不将 MP4 标为通过。[首次协议结果](hardening-2026-10-26/receiver-protocol.json)。

## 中间失败与修正

- 首轮新增安全测试 6/7 通过；新夹具在遍历关联的 WebKit userScripts 集合时回写同一控制器，出现 trap，之后重建对象的版本仍因集合迭代不断增长而停滞。采样确认测试进程内存增长，随即停止本任务测试进程。最终夹具改为固定 setup + source，不再枚举/写回同一集合。失败与停止记录保留；没有把这些运行当成功。[初次摘要](hardening-2026-10-26/initial-security-failure/summary.json)。
- 修正隔离环境的异步调用时，一次误改了既有 IndexedDB 夹具调用，导致编译错误；已恢复原调用。没有削弱业务断言来通过测试。
- 第一次全量回归抓到缓存返回、detached preload 与 block scope 的 `scan`/`announceFrame` 问题，部分夹具因此报错/中断。修正作用域、保留 page source hooks、增加原生提交后的缓存握手后，31 项定向及两套 86 项最终回归通过。
- 独立 receiver runner 最初遇到构建产物目录和本机旧格式 xctestrun 差异；脚本已显式设置 Products/Intermediates 路径，并支持两种 xctestrun 结构。
- 首次原生设备匹配错误地把 SDK `uniqueID` 与 mDNS UUID 比较，造成“发现超时”；官方文档确认 uniqueID 包含类别前缀，改用 `sdkDevice.deviceID` 后发现 1 台并完成验收。该错误属于新增 QA 夹具，原 App 的记忆设备逻辑继续使用 uniqueID。[官方字段定义](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_device)。

原始日志、结果包和采样片段包含本机路径、设备标识或 Debug SDK 信息，仅本地保留在被 Git 忽略的 `artifacts/private/hardening-2026-10-26/`；公开摘要不包含完整签名媒体 URL、Cookie 或个人设备名。成功计数以最终摘要为准，中断结果不计为成功。

## iPhone 当前卡在哪里

iPhone 15 已配对且可用，但签名构建报错：没有 `dev.yc.Webcast` 的可用开发 provisioning profile。Xcode 建议的 `-allowProvisioningUpdates` 会更新 Apple 开发者账户中的签名资源。自动审批明确拒绝了这一步，理由是现有测试授权未明确涵盖开发者账户/共享签名资源修改。

本轮没有重试、绕过拒绝或修改账户资源，也没有把 build 4 安装到手机。已经完成独立接收端、iOS 模拟器发送端、离线回归与未签名 Release 验证。若用户明确批准更新当前 Apple 团队的开发 provisioning 配置，再继续签名、安装并运行 iPhone → Chromecast 验收。

## 保留的边界与后续

- 网站仍能控制 DOM、触发媒体行为、伪造网络观察；frame ID 仍是 bookkeeping，当前视频/MSE 标签不是安全授权或已解码证明。投屏继续需要用户操作。桥隔离没有消除消息进入原生回调前的 IPC/反序列化成本。
- 本轮没有完成完整洪泛 CPU/内存基准、2 小时 soak、故意路由器断网、权限拒绝恢复、iOS 16、真实 iPad、VoiceOver 或全 UI 自动化。资源上限经过测试，不等于这些负载指标已验收。
- HTTP/局域网媒体策略、无痕/关闭历史、固定主电视、首次权限向导、字幕/队列/续播及 CI 系统矩阵仍是后续工作。当前已有“一键连接上次电视”；没有重复开发第二套 Wi-Fi 投屏。
- 未安装、未发版，原手机版本不因本地编译而变更。真实 receiver 测试不替代 iPhone 实机发布验收。

## iPhone 安装续作（2026-10-26）

用户对明确的签名配置/安装请求回复“允许安装”。随后使用现有团队完成自动签名，签名与包检查通过，安装前为 0.1.1 (2)，安装后已从手机元数据确认 **0.1.2 (4) Release**。profile 包含目标手机且有效至 2026-11-02；业务源码未变。当前启动停在 iOS 开发者信任，用户已收到手机设置操作说明，真机 receiver 验收尚未执行。[安装收据](iphone-2026-10-26.json)。上文的“未安装/待签名批准”描述属于该续作之前的历史状态；以本节为当前状态。

## 真实 iPhone → Chromecast 验收完成（2026-10-26）

用户完成开发者信任并确认可打开 App 后，使用真实 **iPhone 15 / iOS 26.5** 运行独立验收套件：**1 passed / 0 failed / 0 skipped**。发现、连接、HLS 加载确认、时间推进、暂停两次、seek 约 30 秒、恢复、静音切换、停止、音量恢复和断开全部通过。发送端和接收端这次都是真实设备。[脱敏验收结果](iphone-receiver-2026-10-26.json)。

测试完成后，已把 Debug 测试宿主还原为签名 **0.1.2 (4) Release**，从手机元数据核对版本，并通过 devicectl 确认启动成功。只读检查确认电视待机、音量/静音恢复到测试前状态。[最终安装收据](iphone-2026-10-26.json)、[清理状态](iphone-receiver-cleanup-2026-10-26.json)。本节取代前文“真机待信任/待测试”的历史状态。

本轮通过终端/Xcode 驱动真实手机的 App/SDK 会话与命令，没有把自动化误述为人工点击完整 UI。手机网页选片到投屏的全 UI、肉眼画面/声音确认、锁屏、Wi-Fi 故障恢复、持续播放仍未完成；业务源代码未变化。
