# DHRich4 - AI 驅動大富翁 🎲

*(For English, see [README.md](README.md))*

這是一個結合真實世界數據與 LLM (大語言模型) 的單機大富翁遊戲 Side Project。
採用 **Godot Engine 4.6 (GDScript)** 開發，以極簡的視覺風格與強大的 AI 事件邏輯為核心特色。

## 🌟 核心特色 (規劃中)

*   **極簡視覺**: 專注於遊戲邏輯與 API 互動，無須精美美術。
*   **編輯器即時預覽**: 實作 `@tool` 專屬地圖預覽器，在地圖資源 `.tres` 修改的瞬間即可於編輯器內實時預覽方格與連線。
*   **動態市場**: 道具與房地產價格將隨機或受玩家供需行為影響。
*   **現實接軌**: 串接真實世界新聞與股市 API，動態改變遊戲數值 (例如科技股大漲帶動特定區域過路費)。
*   **AI 命運之神**: 踩到機會/命運格子時，與 AI (Gemini) 進行對話互動，由 AI 根據玩家態度決定獎懲。

## 🛠️ 開發環境與技術棧

*   **遊戲引擎**: [Godot Engine 4.6.1](https://godotengine.org/) (Standard version, GDScript)
*   **開發語言**: GDScript (具備強型別宣告)
*   **架構設計 (Architecture)**: 採用嚴格的 MVC 與動態實例化 (Instantiation) 模式。
    *   **Model (資料層)**: 
        *   `PlayerManager.gd` (AutoLoad): 管理全域玩家陣列。
        *   `PlayerData.gd`: 封裝單一玩家的資產與狀態，透過 `get_public_view()` 提供具備資訊遮蔽 (Fog of War) 權限判斷的 DTO (Data Transfer Object)。
        *   `BoardData.tres` / `CellData.gd`: 儲存地圖拓樸結構與全域經濟環境參數。
    *   **View (視圖層)**:
        *   `Main.tscn`: 遊戲主容器 (Host Scene)，包含攝影機、棋盤底圖、與 UI 畫布層。
        *   `PlayerEntity.tscn`: 獨立的棋子預製件，由 Controller 動態生成並載入頭像。
        *   `StatusUI.tscn`: 模態視窗預製件，包含玩家狀態、道具與地產的表格/網格排版。
    *   **Controller (邏輯層)**:
        *   `Main.gd`: 遊戲的主狀態機 (State Machine)，控制回合輪替、骰子動畫排程，並作為地圖事件的分發器 (Event Dispatcher)。
        *   `UIManager.gd`: 負責接收主畫面點擊事件，並負責動態實例化 (Instantiate) `StatusUI` 彈出視窗。
        *   `Player.gd`: 掛載於 `PlayerEntity`，專職處理座標平移 (Tween) 與 Z-Index 視覺突顯。
*   **全域圖層管理 (Z-Layer Management)**: 
    *   為防止 UI 互相遮擋 (例如對話框被玩家蓋住，或房子被格子蓋住)，專案中所有節點的渲染層級皆由單一來源 `ZLayer.gd` (Enum) 嚴格控管。
    *   圖層順序：`BOARD(0)` < `CELL_ICON(10)` < `PLAYER_INACTIVE(20)` < `PLAYER_ACTIVE(30)` < `UI_OVERLAY(100)`。
*   **資源管理**: 
    *   實作動態載入與 Fallback 機制，隔離私有資源與開源資源。
    *   **地圖系統完全資料驅動**：捨棄硬編碼，使用 Godot Custom Resources (`.tres`) 建立有向圖 (Directed Graph) 地圖結構，支援 8 字形與岔路走訪。

## 🚀 如何在本地端執行此專案

### 1. 安裝 Godot Engine
請至 Godot 官網下載 **Godot Engine 4.6.x (Standard 版本)**，無需安裝 .NET/C# 版本。

### 2. Clone 專案
```bash
git clone https://github.com/Blackohnny/DHRich4.git
cd DHRich4
```

### 3. 匯入 Godot
1. 開啟 Godot 編輯器。
2. 點擊 **"Import" (匯入)**。
3. 選擇本專案資料夾 (`src/`) 下的 `project.godot` 檔案。
4. 點擊 **"Import & Edit"**。
5. 在編輯器中按下 **F5** (或右上角的播放鍵) 即可開始遊戲！

## 🤖 如何啟用 AI 遊戲核心功能 (Setup AI Features)

本遊戲的兩大核心特色為 **「AI 命運之神互動」** 與 **「AI 每日時事生成」**。
為保護您的隱私與 API 費用，本專案不內建真實的 API Key。如果您希望在本地測試這些功能，請依照以下步驟設定：

1. 進入專案的 `src/` 目錄。
2. 找到 `ai_config.example.json` 檔案。
3. 將該檔案複製一份，並重新命名為 `ai_config.json`。
4. 打開 `ai_config.json`，填入您的 OpenAI 相容 Endpoint 與真實的 API Key。
5. 啟動遊戲。
   - **每日時事 (News)**：遊戲啟動時，系統會自動向 AI 索取今日最新的現實世界新聞，並生成專屬的機會命運卡混入牌堆。
   - **命運之神 (Destiny Dialog)**：當您踩中「機會」或「命運」格時，將觸發與 AI 神明的多回合互動，您的對話態度將決定最終的遊戲數值獎懲！

*(註：如果您未設定此檔案，或檔案內的參數不合法，遊戲不會崩潰，而是會觸發優雅降級 (Graceful Degradation)，退回無 AI 的傳統隨機抽卡模式。)*

## 🗺️ 所見即所得的地圖編輯器 (Map Live Preview)

本專案利用 Godot 的 `@tool` 系統，開發了專屬的 `MapPreviewer`，讓關卡設計變得極度直覺，完全無需修改程式碼。

### 如何即時編輯地圖：
1. 在 Godot 編輯器中打開 `src/scenes/Main.tscn`，你將會在畫面中央看到由方塊與箭頭連線組成的預覽圖。
2. 在左下角的 **FileSystem (檔案系統)** 中，雙擊開啟 `src/data/map_default.tres`。
3. 在右側的 **Inspector (屬性檢查器)** 中，展開 `Cells` 陣列。
4. 點開任何一個格子 (CellData)，嘗試拖曳修改它的 `Position` (X 或 Y 座標)。
5. **Live 修正**：在你拖曳座標的同時，`Main.tscn` 畫面上的方塊與連線會**即時 (Real-time)** 跟著滑鼠移動！

### 如何預覽其他地圖：
你可以利用 `MapPreviewer` 預覽任何地圖檔案：
1. 點擊 `Main.tscn` 場景樹中的 `MapPreviewer` 節點。
2. 在 Inspector 中找到 **Board Data** 屬性。
3. 將你想預覽的另一張 `.tres` 地圖檔從檔案總管拖曳進去，畫面將瞬間切換成新地圖。

---

## 🎨 資源管理與自訂圖片 (Fallback 機制)

本專案為了解決開發者使用**自訂/可能具版權疑慮的圖片**與**開源版本**之間的衝突，實作了獨特的 `ResourceManager` 資源覆寫 (Fallback) 機制。

### 資料夾結構
遊戲執行時，會透過腳本動態載入圖片資源。讀取順序如下：

1.  🥇 `src/assets/private_images/` (私有/高畫質/版權圖)
2.  🥈 `src/assets/public_images/` (開源/安全佔位圖)
3.  🥉 `src/assets/icon.svg` (Godot 預設圖示，終極救命防崩潰圖)

### 如何自訂你專屬的遊戲外觀？

如果你想要將遊戲內的格子或玩家替換成你喜歡的圖片 (例如某知名動畫的官方圖片)，請遵循以下步驟：

1.  準備你的圖片檔案 (例如 `Cyndaquil.png` 或 `Mew.png`)。
2.  將圖片放入 **`src/assets/private_images/`** 資料夾中。
3.  **大功告成！** 再次執行遊戲時，引擎會優先讀取你放入的高畫質圖片。

> **⚠️ Git 注意事項**
> 本專案的 `.gitignore` 已經設定為**強制忽略 `private_images/` 資料夾內的所有內容** (僅保留目錄結構)。
> 因此，你可以放心地在該資料夾內放入任何私人資源，它們**絕對不會**被推送到 GitHub 上，確保你的開源儲存庫合法且安全！

---
*詳細的開發階段與規劃，請參考 [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)*