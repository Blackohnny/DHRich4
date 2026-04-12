# DHRich4 AI 遊戲性與技術架構腦力激盪 (AI Brainstorming & Architecture)
*建立時間：2026-04-13*

## 🎯 執行摘要與核心哲學 (Executive Summary & Core Philosophy)
本文件完整記錄了將 LLM (大語言模型) 深度整合至 Godot 大富翁遊戲的構想與底層 API 實作細節。

> **【核心開發哲學：Godot 算物理，AI 算心理】**
> 絕對不要讓 AI 處理空間數學、窮舉運算或記憶冗長的流水帳。
> Godot (引擎端) 負責遍歷陣列、計算選項、過濾不合法的操作。
> AI (API 端) 負責評估局勢、演繹性格、進行戰略選擇與談判。

---

## Part 1: 遊戲性構想清單 (Gameplay Ideas)

### 1. 真正的 AI 電腦對手 (The True AI Player)
將傳統寫死的電腦對手，升級為具備 Persona 與記憶的 LLM 玩家。
*   **優點**: AI 會有性格 (如激進、保守)，能根據盤面優勢進行複雜決策，極大豐富重玩價值。
*   **挑戰**: Token 消耗大、API 延遲長。需透過「有限視野 (FOV)」與「非同步決策」解決。

### 2. 動態生成的事件池 (Daily/Live Event Generation)
每天或每次開局由 AI 讀取真實世界新聞 API，動態生成機會/命運卡片。
*   **優點**: 完美契合現有 `Phase 4` 與 `EventProcessor` 架構，零遊戲中 API 延遲。

### 3. 互動式機會命運 (Interactive Event - 現有 Phase 5 規劃)
踩中機會命運時，與 NPC 進行 3 句對話交涉，根據玩家態度給予不同獎懲。
*   **挑戰**: 需設計評分系統 (Sentiment Scoring)，避免黑箱作業帶來的挫折感。

### 4. 動態報表 / 新聞播報員 (The AI Announcer)
由 AI 扮演毒舌新聞主播，每隔數回合根據當前戰況播報短評 (背景非同步執行)。

### 5. 道具的創意使用 (Creative Item Usage)
導入「許願卡」，讓玩家自由輸入想要的效果，由 AI 判斷是否合理並執行。

### 6. 商店討價還價 (Shop Negotiation - 延伸自 Idea 5)
玩家在商店購買道具時，可針對單一商品與 AI 老闆進行一次性的討價還價。
*   **優點**: 玩家主動選擇的風險行為 (激怒老闆可能被趕出門)，策略性強且挫折感低。

---

## Part 2: AI 通訊核心概念與 Context 管理 (AI API Deep Dive)

### 2.1 AI 本身沒有記憶 (Statelessness)
每次呼叫 OpenAI 相容的 API（例如 Gemini），伺服器對過去的對話是一無所知的。多輪對話的魔法，來自於 Godot 客戶端每次發送請求時，將「過去所有的對話紀錄」打包進 `messages` 陣列中。

### 2.2 `messages` 陣列結構與 Payload 範例
`messages` 陣列維持了對話的上下文 (Context)，主要包含三種角色：
1.  **`system`**: 給 AI 的最高指導原則（人設、格式要求）。通常放第一筆，權重最高。
2.  **`user`**: 玩家發送的內容。
3.  **`assistant`**: AI 之前回覆的內容。

**Payload JSON 範例 (商店殺價 3 回合)：**
```json
{
  "model": "gpt-4o",
  "temperature": 0.7,
  "messages": [
    {
      "role": "system",
      "content": "你是道具店老闆，性格暴躁。原價1000。請嚴格輸出 JSON 格式：{\"final_price\": int, \"dialog\": \"string\"}"
    },
    {
      "role": "user",
      "content": "老闆，這遙控骰子 300 賣不賣？"
    },
    {
      "role": "assistant",
      "content": "{\"final_price\": -1, \"dialog\": \"滾！300 你連包裝盒都買不起！\"}"
    },
    {
      "role": "user",
      "content": "好啦好啦，那 800 可以了吧？\n\n[系統指令：請務必只輸出 JSON 格式。]"
    }
  ]
}
```

### 2.3 常見問題與解決方案
*   **注意力稀釋 (Lost in the Middle)**: 當對話變長，AI 會忘記最前面的 System 規則。
    *   **解法 (System Injection)**: 真正驅動 AI 行為的是「最後一個 User 訊息」。必須在最後一個對話末尾強制附加防呆指令（如上述範例最後一行的 `[系統指令...]`）。
*   **對話的連續性與幻覺 (Hallucination)**: 
    *   為了省 Token 刪減歷史紀錄時，**絕對不能漏傳單邊訊息**。如果只有 3 個 User 卻只有 2 個 Assistant 訊息，AI 會以為自己剛剛「已讀不回」，進而腦補或瞎掰出未曾發生的對話。
    *   **解法 (Drop Pairs)**: 滑動視窗必須「成對刪除」最舊的 `[User 問, Assistant 答]`。

### 2.4 結構化對話 vs. 文字總結
*   **結構化陣列 (保留 3 次 JSON `messages`)**: 
    *   適用場景：短期交涉 (商店殺價)。
    *   優點：AI 對「這句話是誰說的」認知極度清晰，能完美維持剛剛暴躁或諂媚的情緒連貫性。
*   **文字總結 (注入 System Prompt)**:
    *   適用場景：跨回合長期記憶 (如 10 回合前誰炸了誰)。
    *   優點：極度節省 Token。AI 只需要「知道」那件事發生過，不需維持 10 回合前的語氣。

---

## Part 3: 高級 AI 玩家實作架構 (Advanced Agentic Workflow)

### 3.1 有限視野與自主記憶 (FOV & Scratchpad)
不要把 100 格的全地圖資料丟給 AI，這會導致 API 延遲與注意力失焦。
*   **RAG 空間過濾**: 只傳送 AI 當下可見的範圍 (如：手上有骰子，只傳前方 6 步的收費站與機會命運)。
*   **AI 自主記憶暫存區 (Scratchpad)**: 允許 AI 在輸出的 JSON 決策中加入 `memory_note` (限制 300 字)。Godot 在下回合將此筆記作為記憶塞回 Prompt，讓 AI 能執行「跨回合的長期策略」(如：這回合先買便宜地，筆記寫下次蓋房子)。

### 3.2 代理人工作流與任務拆解 (Agentic Workflow for Complex Items)
LLM 極度不擅長空間數學運算。面對「飛彈 (全地圖 9x9 範圍)」這種複雜道具，必須將思考過程拆解：
1.  **戰略意圖 (API Call 1)**: 問 AI 是否要發射？首要打擊目標是誰？
2.  **引擎代算 (Godot 內部)**: Godot 掃描全地圖，精確計算出 3 個能炸到目標的最佳座標，並評估附帶損害。
3.  **戰術決斷 (API Call 2)**: 將這 3 個選項交給 AI，由其性格決定最終發射座標。

### 3.3 行動決策樹與高階意圖選單 (Action Selection)
為防止 AI 產生「一邊發射飛彈一邊走 3 步」的不合法操作，Godot 必須提供階段式的高階意圖選單。
*   **Phase 1 (道具階段)**: Godot 像畫 UI 一樣，生成一份 JSON 選單給 AI (包含手上可用道具與「跳過」)。AI 只能從中選擇。
*   **Phase 2 (移動階段)**: 道具用完或跳過後，Godot 根據狀態 (是否用了遙控骰子) 決定是否需再次呼叫 API 詢問步數，或直接代為擲骰。

### 3.4 戰術選項的多樣性 (Tactical Diversity)
在 Godot 代算飛彈座標時，不能只提供「傷害最高」的選項，否則防守型 AI 將無從發揮。
Godot 必須提供不同維度的極端選項：
*   `[選項 A - 斬首戰術]`: 對第一名造成最大財產破壞。
*   `[選項 B - 焦土戰術]`: 一次炸毀最多棟建築，但波及自己。
*   `[選項 C - 開路戰術]`: 清除前方 6 步內的危險收費站。
如此一來，攻擊型 AI 會選 A，防守型 AI 會選 C，真正將 **"Godot 的物理計算"** 與 **"AI 的靈魂 (性格判斷)"** 完美結合。
