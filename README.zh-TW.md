# DHRich4 - AI 驅動大富翁 🎲

*(For English, see [README.md](README.md))*

這是一個結合真實世界數據與 LLM (大語言模型) 的單機大富翁遊戲 Side Project。
採用 **Godot Engine 4.6 (GDScript)** 開發，以極簡的視覺風格與強大的 AI 事件邏輯為核心特色。

## 🌟 核心特色 (規劃中)

*   **極簡視覺**: 專注於遊戲邏輯與 API 互動，無須精美美術。
*   **動態市場**: 道具與房地產價格將隨機或受玩家供需行為影響。
*   **現實接軌**: 串接真實世界新聞與股市 API，動態改變遊戲數值 (例如科技股大漲帶動特定區域過路費)。
*   **AI 命運之神**: 踩到機會/命運格子時，與 AI (Gemini) 進行對話互動，由 AI 根據玩家態度決定獎懲。

## 🛠️ 開發環境與技術棧

*   **遊戲引擎**: [Godot Engine 4.6.1](https://godotengine.org/) (Standard version, GDScript)
*   **開發語言**: GDScript (具備強型別宣告)
*   **架構設計**: MVC (Model-View-Controller) 與 State Machine (狀態機)
*   **資源管理 (Data-Driven)**: 
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