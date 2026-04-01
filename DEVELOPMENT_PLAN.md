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

## 🤖 給 AI 協作夥伴的指示 (Instructions for AI Agents)
當使用者要求「執行 Phase X」或「實作某功能」時，請遵循以下原則：
1.  **語言**: 提供 GDScript 範例程式碼，並加上明確的型別提示 (Static Typing，如 `var money: int = 0`)，以符合 C++ 開發者的習慣。
2.  **架構**: 採用 MVC 思維，邏輯 (Data/State) 與 UI (Control Nodes) 盡量解耦。利用 Godot 的 `Signal` (觀察者模式) 進行跨節點溝通。
3.  **網路請求**: 使用 Godot 內建的 `HTTPRequest` 節點處理非同步 API 呼叫，並使用 `JSON.parse_string()` 解析資料。
4.  **動畫**: 移動皆使用 Godot `Tween` 節點實作，避免手刻 `_process` 裡的座標運算。
5.  **更新進度**: 完成任務後，請協助使用者更新本文件下方的 [進度追蹤表](#進度追蹤表-progress-tracker)。

---

## 🛠️ 階段開發藍圖 (Step-by-Step Roadmap)

### Phase 1: 基礎建設與平移動畫 (Foundation & Movement)
*   [ ] **1.1 建立 Godot 專案**: 在 Windows 下開啟 Godot 4，建立專案於 WSL 資料夾 (`/home/j8ohnny/workspace/DHRich4`)。
*   [ ] **1.2 建立地圖資料結構 (Model)**: 寫一個 GDScript (`MapManager.gd`)，定義環狀棋盤的每一格座標 (例如 Array of Vector2)。
*   [ ] **1.3 建立玩家節點 (View)**: 建立 `Sprite2D` 代表玩家，載入預設圖示 (`icon.svg`)。
*   [ ] **1.4 實作骰子與平移 (Controller)**:
    *   按空白鍵產生 1~6 亂數。
    *   計算目標格子座標。
    *   使用 `create_tween().tween_property(player, "position", target_pos, 0.5)` 實作平移。

### Phase 2: 核心遊戲迴圈 (Core Game Loop & State Machine)
*   [ ] **2.1 建立狀態機**: 定義遊戲狀態 (如 `WAITING_ROLL`, `MOVING`, `EVENT_HANDLING`, `END_TURN`)。
*   [ ] **2.2 定義格子事件**: 定義不同格子類型 (空地、商店、機會命運)。
*   [ ] **2.3 玩家資產系統**: 建立 `PlayerStats.gd` 記錄金錢、房地產。實作經過起點加錢、買地扣錢邏輯 (先以文字 `print` 輸出結果)。

### Phase 3: GUI 與市場物價系統 (GUI & Dynamic Market)
*   [ ] **3.1 遊戲主介面**: 使用 `CanvasLayer` 與 `Control` 節點 (Panel, Label) 顯示玩家當前金錢、骰子點數、回合數。
*   [ ] **3.2 商店面板**: 實作簡單的列表顯示可購買道具 (如：遙控骰子)。
*   [ ] **3.3 動態物價演算法**:
    *   實作 `MarketManager.gd`。
    *   每次購買道具，該道具「熱度值」+1，價格上漲 (例如 +10%)。
    *   每回合結束若無人購買，熱度值衰減，價格回落。
    *   UI 即時反映價格變化。

### Phase 4: 現實世界 API 串接 (Real-World Data Integration)
*   [ ] **4.1 建立 HTTPRequest 節點**: 在場景中加入節點準備發送請求。
*   [ ] **4.2 抓取外部資料**: 尋找免費的新聞或股市 API (如 NewsAPI, Finnhub)，實作 GET 請求取得當日頭條或指數。
*   [ ] **4.3 現實影響遊戲**: 解析 API 回傳的 JSON，提取關鍵字或漲跌幅，寫一個函式將其轉換為遊戲影響 (例如：「科技股上漲 2% -> 遊戲內所有過路費 + 20%」)，並顯示在 UI 系統訊息區。

### Phase 5: AI 命運之神 (Gemini Interactive Event)
*   [ ] **5.1 建立對話 UI**: 製作包含 `RichTextLabel` (顯示歷史對話) 與 `LineEdit` (玩家輸入) 的對話框面板。
*   [ ] **5.2 串接 Gemini API**: 實作 POST 請求發送至 Gemini REST API。
*   [ ] **5.3 實作三回合對話機制**:
    *   **回合 1-2**: System Prompt 設定 AI 為神秘商人。將玩家輸入傳給 AI，AI 回傳對話顯示於 UI。
    *   **回合 3**: 強制 Prompt 要求 AI 總結對話，並輸出嚴格的 JSON 格式 (例如 `{"dialog": "最後一句話", "reward_money": 1000, "item": "none"}`)。
*   [ ] **5.4 事件結算**: 解析最後回合的 JSON，套用獎懲至 `PlayerStats`，並關閉對話框。

---

## 📈 進度追蹤表 (Progress Tracker)
- [ ] Phase 1 完成
- [ ] Phase 2 完成
- [ ] Phase 3 完成
- [ ] Phase 4 完成
- [ ] Phase 5 完成

---
*文件建立日期: 2026-04-01*