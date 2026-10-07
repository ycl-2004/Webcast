# 可行性与验收记录

日期：2026-10-07。原始产品范围见 [PLAN.md](../PLAN.md)。

## 结论

**签名 Release 0.1.1 (2) 已安装到真实 iPhone 15；用户于 2026-10-07 确认电视实际播放成功。** 这是用户亲自测试后的反馈。Agent 没有连接电视、启动 Cast 会话或发送遥控命令；后续只读取手机的安装、进程及相关日志状态。

当前保留直接 sender，不增加代理。用户未说明本次视频来源和逐项遥控结果，因此不将这次成功扩大为所有爱壹帆流、锁屏或网络恢复均通过。

## 实测观察

| 检查 | 实测结果 | 能说明什么 |
|---|---|---|
| Mac Chrome 的 Cast 设备列表 | `Dining room TV — Available` | Mac 的 Chrome 可以发现设备；未点选设备 |
| 命令行 mDNS | `DNSServiceBrowse failed -65563` | 当前沙箱不能使用该服务，不能推断电视离线 |
| Chrome 打开《仙逆》第一集 | video.currentSrc 为 blob；资源清单含 pipecdn.vip 的 chunklist.m3u8 和 .ts | 桌面播放器走 MSE，不能只观察 video.src |
| 独立 curl，真实签名 URL，Origin 为 gstatic.com | Cloudflare HTTP 403、HTML 响应 | 该请求未拿到播放列表；不能区分 Cloudflare、Referer、Cookie、UA、IP/token 等限制 |
| App / iPhone 16 Pro iOS 18.6 模拟器打开同一集 | 手机站重定向到 m.iyf.tv，检测到 chunklist.m3u8，标记当前视频，时长 25:42；网页出现实际视频画面 | 移动 WKWebView 的原生媒体路径有效，HLS 与另一 MP4 分开显示 |
| 内置 Apple HLS 页面 | 检测浮层显示 master.m3u8；离线模式投屏按钮禁用 | 资源打包、WKWebView、消息桥和列表可用 |
| 模拟器测试 | 20 passed / 0 failed / 0 skipped | 数据规则、真实 WebKit hook 和 SDK 构建/回调映射通过；不等于 Chromecast 播放通过 |
| iPhone Release 编译、签名、安装 | 0.1.1 (2) 编译成功，签名验证通过；devicectl 再次确认手机安装版本 | 软件版本与安装确认通过 |
| 用户亲自在电视上播放 | 用户反馈“目前感觉测试后是可以的” | 一次真实播放成功；具体站点、设备与遥控项目未逐项记录 |
| 用户测试后的手机读取检查 | 当前无 Webcast 进程；Webcast 名称过滤的 systemCrashLogs 为 0 files；Library 下无 Logs 目录 | 未发现匹配的 App 崩溃报告；Release 无持久化详细 GCK 日志，不能回溯完整播放链路 |

网页链接：[《仙逆》第一集](https://www.iyf.tv/play/qXvszbfSdq5)。签名流的 query 含临时令牌及访问参数，未写入项目文件。

截图：[真实 iyf 嗅探列表](../artifacts/iyf-sniffer.jpg)、[Apple HLS 检测示例](../artifacts/sniffer-demo.jpg)。早期构建失败已解决；诊断和清理结论见 [本轮检查](../artifacts/review-2026-10-07.md)，当前证据见 [验证记录](../artifacts/validation.md)。

## 后续验收

先保留当前能够实际播放的直接投屏方案。后续重点是确认主目标爱壹帆的具体集数、遥控操作、锁屏和 Wi-Fi 恢复，记录测试来源与结果。历史 curl 的 Cloudflare 403 不再作为“电视不能播放”的结论。

只有在复现具体视频失败时，才按需比较有效签名、Referer/Cookie、接收端 Origin、播放列表/分片/密钥的 CORS 与字节格式；确定问题原因后再决定是否需要代理。无须为已经成功的播放路径预先增加请求代理或后台音频。

## 真机验收表

- [x] 在真实 iPhone 15 用 Personal Team 签名安装 Release 0.1.1 (2)。
- [x] 用户已启动正式 App 并在电视上实际播放成功。
- [ ] 补记本次成功的视频来源与设备；当前仅有用户总体成功反馈。
- [ ] 手机允许本地网络权限，App 内发现 Dining room TV。
- [ ] 用户手动选择电视，Apple HLS 测试视频出画面。
- [ ] 播放/暂停、Seek、音量、静音、停止、断开行为符合预期。
- [ ] iyf 选集 → 当前 HLS → 电视实际播放，并能遥控。
- [ ] 锁屏 30 秒回来，投屏会话恢复；短暂 Wi-Fi 波动后恢复。
- [ ] 如代理进入 MVP，额外验证锁屏 5 分钟电视不断流。

字幕、队列、广告过滤、历史和书签维持 Phase 2，不作为本次实现范围。
