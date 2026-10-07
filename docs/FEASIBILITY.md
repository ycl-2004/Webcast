# 可行性与验收记录

日期：2026-10-07。原始产品范围见 [PLAN.md](../PLAN.md)。

## 结论

**可构建的 sender/browser 软件已经实现；第 0 步的接收端可行性仍未通过。** 用户明确要求不要连接 Chromecast，随后仅授权设备扫描。因此没有运行 `catt cast`、启动 Cast 会话、加载电视媒体或发送任何遥控命令。

不能据当前证据断言 iyf 可由 Default Media Receiver 直接播放，也不能断言手机代理一定能解决。当前不加入未经验证的代理；主目标 iyf 的电视验收仍是交付前必须关闭的事项。

## 实测观察

| 检查 | 实测结果 | 能说明什么 |
|---|---|---|
| Mac Chrome 的 Cast 设备列表 | `Dining room TV — Available` | Mac 的 Chrome 可以发现设备；未点选设备 |
| 命令行 mDNS | `DNSServiceBrowse failed -65563` | 当前沙箱不能使用该服务，不能推断电视离线 |
| Chrome 打开《仙逆》第一集 | video.currentSrc 为 blob；资源清单含 pipecdn.vip 的 chunklist.m3u8 和 .ts | 桌面播放器走 MSE，不能只观察 video.src |
| 独立 curl，真实签名 URL，Origin 为 gstatic.com | Cloudflare HTTP 403、HTML 响应 | 该请求未拿到播放列表；不能区分 Cloudflare、Referer、Cookie、UA、IP/token 等限制 |
| App / iPhone 16 Pro iOS 18.6 模拟器打开同一集 | 手机站重定向到 m.iyf.tv，检测到 chunklist.m3u8，标记当前视频，时长 25:42；网页出现实际视频画面 | 移动 WKWebView 的原生媒体路径有效，HLS 与另一 MP4 分开显示 |
| 内置 Apple HLS 页面 | 检测浮层显示 master.m3u8；离线模式投屏按钮禁用 | 资源打包、WKWebView、消息桥和列表可用 |
| 模拟器测试 | 14 passed / 0 failed / 0 skipped | 数据规则、真实 WebKit hook 和 SDK 构建/回调映射通过；不等于 Chromecast 播放通过 |
| iPhone 构建命令 | Xcode 包缓存被沙箱拒绝；直接 swiftc 也被编译宏沙箱阻断 | 真机编译/签名/安装未验证；模拟器构建与运行已通过 |

网页链接：[《仙逆》第一集](https://www.iyf.tv/play/qXvszbfSdq5)。签名流的 query 含临时令牌及访问参数，未写入项目文件。

截图：[真实 iyf 嗅探列表](../artifacts/iyf-sniffer.jpg)、[Apple HLS 检测示例](../artifacts/sniffer-demo.jpg)。本地构建失败的详细诊断保留在 `artifacts/device-build.log` 和 `artifacts/device-compile.log`。

## 第 0 步仍需完成

在得到电视播放测试授权后，重新取得当前有效的主/子列表和分片。比较带/不带 Referer、接收端 Origin、播放列表/分片/密钥的 CORS 与字节格式；隔 10 分钟验证签名有效期。当前 403 返回的是 Cloudflare HTML，尚不能检查分片头、AES 密钥或 DRM 标志。

用实际接收端验证当前有效 URL。若能直播，保留直接 sender；若确定有请求头/CORS/伪装分片限制，才实现并验收本地代理。若是不可取得授权的 DRM，重新评估主目标。手机网页可播放和 Chrome 设备可发现都不能替代这个判断。

## 真机验收表

- [ ] 在真实 iPhone 免费签名安装并启动。
- [ ] 手机允许本地网络权限，App 内发现 Dining room TV。
- [ ] 用户手动选择电视，Apple HLS 测试视频出画面。
- [ ] 播放/暂停、Seek、音量、静音、停止、断开行为符合预期。
- [ ] iyf 选集 → 当前 HLS → 电视实际播放，并能遥控。
- [ ] 锁屏 30 秒回来，投屏会话恢复；短暂 Wi-Fi 波动后恢复。
- [ ] 如代理进入 MVP，额外验证锁屏 5 分钟电视不断流。

字幕、队列、广告过滤、历史和书签维持 Phase 2，不作为本次实现范围。
