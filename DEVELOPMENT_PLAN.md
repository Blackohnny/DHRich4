# DHRich4 - AI 驅動大富翁 開發計畫 (Development Plan)

## 專案概述 (Project Overview)
本專案為一個結合真實世界數據與 LLM (大語言模型) 的單機大富翁遊戲。
*   **開發者背景**: C++ 專業工程師 (熟悉架構、邏輯、API 呼叫)。
*   **遊戲引擎**: Godot Engine 4.x (使用 GDScript)。
*   **執行環境**: Windows (開發檔案存放於 WSL)。
*   **核心特色**:
    1.  **極簡視覺**: 無需精美美術，以方格與圖片平移 (Tween) 呈現空間感。
    2.  **動態市場**: 道具/房地產價格隨機或受玩家行為 (供需) 影響。
    3.  **現實接軌**: 串接真實世界新聞/股市 API，動態改變遊戲數值 (如：科技股大漲帶動過路費)。
    4.  **AI 命運之神**: 踩到機會命運時，與 AI (Gemini) 進行 3 句對話，由 AI 根據玩家態度決定獎懲 (輸出 JSON)。

---

## 🏛️ 架構決策紀錄 (Architecture Decision Records - ADR)
本區塊記錄了專案開發過程中的重大架構轉折與設計理念，供開發團隊回顧。

### 1. 地圖資料儲存 (Board Data)
*   **決策**: 採用 Godot Custom Resources (`.tres`) 取代 JSON。
*   **原因**: 
    *   Godot 底層對 Resource 序列化效能極佳，且支援強型別檢查。
    *   內建 Inspector 支援，零成本獲得地圖編輯器 GUI，無需額外開發工具。
*   **Fallback 機制**: 
    1. 優先讀取外部指定的關卡 `.tres`。
    2. 若未指定，讀取專案內建的 `map_default.tres` (8字形地圖)。
    3. 若實體檔案遺失，則拋出 Fatal Error 中止執行，確保「邏輯」與「資料」的絕對解耦 (Data-Driven)。

### 2. 移動狀態機重構 (Step-by-step Movement)
*   **決策**: 地圖本質為有向圖 (Directed Graph)。廢除「擲骰子後瞬間計算終點」的做法，改以「剩餘步數」逐步移動。
*   **原因**: 為了支援複雜的大富翁機制 (如路障、岔路選擇)，必須在移動的「過程」中安插觸發點。
*   **狀態機流轉順序**: 
    1. 經過節點 (檢查路障/岔路) 
    2. 檢查剩餘步數 
    3. 若歸零則觸發落地事件。
*   **禁止回走 (No Backtracking)**：在有向圖的岔路判定時，必須過濾掉玩家的來源節點 (Previous Node)。

### 3. 實體解耦與 MVC (Entity Decoupling)
*   **決策**: 將玩家狀態與平移動畫抽離至獨立的 `PlayerEntity` 節點與腳本。
*   **原因**: 原先 `Main.gd` (控制器) 直接操作玩家 Sprite 的位置，導致強耦合，且無法支援多玩家。重構後 `Main.gd` 僅負責回合與步數遞迴，透過呼叫 `PlayerEntity.move_one_step()` 並 `await` 其 `step_finished` 訊號 (Signal) 來同步流程。
*   **效益**: 達成完美的 MVC 架構分離，為未來加入 AI 對手或多人連線打下基礎。

### 4. 編輯器即時預覽工具 (Editor Tooling)
*   **決策**: 建立獨立的 `@tool MapPreviewer` 節點，專責在 Godot 編輯器內讀取 `.tres` 並繪製地圖。
*   **原因**: 為了獲得「修改座標即可即時預覽」的開發者體驗 (DX)，需要用到 Godot 的 `@tool`。但若將主控制器 `Main.gd` 設為 `@tool`，其內部的 `_process` 與節點參照會在編輯器內瘋狂噴錯或干擾執行。
*   **效益**: 確保遊戲主邏輯 (`Main.gd`) 乾淨安全，同時透過 `MapPreviewer.gd` 提供強大的所見即所得 (WYSIWYG) 關卡編輯能力。

---

## 🛠️ 階段開發藍圖 (Step-by-Step Roadmap)

### 5. AI 設定檔雙路徑與優雅降級 (AI Config Fallback)
*   **決策**: 捨棄 Godot 內建的 `ConfigFile` (.cfg)，改用 `.json` 作為 AI 設定檔格式。並實作 `AIManager` AutoLoad 單例。
*   **原因**: 
    *   Godot 的 `.cfg` 解析器對於超長字串 (如超過 300 字元的 JWT API Key) 會拋出 `ERR_PARSE_ERROR`。JSON 解析器更為穩健。
    *   為了支援未來發佈 (Export) 後玩家自帶 Key (BYOK) 的模式，設定檔必須具備雙路徑尋找能力。
*   **Fallback 機制**: 
    1. 優先尋找玩家目錄 `user://ai_config.json`。
    2. 尋找開發目錄 `res://ai_config.json`。
    3. 若皆不存在，或參數設定異常，遊戲不會崩潰，而是觸發**優雅降級 (Graceful Degradation)**，將機會/命運格切換為傳統隨機抽卡模式。

### 6. 多玩家 MVC 架構與資訊遮蔽 (Multi-player MVC & Fog of War)
*   **決策**: 將玩家系統徹底解耦為 Model (`PlayerData`), View (`PlayerEntity.tscn` / `StatusUI.tscn`), 與 Controller (`PlayerManager` / `Main.gd`)，並在資料層實作資訊遮蔽。
*   **原因**:
    *   **解決寫死節點的痛點**: 原本主場景僅能支援單一 `$Player` 棋子，重構為動態 `instantiate()` 以支援任意數量玩家與回合輪替 (`advance_turn`)。
    *   **事件驅動 UI**: UI 組件 (`StatusUI`) 不再寫死資料，而是透過 `@onready` 搭配 Unique Name (`%`) 獲取節點參考，並在 `_ready` 透過 Signal (`pressed.connect`) 註冊事件監聽，與控制器互動。
    *   **防堵 AI 作弊 (True Fog of War)**: 若在 UI 層寫死隱藏邏輯，未來的 AI 仍可讀取對手底層參數。故將 `PlayerData` 的資產設為私有 (`_cash`)，並對外提供 `get_public_view(viewer_id)` 視圖 API (DTO 模式)。任何人 (含 AI) 呼叫皆會依照權限回傳精確或模糊化資料。

---

## 🛠️ 階段開發藍圖 (Step-by-Step Roadmap)

### Phase 1: 基礎建設與平移動畫 (Foundation & Movement) [✅ 完成]
*   [x] **1.1 建立 Godot 專案**: 在 Windows 下開啟 Godot 4，建立專案於 WSL 資料夾 (`/home/j8ohnny/workspace/DHRich4`)。
*   [x] **1.2 建立地圖資料結構 (Model)**: 寫一個 GDScript (`MapManager.gd`)，定義環狀棋盤的每一格座標 (例如 Array of Vector2)。
*   [x] **1.3 建立玩家節點 (View)**: 建立 `Sprite2D` 代表玩家，載入預設圖示 (`icon.svg`)。
*   [x] **1.4 實作骰子與平移 (Controller)**: 使用 Tween 實作平移。
*   [x] **1.5 資源覆寫防護 (ResourceManager)**: 建立 private/public 雙資料夾與 Fallback 動態載入機制。
*   [x] **1.6 獨立除錯系統 (DebugLogger)**: 建立不綁死於遊戲畫面的 OS Window 與實體 Log 寫入機制。

### Phase 2: 核心遊戲迴圈與地圖重構 (Core Loop & Map Refactoring) [✅ 完成]
*   [x] **2.1 建立基礎狀態機**: 定義遊戲狀態 (WAITING_ROLL, MOVING, EVENT_HANDLING) 並實作防連點。
*   [x] **2.2 抽離地圖為自訂資源 (Godot Resource)**: 
    *   將 `CellData` (單格屬性) 與 `BoardData` (地圖陣列) 抽離為獨立的 `.tres` 檔案。
    *   導入 `next_nodes: Array[int]` 實作有向圖 (Directed Graph) 以支援未來的岔路系統。
    *   實作外部指定關卡與內建 `map_default.tres` (8字形) 的 Fallback 載入機制。
*   [x] **2.3 重構移動機制 (Step-by-Step Movement)**:
    *   廢除「直線飛往終點」的做法，改為以「剩餘步數」為核心的逐格移動。
    *   每走一步觸發「路過事件 (Passing Event)」(如路障、岔路選擇)。
    *   步數歸零時才觸發「落地事件 (Landing Event)」。
    *   實作禁止回走 (No Backtracking) 的有向圖走訪邏輯。
*   [x] **2.4 實作基礎格子邏輯**: 
    *   導入多型 Resource 架構，將 `CellData` 拆分為 `LandCellData`, `ChanceCellData` 等子類別。
    *   在 `Main.gd` 實作 Event Dispatcher，透過 `is` 關鍵字路由不同事件。
    *   實作基本的扣款、買地、路過起點領薪水等邏輯。

### Phase 3: GUI 與市場物價系統 (GUI & Dynamic Market) [🚧 進行中]
*   [x] **3.1 遊戲主介面**: 實作 `UIManager` 與側邊欄選單 (Settings, Status, Inventory, Map)。
*   [x] **3.2 玩家狀態視窗 (StatusUI)**: 實作獨立的模態視窗，包含資訊遮蔽 (Fog of War) 與動態載入的 Tree/Grid 佈局，可切換查看所有玩家狀態。
*   [ ] **3.3 商店面板**: 實作簡單的列表顯示可購買道具 (如：遙控骰子)。
*   [ ] **3.4 動態物價演算法**:
    *   實作 `MarketManager.gd`。
    *   每次購買道具，該道具「熱度值」+1，價格上漲 (例如 +10%)。
    *   每回合結束若無人購買，熱度值衰減，價格回落。
    *   UI 即時反映價格變化。

### Phase 4: 現實世界 API 串接 (Real-World Data Integration)
*   [ ] **4.1 建立 HTTPRequest 節點**: 在場景中加入節點準備發送請求。
*   [ ] **4.2 抓取外部資料**: 尋找免費的新聞或股市 API (如 NewsAPI, Finnhub)，實作 GET 請求取得當日頭條或指數。
*   [ ] **4.3 現實影響遊戲**: 解析 API 回傳的 JSON，提取關鍵字或漲跌幅，寫一個函式將其轉換為遊戲影響 (例如：「科技股上漲 2% -> 遊戲內所有過路費 + 20%」)，並顯示在 UI 系統訊息區。

### Phase 5: AI 命運之神 (Gemini Interactive Event) [🚧 進行中]
*   [x] **5.1 建立 AI 連線管理器 (AIManager)**: 實作讀取 `ai_config.json` 與雙路徑 (`user://`, `res://`) 的優雅降級。
*   [x] **5.2 串接 OpenAI 相容 API**: 實作 `HTTPRequest` 發送至 AI Endpoint，並測試成功。
*   [ ] **5.3 建立對話 UI**: 製作包含 `RichTextLabel` (顯示歷史對話) 與 `LineEdit` (玩家輸入) 的對話框面板。
*   [ ] **5.4 實作三回合對話機制**:
    *   **回合 1-2**: System Prompt 設定 AI 為神秘商人。將玩家輸入傳給 AI，AI 回傳對話顯示於 UI。
    *   **回合 3**: 強制 Prompt 要求 AI 總結對話，並輸出嚴格的 JSON 格式 (例如 `{"dialog": "最後一句話", "reward_money": 1000, "item": "none"}`)。
*   [ ] **5.5 事件結算**: 解析最後回合的 JSON，套用獎懲至 `PlayerStats`，並關閉對話框。

---

## 📈 進度追蹤表 (Progress Tracker)
- [x] Phase 1 完成
- [x] Phase 2 完成
- [ ] Phase 3 完成
- [ ] Phase 4 完成
- [ ] Phase 5 進行中

---
*文件建立日期: 2026-04-01*
### 📝 備忘錄 (Notes & Future Todos)
*   **遊戲起始設定 (Lobby Setup)**:
    *   目前許多影響開局的變數 (如 `PlayerData.gd` 內的初始現金、初始存款) 皆寫死。
    *   **未來實作**: 這些屬於「單局遊戲參數 (Match Parameters)」，在實作「主選單 (Main Menu)」或「開局大廳 (Lobby/Setup Room)」時，需建立對應的 UI 讓玩家選擇 (例如：初始資金 10,000 還是 20,000)，並在進入 `Main.tscn` 時傳入初始化。
    *   **區別**: 這些只在開局生效的參數，**不應**放入可隨時動態切換的 `SettingUI` 中。

### 7. 全域設定管理與單一資料來源 (Game Settings SSOT)
*   **決策**: 建立 `GameSettings.gd` (Resource 模型) 集中定義所有遊戲內可變的偏好與規則 (如：移動速度、AI 參與度、允許回頭走)。並註冊 `SettingsManager` 作為 Autoload 提供全域存取。
*   **原因**: 
    *   主邏輯腳本 (`Main.gd`, `Player.gd`) 嚴禁寫死這些會被切換的偏好設定，確保邏輯只關注「執行」，規則交由「模型」決定。
    *   達成「單一資料來源 (Single Source of Truth)」：當 `SettingUI` 更改設定時，所有讀取該值的系統能即時套用 (例如：移動動畫的 `Tween` 秒數)。

### 8. UI 元件化封裝 (UI Componentization)
*   **決策**: 針對專案特有、但 Godot 無原生對應的通用 UI 結構 (如：左右分段開關 `SegmentedSwitch`)，必須將其封裝為獨立的 Scene (`.tscn`) 與 Script (`.gd`)，存放於 `src/scenes/ui/components/`。
*   **原因**: 
    *   **DRY 原則 (Don't Repeat Yourself)**: 避免在不同的 UI 介面中重複手刻 `HBoxContainer` 與 `StyleBox` 排版，導致未來修改樣式時「牽一髮動全身」。
    *   **高度重用**: 透過暴露 `@export` 變數 (如按鈕文字) 與自訂 Signal (`option_selected`)，讓其他開發者 (或 UI) 可以直接在 Inspector 中拖拉使用，無需撰寫額外排版邏輯。
