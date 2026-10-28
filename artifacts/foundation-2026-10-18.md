# Webcast 基础质量第二轮检查 — 2026-10-18

目标：按用户追加要求继续研究、检查和实现可验证的基础优化。当前没有真实接收端 E2E 条件；本轮只使用代码检查、SDK 本地请求对象、真实 WebKit、组件渲染和构建包检查。保留已有工作区修改，不连接电视、不安装到手机、不提交或发布。

## 要求与实现

| 要求 | 改进与依据 | 验证 |
| --- | --- | --- |
| R8.1 加载交接 | 等请求确认且接收端上报匹配签名 URL 的 playing/paused 后，才暂停原网页媒体。网页 URL 或文档已变化则忽略迟到确认。 | 状态模型、浏览器 handoff 与 SDK 请求回调测试；[决策说明](../docs/decisions/001-confirm-cast-before-pausing.md)。 |
| R8.2 状态一致性 | 旧请求、会话清理后的回调及取消/替换不再误报新操作失败。加载超过 45 秒退出等待，可重试；匹配的迟到状态仍可确认。已确认视频的播放错误保留重试。加载时禁止旧媒体进度/播放指令；离开遥控页或断线时取消音量发送任务、清除拖动状态。 | SDK applicationRequest 本地回调，旧/未知请求、取消、替换、超时、运行期失败、重试、reset 场景。 |
| R8.3 选片与界面 | 当前媒体优先，再优先 master；排序相同时按 URL 稳定排序。候选显示直播标记；暂停连接时停止提供可投屏 CTA。未知时长不再自动当直播。地址清空热区 44pt；大字体候选徽章/按钮纵排，起始页可滚动。 | 候选回归测试；320pt 窄屏和 accessibility3 组件渲染检查。没有声称完成 VoiceOver 或已连接遥控页的视觉验收。 |
| R8.4 启动与隔离 | 浏览器在首次访问时才打开主页/上次页面，避免进入遥控或设置页时自动加载网站。测试宿主使用本地起始页；各 WebKit 夹具继续使用独立设置与非持久存储。 | 延迟加载、最新主页、上次页面、只启动一次、本地起始页测试。 |
| R8.5 配置与 CI | App 单独声明 UserDefaults 的 CA92.1 原因，保留 Cast SDK 自己的清单。新增 `make check-release` 校验真正构建出来的资源、权限和 Debug 隔离。测试 target 最低版本独立设为 iOS 17，App 仍为 16。CI 使用 JSON 选设备、复用 Makefile、检查 Release 并保留 7 天测试证据。 | 清单/plist/JSON、工作流解析、CI 选择器本地 smoke test、Release 包检查。远端 Actions 未触发。 |
| R8.6 基础验证 | 对最终代码运行两套 iOS 的所有本地测试、渲染与 Release 检查，检查差异、链接和新增资源。 | 两套各 50/50 通过；Release 包检查通过；差异、链接、清单和渲染检查完成。 |

## 设计取舍

沿用原生 SwiftUI 与现有 teal 样式，不增加新的导航层级。当前视频优先解决旧广告 master 盖过正片的问题；同一页面中多个 frame 都在播放时，仍需用户结合来源和时长选择，不能假装已经实现广告识别。

交接状态与传输分开，但 Cast SDK 仍负责发现和连接。没有重写投屏协议或增加代理。保留手机播放能减少加载失败后的中断；代价是接收端确认之前可能短暂双端同时发声。取消 SDK 请求也不保证电视端操作被撤销，因此没有用它承诺“停止电视”。[Google 请求语义](https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_request)。

App 隐私清单只声明自己的本机偏好读写；第三方 SDK 的数据行为由其独立清单描述。这是源码和打包准备，不是 App Store Connect 已验收。[Apple 原因定义](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)、[清单打包位置](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)。

界面细节使用系统控件、语义字号与可滚动内容。44pt 热区遵循 [Apple 按钮指导](https://developer.apple.com/design/human-interface-guidelines/buttons)。组件渲染展示局部布局，不作为端到端交互证据。

## 本轮证据

- 首轮 iOS 18.6：49/49 通过，包括 15 项新增测试；之后补强了运行期失败重试及未知旧状态场景，最终测试数量为 50。
- 最终 iOS 18.6：**50 通过、0 失败、0 跳过**；[xcresult 摘要](foundation-2026-10-18/tests-ios18.json)。
- 最终 iOS 26.5：**50 通过、0 失败、0 跳过**；[xcresult 摘要](foundation-2026-10-18/tests-ios26.json)。
- `make check-release`：**构建与实际包检查通过**；[包检查结果](foundation-2026-10-18/release-bundle.json)。App 最低版本仍为 16.0；测试 bundle 的实际最低版本为 17.0。
- CI 工作流 YAML 解析通过；直接执行其模拟器选择代码，返回本机可用 iPhone 17 Pro 的 UUID。
- 3 张组件渲染已查看，最终测试继续生成同样的组件证据，并断言确实使用 320pt 窄视口：[普通起始页](foundation-2026-10-18/browser-start-narrow.png)、[大字体起始页](foundation-2026-10-18/browser-start-accessibility.png)、[大字体未连接遥控页](foundation-2026-10-18/remote-accessibility.png)。长内容通过 ScrollView 访问。
- SDK 工厂请求测试仅在本地构造、完成、失败或中止 applicationRequest；没有初始化 Cast context 或向接收端发送命令。
- 本轮新增 16 项 XCTest，总数从上一轮的 34 项增至 50 项。原有嗅探和候选边界夹具继续通过；[嗅探结果](foundation-2026-10-18/sniffer-result.json)、[排序与容量结果](foundation-2026-10-18/candidate-result.txt)。
- 相关文档本地链接、字符串目录 JSON、Info.plist、隐私清单和 `git diff --check` 通过。原项目任务账本已按原文归档至 `.fable/history.md`，原有要求和待验收项没有丢弃。
- 完整测试/构建日志保留在 `/tmp/webcast-foundation-2026-10-18-*`。运行中仍有 Xcode 系统版本解析和模拟器 WebKit 进程日志提示；最终 xcresult 未报告测试失败，未将这些系统输出直接判断为 App 缺陷。

## 仍需真实条件验证

真实电视接收完整加载、手机暂停时机和短暂双音、直播/未知时长、接收端是否保留内容标识、硬件音量、系统锁屏命令、应用恢复与 Wi-Fi 变化。最低 iOS 16 实机、实体 iPad、VoiceOver 和已连接状态下的完整视觉交互也不在本轮证据范围。

字幕、书签、连播、广告过滤、AirPlay/DLNA 和代理保留为产品功能取舍；现阶段优先保证现有闭环的本地基础。当前没有足够证据认定需要更换框架、升级 SDK 或重写应用。
