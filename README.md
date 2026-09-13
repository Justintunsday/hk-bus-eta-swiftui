# HK Bus ETA (SwiftUI)

![Build](https://github.com/Justintunsday/hk-bus-eta-swiftui/actions/workflows/build.yml/badge.svg)

香港獨立巴士預報 SwiftUI 版 — an unofficial, ad-free Hong Kong bus ETA app rebuilt from scratch with SwiftUI.

本項目是 [hkbus/hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) 的 SwiftUI 重寫版，資料與服務邏輯取自該開源項目，並非官方應用。

## 功能 Features

- 路線搜尋（路線號碼／起點／終點）與車站搜尋
- 實時到站時間（九巴、城巴、嶼巴、綠色小巴、港鐵巴士、輕鐵、港鐵、渡輪）
- 附近車站（定位，顯示距離）
- 車站到站總覽（同一車站全部路線）
- 路線詳情：MapKit 地圖（路線折線＋編號車站標記＋點選聯動）、時間軸車站順序、點按展開內聯到站、收費、服務時間、班次
- 收藏路線／車站、最近瀏覽
- 到站時間顯示格式（時間／時差／混合）、預定班次標示
- 繁體中文 / 简体中文 / English（跟隨系統或手動切換；數據站名自動繁簡轉換）
- iPhone 與 iPad 自適應

## 技術架構 Architecture

- SwiftUI + `@Observable`（iOS 17+）
- **Liquid Glass**：以 Xcode 26 / iOS 26 SDK 編譯時，標準控件在 iOS 26+ 自動採用 Liquid Glass 設計；篩選標籤等自訂元件另有 `glassEffect` 實作（以編譯器版本門控，Xcode 16 亦可編譯）
- Xcode 16 同步資料夾（`PBXFileSystemSynchronizedRootGroup`），新增檔案無需修改 `project.pbxproj`
- 無第三方依賴
- `HKBusETA/Models` — `EtaDB` Codable 資料模型
- `HKBusETA/Services` — 資料下載與快取、各營運商 ETA API、收藏持久化、定位
- `HKBusETA/Views` — 搜尋、路線、到站、附近、收藏、設定
- `HKBusETA/Resources/Localizable.xcstrings` — 雙語字串表

## 建置 Build

需求：macOS + Xcode 26（iOS 26 SDK，支援 Liquid Glass；Xcode 16 亦可編譯，但沒有玻璃材質）。

```bash
git clone https://github.com/Justintunsday/hk-bus-eta-swiftui.git
cd hk-bus-eta-swiftui
open HKBusETA.xcodeproj
```

選擇 HKBusETA scheme，執行於 iOS 模擬器或裝置（iOS 17+）。

本倉庫亦設有 GitHub Actions（`macos-26` runner / Xcode 26.6），每次推送會自動以 `xcodebuild` 編譯模擬器版本、未簽署裝置封存檔及 IPA：

```
.github/workflows/build.yml
```

## 資料來源 Data Sources

- 到站預報：來自 [資料一站通 DATA.GOV.HK](https://data.gov.hk) 及各營運商 API（九巴、城巴、嶼巴、綠色小巴、港鐵巴士、輕鐵、港鐵）
- 路線、車站、收費、班次：來自 [HK Bus Crawling@2021](https://github.com/hkbus/hk-bus-crawling)（每日更新，`https://data.hkbus.app/routeFareList.min.json`）
- 資料只在首次啟動及每日檢查更新時下載，之後使用本機快取。

## 免責聲明 Disclaimer

本應用為非官方項目，所有到站資料僅供參考，實際班次以營運商公佈為準。
App icon and UI 為本項目自行設計，與任何營運商無關。

## 授權 License

[GPL-3.0](LICENSE)，與上游項目 [hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) 一致。
