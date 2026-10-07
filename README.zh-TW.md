<p align="center">
  <img src="Webcast/Assets.xcassets/AppIcon.appiconset/appicon-watercolor.png" alt="Webcast 水彩電視與投屏圖示" width="120" height="120">
</p>

<h1 align="center">Webcast</h1>

<p align="center">
  <strong>在 iPhone 開啟網頁影片，投到 Chromecast，再用手機控制播放。</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-source%20build-111111" alt="目前提供原始碼建置，沒有公開安裝包">
  <img src="https://img.shields.io/badge/iOS-16.0%2B-111111?logo=apple&amp;logoColor=white" alt="iOS 16.0 或以上版本">
  <img src="https://img.shields.io/badge/version-0.1.1%20%282%29-111111" alt="目前版本 0.1.1，建置編號 2">
  <img src="https://img.shields.io/badge/SwiftUI-WKWebView-F05138?logo=swift&amp;logoColor=white" alt="使用 SwiftUI 與 WKWebView">
  <img src="https://img.shields.io/badge/Google%20Cast-4.8.6-111111" alt="Google Cast SDK 4.8.6">
</p>

<p align="center">
  <a href="#快速開始">快速開始</a> ·
  <a href="#功能">功能</a> ·
  <a href="#隱私">隱私</a> ·
  <a href="#從原始碼建置">從原始碼建置</a> ·
  <a href="https://github.com/ycl-2004/Webcast/issues">問題回報</a> ·
  <a href="README.md">English</a>
</p>

Webcast 是原生 iOS 瀏覽器與 Chromecast 遙控器，適合想把網頁影片放到大螢幕觀看的人。開啟網站並播放影片，再選擇偵測到的串流投到電視。電視直接取得影片串流，手機負責瀏覽與播放控制。

> **目前分發狀態：** 僅提供原始碼建置，尚無 App Store、TestFlight 或公開安裝包。帶有新水彩圖示的 Release **0.1.1 (2)** 已於 **2026-10-07** 使用 Apple Development／Personal Team 簽名，並安裝到 iPhone 15。使用者已回報電視播放成功；個別遙控操作、鎖定畫面與 Wi-Fi 恢復仍待逐項驗收。[驗證紀錄](artifacts/validation.md)。

## 快速開始

請先使用自己的 Apple 簽名帳號[建置並安裝 Webcast](#從原始碼建置)。已安裝後：

1. 將 iPhone 與 Chromecast 或支援 Google Cast 的電視連到同一個 Wi-Fi，並允許 Webcast 的**本機網路**權限。
2. 開啟 **`浏览器`** 分頁，輸入網站並播放影片。預設首頁為爱壹帆，可在 **`设置`** 更改。
3. 點底部的 **`视频`**，優先選擇 **`当前视频`**，或先比對標題、時長與來源。
4. 點 **`投到电视`**；尚未連線時，先選擇電視。
5. 在 **`投屏遥控`** 控制播放、進度、音量、靜音與停止。

投屏失敗時，回到瀏覽器重新播放，再選擇新的候選項目。手機能播放，不代表電視一定能直接取得串流。

### 系統需求

- iOS 16.0 或以上版本；目前簽名建置已安裝到 iPhone 15。
- Chromecast 或支援 Google Cast 的接收端，與手機使用同一個 Wi-Fi。
- 本機網路權限，用於裝置探索與投屏。
- 網頁與遠端影片來源需要網際網路連線。
- 目前 App 介面使用簡體中文；本文保留按鈕的實際文字。已設定 iPad 目標，但尚無實體 iPad 驗收紀錄。

## 為什麼使用 Webcast

- **直接在影片所在的網頁瀏覽。** 使用原生網頁檢視，不必把串流網址複製到另一個播放器。
- **自己選擇投到電視的內容。** 先檢查偵測結果與來源，再開始投屏。
- **手機保留操作空間。** 瀏覽、影片選擇與遙控集中在同一個 App。

## 功能

**瀏覽器**

- 輸入網址、使用 Google 或 Bing 搜尋、前進與返回、重新整理，以及自訂首頁。
- 可要求桌面網站、攔截新視窗，以及選擇啟動位置。
- 網站資料儲存在本機，並可透過設定清除及登出網站。

**影片偵測**

- 偵測主頁面與子框架中的原生媒體及媒體請求。
- 辨識 HLS、MP4 候選項目；可取得資訊時顯示目前影片、來源、時長與直播狀態。
- 保留簽名網址參數、移除重複候選項目，並停用已辨識為 DRM 保護的項目。
- 分開標示推測的 MSE 候選項目；**`可能是正片`** 是估計結果，請核對來源與時長。

**Chromecast 遙控**

- 探索接收端並選擇電視。
- 播放／暫停、調整進度、前後跳轉 15 秒、音量、靜音、停止與中斷連線。
- 顯示連線及播放狀態，包括載入與連線中斷。以上控制已實作，完整實體裝置驗收仍待完成。

## 運作方式

`網站 → 偵測媒體網址 → 選擇 Chromecast 接收端 → 直接播放串流`

Webcast 將選定網址與媒體資訊傳給 Google 的 Default Media Receiver。它不會鏡像手機畫面，也不會讓影片透過手機代理轉送。

**`断开连接`** 會中斷手機連線，不要求電視停止播放；**`停止并断开`** 會要求電視停止後再中斷連線。兩個操作分開提供。

## 畫面截圖

<table>
  <tr>
    <td align="center"><strong>Apple HLS 偵測範例</strong><br><img src="artifacts/sniffer-demo.jpg" alt="較早的模擬器建置偵測 Apple HLS 範例，驗證模式停用投屏" width="260"></td>
    <td align="center"><strong>網頁影片候選項目</strong><br><img src="artifacts/iyf-sniffer.jpg" alt="較早的模擬器建置播放爱壹帆影片，並分別顯示 HLS 與 MP4 候選項目" width="260"></td>
  </tr>
</table>

這兩張已納入版本控制的截圖來自 2026-10-07 較早的模擬器建置，展示實際 WebKit 影片偵測。部分瀏覽器控制項與文案後來已有調整。截圖並非電視播放證據，擷取時也停用了投屏。[擷取背景](docs/FEASIBILITY.md)。

## 隱私

- Webcast 沒有 App 帳號或專案自營後端。設定、上次瀏覽網址與上次選擇的分頁儲存在本機。
- WebKit 在裝置上儲存網站 Cookie、快取與其他網站資料。**`设置 → 清除网站数据`** 會清除這些資料及已儲存的上次網址；之後需要重新登入網站。
- 開啟網頁與搜尋會連線到指定網站或搜尋引擎。投屏會將媒體網址、標題與來源主機名稱傳給接收端，再由接收端直接取得影片。
- App 設定已停用 Google Cast SDK 的分析記錄；Release 也停用詳細 SDK 除錯記錄。
- 網站、搜尋引擎、影片主機與 Google Cast 元件各有自己的網路與資料行為。Webcast 需要網路，也不會讓第三方流量變成私密流量。

## 目前建置

**0.1.1 (2)** 是 [`project.yml`](project.yml) 中的目前版本，包含瀏覽器、影片偵測、Chromecast 遙控、設定與水彩 App 圖示。

| 證據 | 結果 |
| --- | --- |
| 簽名 iPhone Release 建置 | 建置與簽名驗證通過，已安裝到 iPhone 15 |
| 自動化驗證 | 20 項通過，0 項失敗，0 項略過；紀錄早於僅更換圖示的更新 |
| 電視實際播放 | 使用者回報成功；尚未記錄來源與個別遙控結果 |
| 公開分發 | 尚無公開安裝包、App Store 或 TestFlight 版本 |

詳見[驗證紀錄](artifacts/validation.md)、[實作檢查](artifacts/review-2026-10-07.md)及[接收端驗收清單](docs/FEASIBILITY.md)。圖示更新沒有改變 App 行為，因此未重新執行測試。

## 常見問題

<details>
<summary>為什麼手機能播放，電視卻失敗？</summary>

接收端會獨立取得網址。網站可能要求瀏覽器 Cookie、特定請求標頭、有效的簽名網址或 DRM 授權，而接收端不具備這些條件。請重新播放並選擇新的候選項目。目前沒有處理這類需求的中繼或代理功能。

</details>

<details>
<summary>為什麼找不到電視？</summary>

確認電視支援 Google Cast、已開機，且與手機連到同一個 Wi-Fi。在 iOS 設定允許 Webcast 使用本機網路，再開啟裝置選單。不支援僅提供 AirPlay 或 DLNA 的接收端。

</details>

<details>
<summary>為什麼 Personal Team 安裝會到期？</summary>

Personal Team 的佈建描述檔會在七天後到期，屆時需要用自己的簽名帳號重新建置並安裝。Release 是建置設定，不代表 App Store 分發憑證。[Apple 的 Personal Team 說明](https://developer.apple.com/help/account/basics/about-your-developer-account/)。

</details>

## 從原始碼建置

<details>
<summary>需求、本機簽名、建置與驗證指令</summary>

需要安裝 Xcode 與 iOS SDK 的 Mac，並確保 `PATH` 中可使用 XcodeGen。本專案已使用 Xcode 27.0 建置。Google Cast 固定為 `SRGSSR/google-cast-sdk` **4.8.6**；首次建置需要連線下載相依套件。

```sh
git clone https://github.com/ycl-2004/Webcast.git
cd Webcast
make generate
open Webcast.xcodeproj
```

在 **Xcode Settings → Apple Accounts** 登入帳號，選擇自己的團隊，並啟用自動簽名。手機需與 Mac 配對、信任此 Mac，並啟用開發者模式。

建立 `Config/Signing.local.xcconfig`，填入 Xcode 中的 Team ID：

```text
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
```

建立 `.device.mk`，填入手機 UDID：

```make
DEVICE_UDID := <YOUR_DEVICE_UDID>
```

這兩個檔案都由 Git 忽略，請將預留值換成自己的資料。重新產生 Xcode 專案仍會保留本機設定。

```sh
make build           # 未簽名的模擬器 Release
make release         # 未簽名的實體裝置 Release，不安裝
make device-build    # 簽名的實體裝置 Release，不安裝
make device-install  # 建置並安裝，不啟動 App
make device          # 建置、安裝並啟動 App
```

使用已安裝的 iPhone 模擬器執行測試：

```sh
make test SIMULATOR='iPhone 16 Pro'
```

若要開啟內建 HLS 範例，請先啟動模擬器，再填入其 UUID：

```sh
make demo SIMULATOR_ID='<BOOTED_SIMULATOR_UUID>'
```

預設建置、Run、Profile 與 Archive 都使用 Release；測試明確使用 Debug。測試與範例透過 `WEBCAST_OFFLINE_VALIDATION=1` 跳過 Cast SDK 初始化及電視命令。這會停用投屏，不會停用網頁連線。範例與檢查工具不會編入 Release。

既有紀錄已驗證開發機上的模擬器建置／測試，以及實體裝置簽名建置／安裝。尚未在全新 Mac 或另一個 Apple 帳號上驗證設定流程。

</details>

## 專案結構

| 路徑 | 責任 |
| --- | --- |
| `project.yml`、`Makefile`、`Package.resolved` | Xcode 專案產生、建置及固定相依版本 |
| `Webcast/Browser/`、`Webcast/Views/` | 瀏覽器狀態與原生介面 |
| `Webcast/Sniffer/`、`Webcast/Models/` | 媒體偵測、候選排序及網址規則 |
| `Webcast/Cast/` | 裝置探索、會話、媒體載入與遙控 |
| `Webcast/Assets.xcassets/`、`artwork/` | App 圖示、保留的原圖與生成說明 |
| `Tests/Swift/` | 單元測試與實際 WebKit 整合測試 |
| `docs/`、`artifacts/` | 可行性、驗收、截圖與驗證證據 |

## 版本與發布

在 `project.yml` 更新 `CFBundleShortVersionString` 與 `CFBundleVersion`，再執行 `make generate`，同步 `Webcast/Info.plist` 與產生的專案。文件也應對齊實際建置。

目前沒有發布標籤或公開安裝檔。本機簽名檔、裝置識別碼、產生的專案與 App 套件均不納入 Git。公開 iOS 分發需要另行設定簽名與發布方式。

## 參與與回報

請在 [Issues](https://github.com/ycl-2004/Webcast/issues) 提供 iOS 版本、接收端型號、網站、重現步驟及預期結果。回報前請移除 Cookie 與帶有臨時簽名的媒體網址。重用或分發原始碼前，請先閱讀[授權](#授權)。

## 已知限制

- 僅支援接收端直接播放：沒有畫面鏡像、AirPlay、DLNA、本機代理或背景音訊保活。
- 部分網站及特殊播放器無法偵測或播放；已偵測串流仍可能因接收端授權或格式檢查而失敗。
- DRM 偵測只能盡力辨識。未標記不代表串流沒有 DRM。
- 尚未實作字幕、佇列、廣告過濾、瀏覽歷史與書籤。
- 個別遙控操作、指定爱壹帆集數、鎖定畫面恢復、Wi-Fi 恢復，以及實體 iPad 使用尚未完整驗證。
- Personal Team 安裝需要定期重新簽名；目前沒有自動更新或公開安裝包。

## 授權

尚未選定專案授權，儲存庫中也沒有 `LICENSE` 檔案。公開原始碼不代表授予複製、修改、再分發、重新命名或販售的權利。相依套件保留各自的授權。
