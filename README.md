# HK Bus ETA (SwiftUI) · 1.0

![Build](https://github.com/Justintunsday/hk-bus-eta-swiftui/actions/workflows/build.yml/badge.svg)

多地區實時公交預報 App — an unofficial, ad-free multi-region bus ETA app rebuilt with SwiftUI.

本項目最初是 [hkbus/hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) 的 SwiftUI 重寫版（香港），
1.0 起加入**多地區架構**：除香港外，內地城市透過非官方的「車來了」數據源提供服務。本 App 並非官方應用。

## 功能 Features

- **多地區切換**：跟隨定位自動選擇城市（香港 / 深圳 / 廣州 / 上海 / 北京 / 天津 / 重慶 / 成都 / 佛山 / 青島 / 瀋陽 / 南京 / 西安）
- 地區數據互相獨立，切換後搜索、附近、收藏等全部跟隨當前城市
- **香港**：九巴、城巴、嶼巴、綠色小巴、港鐵巴士、輕鐵、港鐵、渡輪的實時到站；路線詳情含收費、服務時間、班次
- **內地城市（車來了）**：關鍵詞搜索（線路 / 站點）、附近站點（含到站預報）、站點經過線路、線路詳情（地圖 + 沿途站序）、實時到站
- 路線詳情：MapKit 地圖（路線折線＋編號站點標記＋點選聯動）、時間軸站序、點按展開內聯到站
- 車站總覽：同一車站全部路線的到站板（等寬數字對齊）
- 附近車站（定位，顯示距離）
- 收藏整條線路 / 車站、最近瀏覽
- 到站顯示格式（時間／時差／混合）、預定班次標示
- 繁體中文 / 简体中文 / English
- iPhone 與 iPad、深色模式、iOS 26 Liquid Glass

## 技術架構 Architecture

- SwiftUI + `@Observable`（iOS 17+），無第三方依賴
- **`TransitProvider` 協議**：地區相關的一切（數據源、時區、營運商、日曆、車費、配色、ETA 抓取）都在 provider 內
  - `HongKongProvider`：靜態數據庫（每日更新）+ data.gov.hk 各營運商 ETA API
  - `CheLaileProvider`：無靜態數據庫，全部按需查詢；`CheLaileClient` 負責 MD5 簽名與 AES-256-ECB 解密的私有 H5 接口
- `RegionCatalog`：內置城市清單與「跟隨定位自動選擇」；`RegionClock` 注入當前地區時區
- 查詢模式的線路會合成為標準 `RouteEntry` 註冊進 `DataStore`，因此地圖／時間軸／到站頁完全復用
- **Liquid Glass**：以 Xcode 26 / iOS 26 SDK 編譯時，標準控件在 iOS 26+ 自動採用 Liquid Glass
- `HKBusETA/Models` — EtaDB、TransitOperator、TransitRegion
- `HKBusETA/Services` — TransitProvider、HongKongProvider、CheLaileClient/Provider、DataStore、ETA 服務、收藏、定位
- `HKBusETA/Views` — 搜索、路線、到站、附近、收藏、設定
- `docs/brand-spec.md` — Warm Minimal 設計系統

## 建置 Build

需求：macOS + Xcode 26（iOS 26 SDK，支援 Liquid Glass；Xcode 16 亦可編譯）。

```bash
git clone https://github.com/Justintunsday/hk-bus-eta-swiftui.git
cd hk-bus-eta-swiftui
open HKBusETA.xcodeproj
```

GitHub Actions（`macos-26` / Xcode 26.6）推送自動編譯模擬器、未簽署歸檔及 IPA。

## 數據來源 Data Sources

- 香港到站預報：DATA.GOV.HK 及各營運商 API；路線、車站、收費、班次來自 [HK Bus Crawling@2021](https://github.com/hkbus/hk-bus-crawling)（`https://data.hkbus.app/routeFareList.min.json`，約 8 MB，首次啟動下載後本機快取，每日檢查更新）
- 內地城市：非官方「車來了」H5 接口（參考 [PeanutSplash/chelaile-mcp](https://github.com/PeanutSplash/chelaile-mcp)，MIT），隨時可能失效，資料僅供參考
- 營運商站牌圖示：來自 [hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) `public/img`（GPL-3.0）

## 免責聲明 Disclaimer

本應用為非官方項目。香港資料來自公開數據；內地城市使用非官方接口，可能隨時中斷。
所有到站資料僅供參考，實際班次以營運商公佈為準。

## 授權 License

[GPL-3.0](LICENSE)，與上游項目 [hk-independent-bus-eta](https://github.com/hkbus/hk-independent-bus-eta) 一致。
