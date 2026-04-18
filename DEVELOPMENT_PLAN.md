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

### 9. 傳統機會與命運系統 (Data-Driven Event System)
*   **決策**: 捨棄在程式碼中寫死 (`if-else`) 抽卡與效果邏輯，改為使用 `events_default.json` 配合 `EventProcessor` 執行指令 (Command Pattern)。
*   **原因**:
    *   **高擴充性**: 新增卡片或複合效果時，完全不需要修改 GDScript，企劃可直接編寫 JSON 即可。
    *   **無縫Fallback**: 如果 AI 模式關閉或連線失敗，遊戲可瞬間切換回 JSON 抽卡模式，確保遊戲流程不中斷。

### 10. 資料驅動道具系統 (Data-Driven Item System vs Handler Pattern)
*   **決策**: 放棄傳統的「道具 ID 查表法 (Handler Pattern)」，改用 Godot Custom Resource (`.tres`) 定義道具，並將邏輯拆解為可組合的指令 (Command Pattern) 交由 `EventProcessor` 執行。
*   **原因**: 
    *   **所見即所得 (WYSIWYG)**: 在 Inspector 可以直接預覽道具圖示與數值，對設計師/企劃友善。
    *   **無盡的擴充性**: 傳統 Handler 會產生幾千行的 `match` 語句，違反開放封閉原則 (OCP)。利用指令組合 (如 `add_cash`, `set_dice`)，不需寫任何程式碼即可創造無限種新卡片 (如「飛彈卡」可組合「扣別人錢」+「扣別人點數」)。
    *   **邏輯重用**: 與抽卡系統 (機會/命運) 共用同一套 `EventProcessor` 執行引擎，極度 DRY。

#### 📌 補充說明：事件指令規格 (Event Command Specs)
在 `events_default.json` 以及道具 `.tres` 檔案中的 `effects` 陣列內，每一項指令包含以下核心欄位：

| 欄位名稱 | 型別 | 說明 | 範例值 |
| :--- | :--- | :--- | :--- |
| **`cmd`** | String | 定義要執行的「動作本質」。 | `"add_cash"`, `"deduct_cash"`, `"set_dice"` |
| **`target`** | String | 定義該動作影響的「目標對象」或「空間範圍」。 | `"self"`, `"all"`, `"others"` |
| **`amount`** | Integer/Float | 定義該動作的「強度」或「數量」。 | `500` (加五百元), `6` (走六步) |
| *(可選)* `item_id` | String | 當 `cmd` 為 `add_item` 時，指定要給予的道具 ID。 | `"item_remote_dice"` |

> **執行流 (Execution Flow)**: 
> 1. 玩家踩中機會/命運，或點擊使用道具。
> 2. 系統取出資料中的 `effects` 陣列。
> 3. 將陣列傳遞給 `EventProcessor.execute_card()`。
> 4. `EventProcessor` 解析 `target`，將目標字串轉換為具體的 `PlayerData` 實體。
> 5. 針對每一個受影響的玩家，執行對應的 `cmd` 函式。

### 11. AI 決策邏輯與狀態分離 (AI Controller & Memory Extraction)
*   **決策**: 採用「策略模式 (Strategy Pattern)」，將玩家的決策行為從 `Main.gd` 抽離為獨立的 `PlayerBrain` 介面 (分為 `HumanBrain`, `LocalAIBrain`, `LLMAIBrain` 三種實作)。同時，將 AI 的長期記憶與性格狀態儲存於 `PlayerData` 的 `ai_memory` 字典中。
*   **原因**: 
    *   **無縫動態降級 (Graceful Degradation)**: 當連網的 `LLMAIBrain` 發生網路中斷時，系統可瞬間將玩家的大腦替換為 `LocalAIBrain`。因為記憶 (State) 存在於 `PlayerData` 而非大腦本身，AI 的性格與仇恨值完全不會遺失。
    *   **解決非同步災難**: `Main.gd` 不需再處理「本地 AI 瞬間決定」與「連網 AI 等待 API」的複雜 `await` 分支，只需統一呼叫 `await player.brain.decide_buy_land()`。
    *   詳見 `docs/ai_architecture_strategy.md`。

### 12. 全域圖層管理 (Z-Layer Management)
*   **決策**: 捨棄在各腳本中寫死 `z_index` (魔術數字)，建立全域的 `ZLayer.gd` (enum) 來統一控管所有節點的前後覆蓋關係。
*   **原因**: 
    *   專案變大後，經常發生「對話框被玩家蓋住」或「房子被格子蓋住」的顯示 Bug。
    *   統一管理後，圖層順序一目了然 (`BOARD(0)` < `CELL_ICON(10)` < `PLAYER_INACTIVE(20)` < `PLAYER_ACTIVE(30)` < `UI_OVERLAY(100)`)，開發新特效時只需調用 `ZLayer.` 即可，永遠不怕蓋錯。

### 13. 獨立圖標座標與防縮放繼承 (Dynamic Icon Offset & Scale Prevention)
*   **決策**: 在 `CellData` 導入獨立的 `icon_offset: Vector2` (相對偏移量)，並在 `Main.gd` 動態生成圖標節點 (`IconNode`) 時，將其作為 `board_node` 的子節點 (平級於格子)，而非格子的子節點。
*   **原因**: 
    *   **靈活的關卡設計**: 解決了大富翁環狀地圖「無方向性」的痛點。水平道路的房子可以長在上下，垂直道路可以長在左右，設計師能在 `.tres` 自由設定每格的 `icon_offset` 達成完美外圈排列。
    *   **避開縮放災難 (Scale Inheritance)**: 格子背景 (`Sprite2D`) 經常因為原始圖片大小不一而必須強制縮放 (`scale` < 1.0)。若把動態生成的 UI (`Label`) 放進去當子節點，字體與圖案會繼承縮放而變成奈米大小。將其抽離為平級節點並使用絕對座標 (`cell_position + icon_offset`)，能保證 1:1 的完美解析度。
*   **附帶視角優化**: 將 `initial_camera_pos` 與 `zoom` 寫入 `BoardData.tres` 達成 Data-Driven 視角，確保不同形狀的地圖載入時都能自動套用最棒的安全邊距 (Margin)。

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
*   [x] **3.3 物品卡片架構與背包系統**: 定義主動/被動道具資料結構 (JSON 或 Resource)，實作 InventoryUI 與道具指令效果 (Command Pattern)。
*   [ ] **3.4 商店面板**: 實作簡單的列表顯示可購買道具 (如：遙控骰子)。
*   [ ] **3.5 動態物價演算法**:
    *   實作 `MarketManager.gd`。
    *   每次購買道具，該道具「熱度值」+1，價格上漲 (例如 +10%)。
    *   每回合結束若無人購買，熱度值衰減，價格回落。
    *   UI 即時反映價格變化。

### Phase 4: 現實世界 API 串接與 AI 晨報系統 (Interactive Daily News Feed) [✅ 完成]
本階段將實作「AI 關鍵字晨報系統」，允許玩家在每日首次啟動遊戲時，輸入感興趣的時事關鍵字，並由 AI 將真實新聞轉化為遊戲內的機會/命運卡片。
*   **核心設計理念 (Separation of Concerns)**: 嚴格區分「遊戲外的新聞閱讀 (Pre-game)」與「遊戲內的卡片事件 (In-game)」。新聞的原始連結與詳細摘要僅在開局晨報中展示，進入遊戲後，時事將完全轉化為純粹的大富翁卡片機制 (如扣款、獲得道具)，確保遊戲心流 (Flow) 不被打斷。
*   [x] **4.1 實作關鍵字輸入介面 (Keyword Input UI)**: 在每日首次啟動時 (Cache Miss)，彈出視窗提供 3 個可選的輸入框，並帶有隨機預設的淺灰色提示詞 (如: 電玩, AI, 颱風)。若玩家未輸入，則使用預設關鍵字。
*   [x] **4.2 抓取真實新聞與 AI 轉化**: 
    *   將玩家的關鍵字組合成 Prompt 傳送給具備聯網搜尋能力 (Grounding) 的 LLM，或串接免費的新聞 API。
    *   要求 AI 擷取 3 則真實新聞 (包含標題、摘要、URL)，並根據這些新聞嚴格生成符合 `COMMAND_SCHEMA` 的機會/命運卡 JSON。
*   [x] **4.3 實作晨報展示介面 (Morning Briefing UI)**: 
    *   展示擷取到的真實新聞，並附上 `LinkButton` 讓玩家可在瀏覽器中打開原始新聞 (OS.shell_open)。
    *   展示「命運之神已將這些事件轉化為卡片混入牌堆」的提示。
    *   玩家點擊「開始遊戲 (Next)」後，關閉晨報，正式進入大富翁主迴圈，此後遊戲內不再出現任何外部新聞連結。

### Phase 5: AI 命運之神 (Gemini Interactive Event) [✅ 完成]
*   [x] **5.1 建立 AI 連線管理器 (AIManager)**: 實作讀取 `ai_config.json` 與雙路徑 (`user://`, `res://`) 的優雅降級。
*   [x] **5.2 串接 OpenAI 相容 API**: 實作 `HTTPRequest` 發送至 AI Endpoint，並測試成功。
*   [x] **5.3 實作受限的自由 (Bounded Freedom) API**: 擴充 `AIManager.gd`，在決算回合傳送嚴格的 System Prompt 與 JSON Schema，約束 AI 只能從允許的指令庫 (如 `add_cash`, `add_item`) 自由組合結果，確保遊戲邏輯不崩潰。導入「動態角色扮演 (Dynamic Personas)」解決單一 Prompt 疲勞。
*   [x] **5.4 建立對話 UI**: 製作包含 `RichTextLabel` (顯示歷史對話) 與 `LineEdit` (玩家輸入) 的 `DestinyDialogUI` 面板。實作三回合對話的協程狀態機與捲動防呆。
*   [x] **5.5 事件結算與指令執行**: 解析最後回合 AI 回傳的 JSON `effects` 陣列，直接交由 `EventProcessor` 執行，並優雅地透過 `ConfirmDialog` 彈窗向玩家展示結果。

---

## 📈 進度追蹤表 (Progress Tracker)
- [x] Phase 1 完成
- [x] Phase 2 完成
- [ ] Phase 3 進行中
- [x] Phase 4 完成
- [x] Phase 5 完成

---
*文件建立日期: 2026-04-01*

### 📝 備忘錄 (Notes & Future Todos)
*   **遊戲起始設定 (Lobby Setup)**:
    *   目前許多影響開局的變數 (如 `PlayerData.gd` 內的初始現金、初始存款) 皆寫死。
    *   **未來實作**: 這些屬於「單局遊戲參數 (Match Parameters)」，在實作「主選單 (Main Menu)」或「開局大廳 (Lobby/Setup Room)」時，需建立對應的 UI 讓玩家選擇 (例如：初始資金 10,000 還是 20,000)，並在進入 `Main.tscn` 時傳入初始化。
    *   **區別**: 這些只在開局生效的參數，**不應**放入可隨時動態切換的 `SettingUI` 中。
*   **道具系統架構 (Item System Architecture)**:
    *   **分類 (Types)**: 主動使用型 (如遙控骰子)、被動觸發型 (如烏龜卡、免死金牌)。
    *   **儲存 (Storage)**: 討論是否使用 JSON 還是 Custom Resource 儲存所有道具的資料 (名稱、圖示、效果指令)。
    *   **實作 (Implementation)**: 參考 Event Command Pattern，讓道具效果也能被指令化，避免寫死在腳本中。
    *   **UI**: 實作 `InventoryUI` 與 `ShopUI` 來展示與使用道具。
*   **世界事件與總體經濟系統 (World Events & Macroeconomics)**:
    *   **觸發時機**: 統一在一個完整回合 (Round) 結束時 (所有玩家皆行動過一次) 結算，確保每位玩家面對的經濟起跑點公平。
    *   **明面表現 (View)**: 觸發「世界事件」(如新聞快報、突發天災、股市大漲)，未來可與 Phase 4 的現實世界 API 結合。
    *   **暗面機制 (Model)**: 引入「通膨係數 (Inflation Rate)」。隨著回合推進或事件影響，全域的地價、過路費、道具價格會動態上升。這能有效消耗玩家後期過剩的現金，避免遊戲陷入僵局 (Stalemate)。

### 📝 背包介面 (Inventory) 與狀態介面 (Status) 的職責區隔 (Separation of Concerns)
在設計 UI 時，我們決定將 `InventoryUI` 與 `StatusUI` 拆分為兩個獨立的介面，雖然它們都會顯示玩家持有的「道具」，但其目的與互動層級完全不同：

1.  **狀態介面 (StatusUI - 唯讀 View)**：
    *   **目的**：提供全域的「情報探查」。玩家開啟它來觀看對手（或自己）的資產、持有的地產總覽，以及道具「數量」。
    *   **互動**：純展示，**不能**在此介面點擊道具或使用道具。它依賴 `PlayerData.get_public_view()` 獲取被資訊遮蔽 (Fog of War) 過濾後的資料。
2.  **背包介面 (InventoryUI - 可互動 Controller/View)**：
    *   **目的**：專屬於「當前行動玩家 (Current Player)」的戰術面板。
    *   **互動**：玩家在此查看自己道具的詳細說明（卡牌樣式），並點擊「使用 (Use)」或「丟棄 (Discard)」按鈕。
    *   **限制**：只有在玩家自己的回合 (例如 `WAITING_ROLL` 狀態) 才能開啟並操作。它直接讀取當前玩家的私有 `_items` 陣列。

這樣的 MVC 解耦確保了「看情報」與「下指令」不會混淆，未來就算加入 AI 對手或連線模式，權限控管也會非常清晰。


### 📝 通用對話框與事件中斷 (Generic Dialog & Event Interrupt)
在實作土地購買、升級，以及未來的「被動道具 (如免費卡)」時，我們需要一個非阻塞式的通用對話框 (Generic Dialog)。
*   **設計目標**: 
    1.  **非阻塞 (Non-blocking)**: 對話框彈出時，遊戲主迴圈 (`Main.gd`) 必須 `await` 玩家的決定，但**不能鎖死 UI**。玩家必須能自由切換到 `StatusUI` 查看自己或對手的資產，或打開 `Map` 查看地圖，然後再回來做決定。
    2.  **通用性 (Genericity)**: 支援「單選 (確認/關閉)」(例如：付過路費) 與「雙選 (是/否)」(例如：是否花 $1000 買地)。
    3.  **狀態機整合**: 在對話框開啟期間，`Main.gd` 的狀態機應處於 `EVENT_HANDLING`，防止玩家在此時再次擲骰子。
