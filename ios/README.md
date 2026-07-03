# YJ 指揮中心 — 原生 iOS App（SwiftUI）

原生 SwiftUI 版本的 ADHD 儀表板。直接連你現有的 Supabase，**與網頁版共用同一份資料**——手機上改的，電腦網頁上立刻看得到，反之亦然。

## 功能

| Tab | 內容 |
|-----|------|
| **今日** | 生活費跑道（點天數可改截止日）、專注任務、番茄鐘（25/5/15）、今日任務清單 |
| **清空** | 腦袋清空三階段：倒出 → 分類（時間壓力/分類/幫助/難度）→ 5 分鐘啟動 |
| **看板** | 今天必做 / 立即可做 / 本週做 / 低優先，長按卡片可完成、移動、刪除 |

原生版獨有的優勢：
- **番茄鐘到點推送系統通知** — 就算 app 在背景、手機鎖屏也會響（網頁版做不到）
- 計時用時間戳計算，切 app、鎖屏都不會凍結
- 所有操作樂觀更新，點下去畫面立即反應，背景才同步資料庫
- 自動深色模式

## 怎麼跑到你的 iPhone 上（Mac 上操作，約 10 分鐘）

1. **裝 Xcode**（App Store 免費，需要 macOS 14+）
2. 打開 `ios/ADHDCommand.xcodeproj`
3. 左側點藍色專案圖示 → **Signing & Capabilities** → Team 選你的 Apple ID
   （沒有的話按 "Add an Account…" 登入你的一般 Apple ID，免費）
4. iPhone 用線接上 Mac（第一次需要在手機上按「信任這部電腦」）
5. 頂部裝置選單選你的 iPhone → 按 **▶ Run**
6. 第一次跑，手機上要去 **設定 → 一般 → VPN 與裝置管理** 信任你的開發者憑證

### 簽名的現實

- **免費 Apple ID**：app 裝在手機上 7 天後要重新從 Xcode Run 一次（資料不會掉，因為都在 Supabase）
- **Apple Developer Program（US$99/年）**：一年才過期一次，也才能用 TestFlight / 上 App Store

個人自用的話，免費方案 + 偶爾重新 Run 一次就夠了。

## 疑難排解

- **專案打不開**（Xcode 15 以下）：`brew install xcodegen`，然後在 `ios/` 目錄執行 `xcodegen`，會重新產生相容的專案檔
- **編譯錯誤**：這份代碼是在沒有 Xcode 的環境寫的，第一次編譯可能有小錯——把錯誤訊息貼回給 Claude 即可修
- **資料沒載入**：檢查手機網路；Supabase 專案若被暫停（免費方案閒置 90 天），去 supabase.com 恢復

## 架構

```
ADHDCommand/
├── ADHDCommandApp.swift   # App 入口 + TabView
├── Models.swift           # tasks / unblock_items / unblock_categories 模型 + 分類邏輯
├── Supabase.swift         # 輕量 PostgREST client（無第三方依賴）
├── AppStore.swift         # 資料層：樂觀更新 + 背景同步
├── PomodoroModel.swift    # 時間戳計時器 + 本地推送通知
├── Theme.swift            # 暖紙色 + 金色主題（自動深色模式）
└── Views/
    ├── TodayView.swift    # 今日：跑道、番茄鐘、任務
    ├── UnblockView.swift  # 清空：dump → triage → focus
    └── KanbanView.swift   # 看板
```

刻意零第三方依賴（不用 supabase-swift SDK，直接呼叫 PostgREST API），打開專案不用等套件下載，也少一層會壞的東西。

## 還沒做的（跟網頁版比）

- 分類管理（新增/改名/刪除分類）— 先用網頁版管理，app 會即時讀到
- 早晨模式選擇（morning gate）
- ADHD 策略小卡輪播
