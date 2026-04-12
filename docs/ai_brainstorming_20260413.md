# DHRich4 AI 遊戲性腦力激盪 (AI Brainstorming)
*建立時間：2026-04-13*

本文件記錄了如何將 LLM (大語言模型) 深度整合至大富翁遊戲機制的各種構想，並分析其優缺點與技術可行性。

## 1. 真正的 AI 電腦對手 (The True AI Player)
將傳統以「權重樹」或「狀態機」寫死的電腦對手，升級為具備 Persona 與記憶的 LLM 玩家。

*   **遊戲性 (Fun Factor)**:
    *   **性格與記憶**: AI 會有不同的 Persona (如激進投資客、保守守財奴、復仇者)。他們會「記得」上一回合誰收了他高額過路費，並在接下來的行動中針對該玩家。
    *   **不可預測的策略**: AI 不再只是無腦買地，能根據當前盤面優勢 (誰最有錢、誰即將破產) 進行複雜的道具使用與投資決策。
*   **優點**: 極大豐富了單機遊戲的重玩價值與對抗樂趣。
*   **缺點**: 
    *   **Token 消耗大**: 每回合都需要傳遞大量盤面狀態給 AI。
    *   **遊戲節奏拖沓**: API 延遲會導致 AI 思考時間過長。
*   **技術挑戰 (Technical Feasibility)**: 
    *   需要設計極為精簡的 Prompt (JSON State 序列化) 來描述盤面。
    *   需要實作「非同步決策 (Asynchronous Decision Making)」，讓 AI 在背景提早思考，避免卡死主執行緒。

## 2. 動態生成的事件池 (Daily/Live Event Generation)
結合現實世界新聞 API，每天或每次開局由 AI 動態生成獨特的機會/命運卡片。

*   **遊戲性 (Fun Factor)**:
    *   **時事結合**: 玩家抽到的不再是千篇一律的「中大獎 2000 元」，而是「輝達發布新晶片，科技園區地主獲利 3000 元」。
*   **優點**: 
    *   完美契合現有 `Phase 4` (現實世界串接) 與 `EventProcessor` 架構。
    *   只要 AI 輸出的 JSON 符合既有的 Command Schema (`cmd`, `target`, `amount`)，底層系統完全不需要改動。
    *   開局時一次性生成，遊戲過程中無 API 延遲。
*   **缺點**: 無即時互動感。
*   **技術挑戰 (Technical Feasibility)**: 
    *   需要穩定的外部新聞 RSS 或 API 來源。
    *   要求 AI 生成嚴格符合現有 JSON Schema 的卡片資料。

## 3. 互動式機會命運 (Interactive Event - 現有 Phase 5 規劃)
將踩中機會命運的過程，轉變為與 NPC 的 3 句對話交涉，根據玩家態度給予不同獎懲。

*   **遊戲性 (Fun Factor)**:
    *   **交涉與說服**: 玩家不再只是被動接受結果。你可以試圖賄賂貪官、或是在法庭上為自己辯護。
    *   **隱藏條件 (Hidden Constraints)**: NPC 有隱藏的喜好或底線，玩家需要透過對話去「試探」。
*   **優點**: 創造出大富翁中前所未有的 RPG 角色扮演體驗。
*   **缺點**: 
    *   對話頻繁可能導致節奏拖慢。
    *   如果結果最終還是隨機的，玩家會產生「說服無效」的挫敗感 (Blackbox 效應)。
*   **技術挑戰 (Technical Feasibility)**: 
    *   需要設計評分系統 (Sentiment/Negotiation Scoring)，將文字對話量化為具體的遊戲數值 (例如 `attitude_score: 1~10`)。
    *   UI 需要實作對話框與歷史紀錄。

## 4. 動態報表 / 新聞播報員 (The AI Announcer)
由 AI 扮演毒舌新聞主播，每隔數回合根據當前戰況播報短評。

*   **遊戲性 (Fun Factor)**:
    *   **直播氛圍**: 「目前最窮的玩家竟然又買了一塊爛地，看來破產只是時間問題...」
*   **優點**: 
    *   實作成本極低。
    *   完全在背景非同步執行，完全不影響遊戲核心操作節奏。
    *   Token 消耗少。
*   **缺點**: 純裝飾性，不影響遊戲實質勝負。
*   **技術挑戰 (Technical Feasibility)**: 僅需將定期將核心數據 (財富排行) 轉字串丟給 AI 即可。

## 5. 道具的創意使用 (Creative Item Usage)
導入「許願卡」，讓玩家自由輸入想要的效果 (例如：「我要讓對手下回合倒退 3 步」)，由 AI 判斷是否合理並執行。

*   **遊戲性 (Fun Factor)**:
    *   **極高自由度**: 突破傳統道具的限制，玩家可以根據當下局勢發明新玩法。
    *   **等價交換**: AI 會評估玩家提出的條件 (例如願意付出多少代價) 是否合理，不合理則駁回。
*   **優點**: 讓玩家感覺真正在與一個有智慧的 GM (Game Master) 互動。
*   **缺點**: 容易被玩家找出 Prompt 漏洞 (Prompt Injection) 導致平衡崩壞。
*   **技術挑戰 (Technical Feasibility)**: 需要極高難度的 Prompt 工程，確保 AI 生成的 Command 既符合玩家創意，又不超出遊戲底層引擎支援的極限 (必須 mapping 到現有的 `cmd` 列表)。

## 6. 商店討價還價 (Shop Negotiation - 延伸自 Idea 5)
玩家在商店購買道具時，可以選擇與 AI 老闆針對單一商品進行「一次性」的討價還價。

*   **遊戲性 (Fun Factor)**:
    *   **風險與報酬 (Risk vs Reward)**: 殺價成功可省錢，但如果激怒老闆 (例如出價太低或態度太差)，老闆可能會拒絕交易甚至漲價。
    *   **探索 Persona**: 每次進商店的老闆性格可能不同 (如：急需現金的賭徒、自尊心高的職人)，玩家需要試探底線。
*   **優點**: 
    *   比起「命運強制互動」，商店殺價是**玩家主動選擇**的風險行為，挫折感較低。
    *   單回合文字輸入，無冗長對話，節奏較快。
*   **缺點**: 如果老闆性格太單一，玩家可能會找出固定的殺價套路 (最佳解)。
*   **技術挑戰 (Technical Feasibility)**: 
    *   需要強硬的 System Prompt 確保 AI 回傳包含最終價格與對話的嚴格 JSON 格式 (`{"final_price": int, "shopkeeper_dialog": "string"}`)。
    *   UI 狀態管理：殺價等待 API 回應期間 (Loading)，必須鎖定其他購買操作。

## 7. AI 玩家的狀態管理與記憶機制 (AI Player State Management & Memory)
探討如何將複雜的大富翁盤面狀態傳遞給 AI 玩家，並分析其技術負擔與可行性策略。

### 傳輸資料量與負擔 (Payload Size & Overhead)
目前主流 LLM (如 Gemini 1.5, GPT-4o) 的 Context Window 非常大 (128K ~ 2M Tokens)，因此「能不能傳」不是問題，問題在於：
1.  **API 延遲 (Latency)**: 雖然能傳幾萬字，但 Input Tokens 越多，API 的 First-Byte 回應時間越長，這會嚴重拖垮大富翁這種需要快速輪轉的遊戲節奏。
2.  **Token 成本 (Cost)**: 如果每回合都把完整的 100 格地圖資料傳給 AI，每回合可能消耗 2000~5000 Tokens。一場 50 回合的遊戲，4 個 AI 玩家，光是一局遊戲就會消耗超過百萬 Tokens。
3.  **注意力稀釋 (Lost in the Middle)**: 傳遞過多無關的資料 (例如離 AI 還有 30 步遠的便宜空地)，反而會干擾 AI 的決策，導致它忽略近在眼前的破產危機。

### 解決方案：精準的狀態視角 (Targeted State Perspective)
與其傳送「全局 (Global State)」，不如只傳送 AI 當下「可見與可操作的範圍 (Local/Actionable State)」。

*   **玩家狀態摘要 (Player Stats Summary)**:
    只傳送關鍵數值，避免傳送冗長的歷史。
    ```json
    {
      "me": {"cash": 5000, "deposit": 10000, "items": ["遙控骰子", "路障"]},
      "opponents": [
        {"id": "p2", "cash": 500, "is_bankrupt_risk": true},
        {"id": "p3", "cash": 25000, "threat_level": "high"}
      ]
    }
    ```
*   **視野範圍內的地圖資料 (Field of View - FOV)**:
    你提到的「只傳 6 步內的地圖資料」是非常高明的做法！這完全符合「視距 (Line of Sight)」的概念。
    如果 AI 只有一顆骰子 (1~6步)，他只需要知道這 6 格的風險與機會。
    ```json
    "upcoming_cells": [
      {"steps": 1, "type": "land", "owner": "p3", "toll": 4000, "danger": true},
      {"steps": 2, "type": "chance", "event": "unknown"},
      {"steps": 6, "type": "land", "owner": "none", "price": 1000}
    ]
    ```

### 革命性構想：AI 的自主記憶暫存區 (Self-Managed Memory Buffer)
你提出的「讓 AI 自己決定要保留 300 字元的記憶」是非常前沿的 Agent 設計模式 (如 AutoGPT 的 Scratchpad)！

*   **運作方式 (How it works)**:
    在 AI 每個回合輸出的 JSON 決策中，增加一個 `internal_monologue` 或 `memory_note` 欄位。
    ```json
    {
      "action": "use_item",
      "target": "p3",
      "item_id": "item_roadblock",
      "memory_note": "P3 很有錢而且前面就是他的大怪獸地，我放了路障。下回合要注意他會不會報復，如果他靠近我，我要準備用烏龜卡逃跑。"
    }
    ```
*   **下一回合的 Input (Next Turn Injection)**:
    當下一回合輪到這個 AI 時，你將這段 `memory_note` 作為「他的大腦前額葉暫存」塞回給他：
    `[你的上一回合筆記]: "P3 很有錢而且前面...準備用烏龜卡逃跑。"`
*   **優勢 (Advantages)**:
    1.  **極度節省 Token**: 你不需要傳送過去 10 回合的完整重播，只要傳這 300 字。
    2.  **長期連貫性 (Long-term Coherence)**: AI 可以透過這個機制「規劃未來」(例如：先買便宜地，筆記寫「下次有錢再來蓋房子」)。
    3.  **性格塑造**: 不同 Persona 的 AI 寫出來的筆記會完全不同，有些可能是冷酷的算計，有些可能是情緒發洩，這本身也可以做成遊戲內的一個有趣功能 (例如：玩家可以使用「駭客卡」偷看 AI 的大腦筆記！)。

## 8. AI API 對話記憶機制 (Understanding AI Statelessness & Context Management)
釐清如何讓「無狀態 (Stateless)」的 AI API 能夠記得前幾回合的對話，並應用於遊戲開發中。

### 核心觀念：AI 本身沒有記憶
*   每次呼叫 OpenAI 相容的 API（例如 Gemini 的 Chat API），伺服器對過去的對話是一無所知的。
*   所謂的多輪對話（ChatBot），是因為**客戶端（Godot 遊戲）在每次發送請求時，將「過去所有的對話紀錄」打包進 `messages` 陣列中傳給 AI。**

### `messages` 陣列結構 (The Context Array)
1.  **`system`**: 給 AI 的最高指導原則（人設、格式要求）。通常放在陣列的第一筆，擁有最高的注意力權重。
2.  **`user`**: 玩家發送的內容。
3.  **`assistant`**: AI 之前回覆的內容。

### 常見問題與解決方案 (Common Pitfalls & Solutions)
*   **問題 1：Token 消耗與延遲 (Token Cost & Latency)**
    *   **原因**: 對話不斷 Append，導致 `messages` 陣列越來越大，每次請求都需要發送數千字。這不僅耗費大量 API 費用，更會拖慢回應速度。
*   **問題 2：規則稀釋 / 中間遺忘效應 (Context Dilution / Lost in the Middle)**
    *   **原因**: 隨著對話變長，AI 會逐漸忘記放在陣列最前面的 `system` 規則（例如要求嚴格輸出 JSON 格式）。
    *   **解法 (System Injection)**: 在每一輪玩家輸入的 `user` content 後面，偷偷加上一段強烈的「系統指令」提醒。
        例如：`"玩家的對話內容...\n\n[系統指令：請務必只輸出 JSON 格式。]"`。將規則放在最靠近結尾的地方，AI 遵守的機率最高。
*   **解決方案：滑動視窗記憶 (Sliding Window Memory)**
    *   **作法**: 在 Godot 腳本中，只保留最近 N 回合的對話紀錄（例如只存最近 3 輪的 `user` 與 `assistant` 對話）。
    *   **優勢**: 極大程度節省 Token，並保持 AI 的注意力集中在當前的交涉上，避免被久遠前的對話干擾。

### Payload 範例 (JSON Example of Context Array)
以下是一個簡單的「商店殺價」對話陣列範例，展示了如何組合 `system` (人設)、`user` (玩家出價)、與 `assistant` (老闆前次的回覆)。

```json
{
  "model": "gpt-4o",
  "temperature": 0.7,
  "messages": [
    {
      "role": "system",
      "content": "你是道具店老闆，性格暴躁。原價1000，只能用繁體中文回答。請根據對話嚴格輸出 JSON 格式：{\"final_price\": int, \"shopkeeper_dialog\": \"string\"} (可拒絕交易設為 -1)。"
    },
    {
      "role": "user",
      "content": "老闆，這遙控骰子 300 賣不賣？"
    },
    {
      "role": "assistant",
      "content": "{\"final_price\": -1, \"shopkeeper_dialog\": \"滾！300 你連包裝盒都買不起！\"}"
    },
    {
      "role": "user",
      "content": "好啦好啦，那 800 可以了吧？我真的只有這麼多錢了。\n\n[系統指令：請務必只輸出 JSON 格式。]"
    }
  ]
}
```

### AI 回答的決定因素 (Who makes the call?)
*   **來回對話 (Historical Context)**:
    在 `messages` 陣列中間的那些 `user` 和 `assistant` 的來回對話，確實**只是給 AI「參考」用的**。它幫助 AI 了解你們剛才聊了什麼、氣氛如何、玩家出過什麼價。
*   **實際有效指令 (The Actionable Prompt)**:
    真正驅動 AI「這次要回答什麼」的，永遠是陣列裡面的**最後一個 `user` 訊息**。
    所以，如果你希望 AI 在讀完落落長的對話歷史後，不要忘記他現在的任務是「輸出 JSON」，最保險的做法就是在這最後一個訊息的尾巴，強硬地補上你的系統指令 (也就是所謂的 System Injection)。

### 對話架構的影響 (Does the structure matter? What if I skip an assistant message?)
你問到一個非常有趣且深入的 AI 運作機制問題：**這些對話架構是有意義的嗎？如果故意少傳一個 assistant 訊息會怎樣？**

答案是：**非常有意義，而且 AI 會很容易被這種「不自然的對話歷史」搞混，甚至出現幻覺 (Hallucination)。**

#### 為什麼會這樣？(Why does the structure matter?)
LLM (大語言模型) 本質上是一個「接字機器 (Next-Token Predictor)」。它在閱讀 `messages` 陣列時，是把它當成一個「已經發生過的劇本」在讀。
它預期的標準劇本是：`User 問 -> Assistant 答 -> User 問 -> Assistant 答...`

#### 如果你故意漏掉一個 `assistant` 回覆 (3 User, 2 Assistant)：
假設你的 Payload 長這樣：
```json
[
  {"role": "user", "content": "老闆這多少錢？"},
  {"role": "assistant", "content": "1000元。"},
  {"role": "user", "content": "太貴了，300 賣不賣？"},
  // (這裡你故意不傳 assistant 拒絕的回答)
  {"role": "user", "content": "老闆你幹嘛不講話？到底賣不賣啦！"}
]
```

**AI 收到這個 Payload 時，會發生什麼事？**
1.  **AI 會以為自己「真的沒講話」**：因為在他的認知裡，這份 `messages` 就是全部的歷史。他看到玩家連續講了兩句話（"太貴了..." 和 "老闆你幹嘛..."），而中間他確實沒有回覆。
2.  **AI 的回答會出現「填補空白」或「幻覺」**：
    *   他可能會順著玩家的話演下去：「抱歉抱歉，我剛剛在算帳沒聽到。300 真的沒辦法...」
    *   他也可能會覺得奇怪：「我有講話啊？（如果他的 System Prompt 設定很強勢）」
    *   **最糟的情況 (嚴重的幻覺)**：AI 為了讓對話邏輯連貫，可能會**自己腦補出一個從未發生過的事實**。例如：「我剛剛不是說了 500 嗎？你到底有沒有在聽！」（即使你根本沒傳過 500 這個數字）。

#### 結論 (Conclusion)
*   **對話的連續性 (Coherence)** 遠比對話的長度重要。
*   如果你要為了節省 Token 而刪減對話，**絕對不能只刪單邊**。
*   正確的「滑動視窗」做法是：**成對刪除 (Drop Pairs)**。你要刪除，就要把最舊的那組 `[User 問, Assistant 答]` 一起刪掉，讓剩下的對話歷史仍然是邏輯連貫的問答。

### 結構化對話 (Structured Array) vs. 文字總結 (Text Summarization)
你提出了一個非常進階的實作問題：**「保留 3 次的 JSON `messages` 陣列對話紀錄」與「我把前 3 次的對話總結成一段文字 (如：『我跟你說 OOO，你回答 XXX...』) 塞進最新一句話裡傳過去」有什麼差別？**

這兩者在結果上都達到了「傳遞上下文 (Context)」的目的，但在 AI 的理解與你的實作成本上有很大的差異：

#### 1. 結構化陣列 (Structured `messages` Array)
*   **作法**: 將歷史對話嚴格區分為 `{"role": "user", "content": "..."}` 和 `{"role": "assistant", "content": "..."}` 的多個物件。
*   **優點**:
    *   **角色認知極度清晰**: 模型在底層訓練時，就是看著這種 `<User>...</User><Assistant>...</Assistant>` 的標籤長大的。它能 100% 確定哪句話是誰說的、情緒是誰的。
    *   **情緒與語氣的連貫性**: 因為它看到的是「原汁原味」的自己剛剛說的話，它能完美接續上一句的暴躁或諂媚語氣。
*   **缺點**: 佔用的 Token 較多（每次都要重複傳送大量完整的句子與 JSON 標籤）。

#### 2. 文字總結/情境注入 (Text Summarization / Prompt Injection)
*   **作法**: 將歷史對話壓縮成一段敘述，塞入 `system` 或最後一個 `user` 訊息中。
    例如：`{"role": "user", "content": "[前情提要：我剛剛出價 300 你拒絕了，還罵我窮酸。]\n那 800 可以了吧？"}`
*   **優點**:
    *   **極度節省 Token**: 這就是前面提到的「自主記憶暫存 (Scratchpad)」概念的延伸。你用極少的字數總結了過去 3 回合的精華。
*   **缺點 (關鍵差異)**:
    *   **角色認知較弱 (Role Confusion)**: 當你用第一人稱寫「我剛剛跟你說 OOO」，模型需要多一層理解去解析「這個『我』是指玩家，『你』是指模型」。有時候如果總結寫得不好，模型會搞混剛剛到底是誰罵誰。
    *   **語氣斷層 (Tone Break)**: 因為模型沒看到自己剛剛「原汁原味」的發言，只看到了「你剛剛拒絕了我」，它接下來的回覆可能會變得比較生硬或格式化，失去剛剛扮演暴躁老闆的鮮活感。

#### 結論：哪種適合大富翁？
*   **短期、需要強烈角色扮演的交涉 (如：商店殺價 3 回合)**: 絕對使用 **結構化陣列**。因為你要的是老闆原汁原味的暴躁與情緒連貫，且 3 回合的 Token 消耗完全在可接受範圍內。
*   **長期、跨回合的記憶 (如：10 回合前誰炸了誰)**: 絕對使用 **文字總結 (注入 System Prompt)**。因為把 10 回合前的完整對話陣列保留下來太耗 Token，且 AI 不需要接續 10 回合前的語氣，它只需要「知道」那件事發生過。

## 9. 最高難度 AI：全域道具與多步決策 (Agentic Workflow for Global Items)
當我們排除「API 延遲與耗時」的限制（例如玩家自願開啟「究極思考模式」），AI 能夠執行多麼複雜的操作？以全地圖範圍道具「飛彈」為例。

### LLM 的弱點：空間運算與窮舉
即使給予無限的時間與 Token，LLM (大語言模型) 天生就**不擅長做複雜的空間數學計算** (Spatial Math)。
如果直接把 100 格的資料丟給 AI 並問：「你要往哪裡丟飛彈效益最大？（爆炸範圍 9x9，人員送醫、建築降級）」，AI 很容易迷失在數據海中，選出一個其實炸到自己、或者只炸到空地的愚蠢目標。

### 解決方案：AI 代理人工作流 (Agentic Workflow / Task Breakdown)
既然時間不是問題，我們不該奢望 AI 用「一次 API 呼叫」解決所有問題。我們應該把決策**拆解 (Breakdown)**，並讓 Godot 引擎 (C++) 負責算數學，讓 AI 負責「政治與策略」。

**實作範例：發射飛彈的三步工作流**

1.  **Step 1: 策略定調 (API Call 1 - Intent)**
    *   **Godot 傳送**: 當前各玩家的財力與威脅度總結。
    *   **Prompt**: "你手上有飛彈。請評估當前局勢，決定這回合是否要發射？如果要，你的『首要打擊目標』是誰？"
    *   **AI 回覆**: `{"use_missile": true, "primary_target": "Player_3", "reason": "他快要獨佔整條科技街了。"}`

2.  **Step 2: 引擎代算 (Godot Calculation - No API)**
    *   既然 AI 決定搞 Player 3，Godot 引擎立刻在背景進行陣列遍歷 (這對 Godot 來說只需 1 毫秒)。
    *   Godot 掃描地圖，找出能炸到 Player 3 建築的所有合法座標，並計算每個座標的**附帶損害 (Collateral Damage)**。
    *   Godot 整理出前 3 個最佳打擊點：
        *   選項 A (座標 15): 炸毀 P3 兩棟 5 級房，但會波及到你自己 (送醫)。
        *   選項 B (座標 42): 炸毀 P3 一棟 4 級房，波及 P2。
        *   選項 C (座標 60): 炸毀 P3 玩家本體 (剛好路過)，無建築損害。

3.  **Step 3: 戰術決斷 (API Call 2 - Execution)**
    *   **Godot 傳送**: 把這 3 個過濾後的選項，以及附帶損害的文字描述傳給 AI。
    *   **Prompt**: "你決定用飛彈攻擊 Player 3。作戰電腦為你規劃了三個打擊方案，請選擇最終發射座標。"
    *   **AI 回覆**: `{"target_coordinate": 42, "reason": "炸掉他的房子，順便波及 P2 削弱其他人，且確保我自己安全。"}`

### 結論 (Conclusion)
*   **不要讓 LLM 算數學**：無論難度多高、時間多充裕，都不要讓 AI 去窮舉 100 個格子的 9x9 範圍。
*   **Godot 算物理，AI 算心理**：讓遊戲引擎負責生成「選項清單 (Options/Heatmap)」，讓 AI 負責做「價值觀判斷」。這才是未來高階遊戲 AI 的終極架構！

## 10. AI 行動決策樹：如何決定「第一步」？(Action Selection & The Turn Lifecycle)
承接上一點，我們知道 AI 在使用「飛彈」時需要拆解步驟，Godot 負責算物理，AI 負責算心理。
但問題來了：**AI 怎麼知道它這回合「可以」或「應該」使用飛彈？** 它面前有擲骰子、使用遙控骰子、使用均貧卡等多種選擇。

### 錯誤作法：一次問完所有事情 (The All-in-One Prompt)
如果我們把「所有能做的事」和「所有道具的細節」全部塞在同一個 Prompt 裡問 AI：「這是你所有的卡片、這是全地圖狀態、這是你可以做的事，請一次告訴我你這回合要幹嘛（包含選哪個道具、打誰、然後丟幾步）」，這會導致 AI 嚴重的**認知過載 (Cognitive Overload)**。它可能會試圖同時規劃「用飛彈炸 A，然後用遙控骰子走到 B 買地」，結果輸出混亂的指令，甚至忽略了「丟骰子是回合結束動作」的規則。

### 正確作法：提供「高階意圖選單」與「回合生命週期」(High-Level Intent Menu & Lifecycle)
我們應該把一整個回合拆解為**階段 (Phases)**，並在每個階段只給 AI 當下合法的**「高階意圖選單 (High-Level Intent Menu)」**。

**AI 回合決策的標準生命週期：**

#### Phase 1: 道具使用意圖 (Item Phase - Optional)
在 AI 回合剛開始時，Godot 引擎會先檢查 AI 手上有什麼道具。如果沒有，直接跳到 Phase 2。
如果有，Godot 構建一個**「可行意圖清單 (Intent Menu)」**傳給 AI。

*   **Godot 傳送**:
    *   盤面摘要（誰最有錢、誰最具威脅）。
    *   `available_actions`:
        1.  `"action": "use_item", "item_id": "missile", "description": "飛彈：大範圍破壞對手資產，可能波及自己。"`
        2.  `"action": "use_item", "item_id": "remote_dice", "description": "遙控骰子：指定接下來走 1~6 步，可用來踩好地或躲避收費站。"`
        3.  `"action": "skip_items", "description": "跳過使用道具，直接進入擲骰子階段。"`
*   **Prompt 重點提示**: 「你一次只能選擇一個行動。請注意：一旦選擇『跳過使用道具』，你本回合將無法再使用任何卡片，必須直接擲骰子。」
*   **AI 決策**: AI 根據盤面與自身性格，選擇了 `{"action": "use_item", "item_id": "missile"}`。

#### Phase 2: 道具目標細化 (Targeting Phase - Sub-workflow)
*如果 AI 在 Phase 1 選擇了使用道具*，Godot 就會進入我們在「第 9 點」討論的 Agentic Workflow：
1. Godot 計算飛彈的最佳 3 個打擊座標（代算）。
2. Godot 再次呼叫 API，讓 AI 從這 3 個選項中挑一個（戰術決斷）。
3. 執行飛彈效果。

*(如果 AI 還有其他道具可以連續使用，Godot 可以再次回到 Phase 1，更新選單並詢問，直到 AI 選擇 `skip_items`)*

#### Phase 3: 移動決策 (Movement Phase - Mandatory)
當 AI 選擇 `skip_items` 或道具用完後，進入必須執行的移動階段。
此時，Godot 根據 AI 當前的狀態（是否有使用遙控骰子）給出不同的選項。

*   **情境 A (正常擲骰)**: 如果沒用遙控骰子，AI 只能選擇 `roll_dice`，Godot 產生 1~6 亂數並移動 AI。這裡根本不需要呼叫 API，因為這是不涉及決策的強制動作。
*   **情境 B (遙控骰子)**: 如果 AI 剛剛使用了遙控骰子，Godot 會幫它算出往前走 1~6 步分別會停在哪裡。
    *   **Godot 傳送**: `upcoming_cells` (眼前 6 步的詳細資訊，包含空地、別人的收費站、機會命運等)。
    *   **Prompt**: 「你使用了遙控骰子，請決定你要走 1~6 步中的哪一步？」
    *   **AI 決策**: `{"action": "move_steps", "steps": 4, "reason": "第 4 步是無主的高級空地，我要買下來。"}`

### 為什麼要這樣設計？ (The Power of High-Level Intents)
這正是我們反覆強調的核心哲學：
*   **【重點高亮】AI 負責它最擅長的事：政治考量、仇恨值判斷、性格演繹。**
*   **【重點高亮】Godot 負責它最擅長的事：陣列遍歷、數值加總、範圍傷害計算。**

當你給 AI 一個「高階意圖選單（包含：你要用飛彈？還是用均貧卡？還是直接擲骰子？）」時：
1.  **收斂決策空間 (Converged Action Space)**：AI 不會迷失在「我可以用飛彈炸 (15, 20) 這個座標，然後再用遙控骰子走 3 步到 (15, 23)」這種荒謬且引擎無法解析的複雜計畫中。
2.  **防呆 (Error Prevention)**：你明確告訴它選項 3 是「跳過道具，準備擲骰子」，這就解決了你提到的「它不知道擲骰子是最後一步」的問題。你用清單的結構，強迫 AI 遵守遊戲的階段規則。
3.  **靈活擴充 (Scalability)**：未來你新增任何奇奇怪怪的道具，只要加進這個 `available_actions` 清單，並寫一行簡單的 `description`，AI 就懂了！完全不需要改動底層的 AI 判斷邏輯。

## 11. Godot 端實作：Context Builder 與多樣化戰術選項 (Implementation & Tactical Diversity)

### 痛點：產生給 AI 的 JSON 其實是一項苦工 (The Context Builder)
如前所述，產生 `available_actions` 給 AI 判斷，在理想中很美好，但在 Godot 實作中，這會是一個需要撈取大量資料的龐大 Function。

**實作建議：UI 驅動思維 (Think like rendering a UI)**
不要把這件事想成「寫 Prompt」，把它想成「繪製 UI 選單」。
在你的遊戲裡，當玩家輪到回合時，畫面上的「背包按鈕」會根據玩家擁有的道具亮起。產生 JSON 的邏輯完全一樣！
你可以寫一個專門的 Class (例如 `AIPromptBuilder`)：
1.  **Extract (撈資料)**: `var items = current_player.inventory.get_items()`
2.  **Filter (過濾)**: 檢查道具是否可用（例如有些道具只能在特定地磚使用）。
3.  **Format (組裝 JSON)**: 跑一個 `for` 迴圈，把道具的 ID 和說明塞進 `available_actions` Array 中。
4.  **Append (加上預設選項)**: 永遠在最後 push 一個 `{"action": "skip", "description": "跳過"}`。

這本質上就是資料結構轉換 (Data Mapping)，雖然程式碼長，但邏輯非常單純，且完全由 Godot 掌控，不會有不可預期的錯誤。

### 痛點：如何讓同一個道具，在不同性格的 AI 手中產生不同用法？(The Missile Dilemma)
假設有兩個 AI：
*   **AI A (攻擊型)**: 想用飛彈炸毀敵人的昂貴建築。
*   **AI B (防守型)**: 發現前方 6 步內有 4 格是敵人的高收費站，想用飛彈「清空前方的路」。

如果在前面提到的 **Step 2 (引擎代算)** 中，Godot 只是單純算出「對敵人造成最大金錢損害」的前 3 個座標，那 AI B (防守型) 就永遠無法選擇防守策略！

**解決方案：Godot 提供「戰術分類的選項清單」 (Categorized Tactical Options)**
Godot 在底層幫飛彈算選項時，**不應該只用單一維度 (例如最大傷害) 去評估**。Godot 應該計算並提供幾種**不同戰術意圖**的選項給 AI 選：

*   **Godot 算完後傳給 AI 的選項 (Targeting Phase)**:
    *   `[選項 A - 斬首戰術]`: 座標 (45)。能對目前總資產第一名的玩家造成最大財產破壞 (-8000元)。
    *   `[選項 B - 焦土戰術]`: 座標 (12)。能一次炸毀最多棟建築 (4棟)，但會波及玩家自己。
    *   `[選項 C - 開路戰術]`: 座標 (本體前方 3 格)。能清除你前方 6 步內的危險收費站，確保你接下來擲骰子的安全。

**AI 的決策過程 (The Magic of LLM)**:
*   當 **AI A (攻擊型)** 看到這張清單，它的 Persona 會驅使它回傳：`{"choice": "A", "reason": "我要把第一名拉下來！"}`
*   當 **AI B (防守型)** 看到同一張清單，它的 Persona 加上它知道自己快破產了，就會回傳：`{"choice": "C", "reason": "前面太危險了，我必須確保我能活過這回合。"}`

### 結論 (Conclusion)
要把這個系統做成遊戲內實際運作的 Function：
1.  **Godot 的 Context Builder 就像在畫隱形 UI**：把玩家能按的按鈕，轉成文字選項清單。
2.  **Godot 的引擎代算必須提供「多樣性」**：不要幫 AI 決定什麼是「最好」的。Godot 負責算出「最痛的」、「最安全的」、「波及最廣的」幾個極端值，把選擇權交還給 AI 的 Persona。這樣不同性格的 AI 玩起來才會有靈魂！
