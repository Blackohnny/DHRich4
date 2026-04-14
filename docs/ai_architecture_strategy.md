## 4. 動態降級與連線管理 (Dynamic Degradation & Connection Management)
在實作 `GeminiAIBrain` 與 `AIManager` 時，必須考量到網路的不穩定性與使用者設定的動態變化。
系統必須具備一套嚴謹的「動態換腦 (Brain Swapping)」機制，確保遊戲流程永遠不會因為 AI 連線問題而卡死。

### 4.1 觸發降級 (Fallback) 的情境
1.  **開局/載入時 (Initialization)**: 未來在遊戲大廳 (Lobby) 必須實作「測試連線 (Test Connection)」按鈕。只有在讀取設定檔 (`ai_config.json`) 且測試連線成功後，才能將玩家的大腦實例化為 `GeminiAIBrain`。否則，預設使用 `LocalAIBrain`。
2.  **遊戲進行中連線失敗 (Runtime Failure)**:
    *   當 `GeminiAIBrain` 呼叫 `AIManager` 發送請求時，若發生 Timeout 或授權錯誤 (HTTP 401/403 等)。
    *   **處理流程**: 彈出系統對話框 (System Dialog) 提示使用者「AI 連線失敗」。
    *   **使用者抉擇**: 
        *   [重試 (Retry)]: 再次發送相同的 API 請求。
        *   [放棄並降級 (Fallback)]: 系統發出全域訊號，`PlayerManager` 將該玩家的大腦動態替換為 `LocalAIBrain`，並以此本地邏輯繼續完成當前決策，遊戲不中斷。
3.  **使用者手動關閉 (User Intervention)**: 玩家在遊戲進行中打開「設定 (Settings)」，手動將 `ai_enabled` 設為 `false`。
    *   **處理流程**: `SettingsManager` 發出 `ai_setting_changed(false)` 訊號。`PlayerManager` 捕捉後，將場上所有 `GeminiAIBrain` 強制替換為 `LocalAIBrain`。

### 4.2 恢復連線 (Recovery) 的情境
當使用者手動降級，或因錯誤而被迫降級後，若想重新啟用 LLM AI：
*   必須在「設定 (Settings)」介面中，再次進行「測試連線」。
*   只有連線測試成功，系統才會發出 `ai_setting_changed(true)` 訊號。
*   `PlayerManager` 收到訊號後，根據開局設定，將原本應該是真 AI 的玩家，從 `LocalAIBrain` 替換回 `GeminiAIBrain`。

這套機制完美落實了「策略模式 (Strategy Pattern)」的優勢：大腦本身依然是純粹的無狀態邏輯 (Stateless)，而降級與恢復的調度 (Orchestration) 由上層的 `PlayerManager` 與 `UIManager` 負責。
# AI 決策系統架構設計與演進 (AI Architecture Strategy)

本文件紀錄了 DHRich4 專案中，關於「電腦玩家 (AI Player)」決策系統的架構設計討論與最終共識。
討論時間：2026-04-13

## 1. 痛點分析 (Problem Statement)
在早期的 MVP 實作中，AI 的決策邏輯（如：是否購買土地、是否升級房屋）是直接寫死在遊戲主迴圈 `Main.gd` 與資料模型 `PlayerData.gd` 之中，透過簡單的 `if is_ai:` 判斷。

隨著專案核心目標「結合 LLM (Gemini) 進行動態互動」的推進，這種設計暴露出嚴重的架構缺陷：
*   **違反開閉原則 (OCP)**: 每次新增一種 AI 行為或難度，都必須修改核心的遊戲迴圈程式碼。
*   **非同步災難 (Asynchronous Hell)**: 本地寫死的 AI 決策是瞬間完成的，但連網的 LLM AI (Gemini) 需要等待網路回應。將兩者混在同一個 Controller 函式中處理 `await` 將導致邏輯極度混亂。
*   **缺乏優雅降級 (Graceful Degradation)**: 若玩家在遊戲中途網路斷線，無法在不中斷遊戲的情況下，將「連網 AI」無縫切換回「本地 AI」。

## 2. 最終架構決策：策略模式與狀態分離 (Strategy Pattern & State Separation)

為了解決上述痛點，我們決定採用 **策略模式 (Strategy Pattern)** 結合 **資料與行為分離 (Entity-Component/Model-Controller Separation)** 的進階架構。

### 2.1 剝離決策行為 (The Brain Interface)
建立一個抽象的基底類別 (Base Class) `PlayerBrain`，定義所有需要玩家決策的介面（Virtual Functions）。
```gdscript
class_name PlayerBrain extends RefCounted
func decide_buy_land(land: LandCellData, player_data: PlayerData) -> bool: return false
# ... 其他決策介面
```

並衍生出三種具體的「大腦」實作：
1.  **`HumanBrain` (真人玩家)**: 實作會呼叫 `UIManager` 彈出互動視窗，並 `await` 使用者的按鈕點擊。
2.  **`LocalAIBrain` (本地寫死 AI)**: 實作會根據當前資金與保留底線 (Reserve Cash)，瞬間返回決策結果。
3.  **`GeminiAIBrain` (連網 LLM AI)**: 實作會將當前局勢打包為 Prompt，委派給全域的 `AIManager` 發送網路請求，並 `await` 雲端回覆後解析結果。

> **架構優勢**: `Main.gd` 完全不需要知道當前玩家是人類還是哪種 AI，只需統一呼叫 `await current_player.brain.decide_buy_land(...)` 即可。

### 2.2 記憶與靈魂的歸屬 (Separation of State and Behavior)
**痛點**: 若實作動態抽換大腦 (例如斷線時將 `GeminiAIBrain` 換成 `LocalAIBrain`)，大腦內部的記憶（如：性格、仇恨值、短期目標）會隨著實體被銷毀而遺失。

**決策**: 大腦 (`PlayerBrain`) 必須是 **無狀態的 (Stateless / Pure Function)**。所有關於 AI 個體差異的「長期記憶」與「狀態」，必須集中儲存在資料模型 `PlayerData.gd` 中。

```gdscript
# 在 PlayerData.gd 中擴充
var ai_memory: Dictionary = {
    "personality": "aggressive", # 性格設定
    "target_land_id": -1,        # 欲購買的目標地產
    "aggro_table": {}            # 對其他玩家的仇恨值
}
```

*   **本地 AI 讀取**: `LocalAIBrain` 進行決策時，讀取 `player_data.ai_memory["personality"]` 來決定其投資激進程度。
*   **LLM AI 讀取**: `GeminiAIBrain` 將 `ai_memory` 轉換為 System Prompt 的一部分（例如：「你是一個激進的玩家，你現在非常討厭玩家 1...」），並可透過 LLM 的 JSON 回覆動態更新這個記憶庫。
*   **無縫切換 (Painless Swapping)**: 當網路斷線觸發降級時，系統只需執行 `player.set_brain(LocalAIBrain.new())`。新的大腦接手後，依然能讀取同一份 `ai_memory`，AI 的性格與仇恨值完全不會中斷。

## 3. 未來實作路徑 (Implementation Roadmap)
1.  建立 `PlayerBrain.gd` 介面。
2.  實作 `HumanBrain.gd` 並將 `Main.gd` 中所有彈出 `ConfirmDialog` 的邏輯遷移至此。
3.  實作 `LocalAIBrain.gd` 並將防破產等基礎數學邏輯遷移至此。
4.  擴充 `PlayerData.gd` 包含 `brain` 實體參考與 `ai_memory` 字典。
5.  （Phase 5）實作 `GeminiAIBrain.gd` 並與 `AIManager` 網路層串接。
