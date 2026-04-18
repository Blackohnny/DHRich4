extends Node

# ---------------------------------------------------------
# AIManager: 全域 AI 通訊與狀態管理器 (AutoLoad)
# 負責讀取設定檔，並管理 AI 連線狀態。如果失敗，提供降級機制。
# ---------------------------------------------------------

var is_ready: bool = false
var api_endpoint: String = ""
var api_key: String = ""
var model_name: String = "gpt-4o"
var temperature: float = 0.8
var max_tokens: int = 1000

const CONFIG_FILE_NAME: String = "ai_config.json"
const USER_CONFIG_PATH: String = "user://" + CONFIG_FILE_NAME
const RES_CONFIG_PATH: String = "res://" + CONFIG_FILE_NAME
const TEMPLATE_PATH: String = "res://ai_config.example.json"

func _ready() -> void:
	load_config()

# 讀取 AI 設定檔 (開放給 DebugLogger 按鈕手動重讀)
func load_config() -> void:
	var target_path: String = ""

	# 優先尋找玩家自訂設定 (user://)，找不到再找專案開發設定 (res://)
	if FileAccess.file_exists(USER_CONFIG_PATH):
		target_path = USER_CONFIG_PATH
		DebugLogger.log_msg("📁 從玩家目錄載入設定: " + ProjectSettings.globalize_path(USER_CONFIG_PATH))
	elif FileAccess.file_exists(RES_CONFIG_PATH):
		target_path = RES_CONFIG_PATH
		DebugLogger.log_msg("📁 從專案目錄載入設定: " + ProjectSettings.globalize_path(RES_CONFIG_PATH))
	else:
		DebugLogger.log_msg("[ERROR] AI 設定檔不存在！預期路徑: " + ProjectSettings.globalize_path(RES_CONFIG_PATH))
		DebugLogger.log_msg("--> 已自動降級為【傳統無 AI 模式】。")
		DebugLogger.log_msg("--> 一般玩家: 請將設定檔放在 " + ProjectSettings.globalize_path("user://"))
		DebugLogger.log_msg("--> 開發者: 請將 '%s' 複製為 '%s' 並填寫真實金鑰。" % [TEMPLATE_PATH, RES_CONFIG_PATH])
		# TODO: (Phase 5) 未來實作遊戲內 UI 讓玩家輸入 API Key 並存入 user://
		is_ready = false
		return

	var file = FileAccess.open(target_path, FileAccess.READ)

	if file == null:
		var err = FileAccess.get_open_error()
		DebugLogger.log_msg("[ERROR] AI 設定檔載入失敗！錯誤碼: %d" % err)
		_fallback_to_traditional()
		return
	# 使用 Godot 原生 JSON 解析器
	var json_string = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_string)
	
	if typeof(data) != TYPE_DICTIONARY:
		DebugLogger.log_msg("[ERROR] AI 設定檔格式錯誤！必須是有效的 JSON 物件 (Dictionary)。")
		_fallback_to_traditional()
		return
		
	# 讀取設定 (如果鍵值不存在，給予預設值或空字串)
	api_endpoint = data.get("api_endpoint", "")
	api_key = data.get("api_key", "")
	model_name = data.get("model", "")
	temperature = data.get("temperature", -1.0)
	max_tokens = data.get("max_tokens", -1)
	if api_endpoint == "" or api_endpoint == "https://your-api-endpoint.com/chat/completions":
		DebugLogger.log_msg("[ERROR] AI 設定檔參數不合理：api_endpoint 未正確設定！")
		_fallback_to_traditional()
		return
		
	if api_key == "" or api_key == "your_api_key_here":
		DebugLogger.log_msg("[ERROR] AI 設定檔參數不合理：api_key 未正確設定！")
		_fallback_to_traditional()
		return
		
	if model_name == "":
		DebugLogger.log_msg("[ERROR] AI 設定檔參數不合理：model 未設定！")
		_fallback_to_traditional()
		return
		
	if temperature < 0.0 or max_tokens <= 0:
		DebugLogger.log_msg("[ERROR] AI 設定檔參數不合理：temperature 或 max_tokens 數值異常！")
		_fallback_to_traditional()
		return
		
	# 設定成功，印出讀取到的參數 (除了 api_key 以外，保護金鑰安全)
	is_ready = true
	DebugLogger.log_msg("====== AI 通訊參數 ======")
	DebugLogger.log_msg("Provider: openai_compatible")
	DebugLogger.log_msg("Endpoint: " + api_endpoint)
	DebugLogger.log_msg("Model: " + model_name)
	DebugLogger.log_msg("Temperature: " + str(temperature))
	DebugLogger.log_msg("Max Tokens: " + str(max_tokens))
	DebugLogger.log_msg("=========================")
	DebugLogger.log_msg("[SUCCESS] AI 模組初始化成功！(檔案格式正確、檔案格式正確)", true)

func _fallback_to_traditional() -> void:
	DebugLogger.log_msg("--> 已自動降級為【傳統無 AI 模式】。請參考範本檔 '%s' 修正參數。" % TEMPLATE_PATH)
	is_ready = false

# 外部呼叫：檢查 AI 是否準備好 (用於決定是否切換到傳統模式)
func is_ai_ready() -> bool:
	return is_ready

# ---------------------------------------------------------
# AI 每日時事生成核心 (Phase 5 Extension)
# ---------------------------------------------------------

signal news_generation_completed(news_data: Dictionary)
signal news_generation_failed(error_msg: String)

## 向 AI 請求生成符合今日日期的時事卡片
func request_daily_news_generation(today_date: String, news_context: Array[Dictionary] = []) -> void:
	if not is_ready:
		news_generation_failed.emit("AI 未連線，無法生成時事。")
		return

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_news_request_completed.bind(http_request, today_date))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	# 未來可以從 SettingsManager 讀取，目前先寫死
	var chance_count = 3
	var destiny_count = 3

	# 1. 建立生成時事卡的 System Prompt
	var system_prompt = "你現在是一位專業的大富翁遊戲企劃與新聞編輯。\n"
	system_prompt += "今天的日期是：%s。\n" % today_date
	
	if news_context.size() > 0:
		system_prompt += "請根據以下真實新聞摘要，設計 %d 張機會卡 (chance) 與 %d 張命運卡 (destiny)：\n\n" % [chance_count, destiny_count]
		for i in range(news_context.size()):
			var item = news_context[i]
			system_prompt += "[新聞 %d]\n標題：%s\n摘要：%s\n\n" % [i + 1, item.get("title", ""), item.get("snippet", "")]
		system_prompt += "請確保卡片的事件內容與上述新聞密切相關。\n"
	else:
		system_prompt += "請以最近幾天全球發生的真實重大「科技」、「財經」或「社會」新聞為主題（如果你無法連網，請根據你知識庫中近幾年的重大歷史事件來虛構合理的新聞）。\n"
		system_prompt += "請幫我設計 %d 張機會卡 (chance) 與 %d 張命運卡 (destiny)。\n" % [chance_count, destiny_count]

	system_prompt += "機會卡高機率是好事（例如：獲得金錢、獲得道具、給所有人發紅包）。命運卡高機率是壞事（例如：扣錢、沒收道具、所有人扣錢）。\n"
	system_prompt += "【重要指令：全域事件】請確保在生成的卡片中，至少有 1 到 2 張卡片是影響「所有人(all)」或「其他人(others)」的範圍事件（例如：全球通膨導致所有人扣款，或全民普發獎金）。\n"
	system_prompt += "【重要】每張卡片的 'id' 請用 'news_c_隨機數字' 或 'news_d_隨機數字' 命名。\n"
	system_prompt += "【重要】每張卡片的 'weight' 請固定設定為 15。\n"
	system_prompt += "請「嚴格」回傳以下格式的 JSON，不要包含任何額外廢話或 Markdown 標籤：\n"
	system_prompt += "{\n"
	system_prompt += "  \"date\": \"%s\",\n" % today_date
	system_prompt += "  \"chance\": [\n"
	system_prompt += "    { \"id\": \"news_c_01\", \"title\": \"標題\", \"description\": \"新聞描述...\", \"weight\": 15, \"effects\": [{\"cmd\": \"add_cash\", \"target\": \"self\", \"amount\": 1000}] }\n"
	system_prompt += "  ],\n"
	system_prompt += "  \"destiny\": [ ... ]\n"
	system_prompt += "}\n\n"

	# 動態掛載 EventProcessor 的 Schema，約束 AI 只能產生合法的遊戲機制
	var processor = get_node_or_null("/root/EventProcessor")
	if processor:
		system_prompt += processor.get_schema_prompt()

	var messages = [{"role": "system", "content": system_prompt}]

	var payload = {
		"model": model_name,
		"temperature": 0.4, # 給予一點點創意空間，但保持 JSON 結構穩定
		"max_tokens": 2000, # 卡片變多，提高 token 數量
		"messages": messages,
		"stream": false,
		"response_format": { "type": "json_object" } # 強制 JSON 輸出
	}

	var json_payload = JSON.stringify(payload)

	# === [新增詳細 Log] 記錄打出去的完整 Payload ===
	DebugLogger.log_msg("🚀 [News AI Request] 準備向模型請求生成今日時事卡片: " + today_date)
	DebugLogger.log_msg("發送的完整 Payload (Prompt) 內容:\n" + JSON.stringify(payload, "  "))
	# ==========================================

	var err = http_request.request(api_endpoint, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		DebugLogger.log_msg("[ERROR] News HTTPRequest 發送失敗！錯誤碼: %d" % err)
		news_generation_failed.emit("網路發送失敗。")
		http_request.queue_free()

func _on_news_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest, expected_date: String) -> void:
	http_node.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		news_generation_failed.emit("網路連線失敗。")
		return

	var response_text = body.get_string_from_utf8()

	if response_code == 200:
		var json = JSON.parse_string(response_text)

		# === [新增詳細 Log] 記錄 AI 回傳的完整 HTTP Response ===
		DebugLogger.log_msg("📥 [News AI Raw Response Code] " + str(response_code))
		
		if typeof(json) == TYPE_DICTIONARY and json.has("choices") and json.choices.size() > 0:
			var ai_reply_str = json.choices[0].message.content
			DebugLogger.log_msg("📥 [News AI Extracted Message Content]:\n" + ai_reply_str)
			
			var news_json = JSON.parse_string(ai_reply_str)
			if news_json != null and typeof(news_json) == TYPE_DICTIONARY:
				# 強制覆寫日期，確保快取一致性
				news_json["date"] = expected_date
				news_generation_completed.emit(news_json)
			else:
				DebugLogger.log_msg("[ERROR] AI 產生的時事卡片不是合法的 JSON。")
				news_generation_failed.emit("JSON 解析失敗。")
		else:
			news_generation_failed.emit("AI 回傳格式異常。")
	else:
		DebugLogger.log_msg("[ERROR] News 伺服器錯誤 %d: " % response_code + response_text)
		news_generation_failed.emit("伺服器錯誤：" + str(response_code))

# ---------------------------------------------------------
# AI 通訊核心 (Phase 5 測試用)
# ---------------------------------------------------------

signal destiny_response_received(response_data: Dictionary)
signal destiny_error_occurred(error_msg: String)

# 動態角色池 (Dynamic Personas)
const PERSONAS: Array[Dictionary] = [
	{
		"name": "盜寶哥布林",
		"personality": "極度貪婪、市儈、講話急躁、看到錢就眼睛發亮，喜歡嘲笑窮人。"
	},
	{
		"name": "森林小妖精",
		"personality": "天真無邪、喜歡惡作劇、講話像小孩子，對金錢沒什麼概念，但喜歡發送驚喜。"
	},
	{
		"name": "深淵惡魔",
		"personality": "威嚴、恐怖、講話緩慢且充滿壓迫感，喜歡給予人類殘酷的試煉或巨大的誘惑。"
	},
	{
		"name": "溫和的大地女神",
		"personality": "充滿母愛、語氣溫柔慈祥，總是鼓勵玩家，即使懲罰也是帶著『這是為了你好』的語氣。"
	},
	{
		"name": "暴躁的火神",
		"personality": "脾氣極差、很容易不耐煩、覺得人類很煩，動不動就想用火燒掉一切。"
	},
	{
		"name": "神秘的流浪商人",
		"personality": "語氣神祕、總是說話留一半、像是在推銷東西，但從來不強求。"
	}
]

func get_random_persona() -> Dictionary:
	return PERSONAS[randi() % PERSONAS.size()]

## 發送命運之神對話請求
## is_final_turn: 若為 true，會加上隱藏 prompt 強制 AI 輸出 JSON (包含 effects)
func request_destiny_event(chat_history: Array, player_name: String, persona: Dictionary, is_final_turn: bool) -> void:
	if not is_ready:
		destiny_error_occurred.emit("AI 未連線，請檢查設定檔。")
		return
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	# 這裡不再綁定 test 的 callback，改綁正式的 callback
	http_request.request_completed.connect(self._on_destiny_request_completed.bind(http_request, is_final_turn))

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	# 1. 建立 System Prompt (動態角色扮演)
	var npc_name = persona.get("name", "神秘存在")
	var npc_trait = persona.get("personality", "神祕")
	
	var system_prompt = "你是一個名為『%s』的虛擬角色，負責在大富翁遊戲中與玩家互動。\n" % npc_name
	system_prompt += "【嚴格角色設定】你的個性是：%s\n" % npc_trait
	system_prompt += "【嚴格規定】你是劇情 NPC，不是遊戲系統小幫手！絕對不要向玩家列出任何遊戲操作選項（例如：查詢狀態、擲骰子、購買土地等）。\n"
	system_prompt += "目前的玩家是：[%s]。請根據你的角色設定，直接針對他來到你面前這件事給予回應。\n" % player_name
	#system_prompt += "對話請保持簡短，限制在 50 字以內。\n"
	
	if is_final_turn:
		system_prompt += "\n【強制指令：這是最後一回合】\n"
		system_prompt += "請根據玩家剛才的態度進行最終裁決，並「嚴格」回傳以下格式的 JSON，不要包含任何額外廢話或 Markdown 標籤：\n"
		system_prompt += "{\n"
		system_prompt += "  \"dialog\": \"你的最後一句話（例如：放肆！扣你錢！）\",\n"
		system_prompt += "  \"effects\": [ {\"cmd\": \"...\", \"target\": \"...\", ...} ]\n"
		system_prompt += "}\n\n"
		# 動態掛載我們剛才在 EventProcessor 寫好的 Schema
		var processor = get_node_or_null("/root/EventProcessor")
		if processor:
			system_prompt += processor.get_schema_prompt()
	
	# 2. 組裝 Messages 陣列 (包含 System 提示與先前的聊天紀錄)
	var messages = [{"role": "system", "content": system_prompt}]
	messages.append_array(chat_history)
	
	var payload = {
		"model": model_name,
		"temperature": temperature if not is_final_turn else 0.2, # 決算回合降低溫度確保 JSON 穩定
		"max_tokens": max_tokens,
		"messages": messages,
		"stream": false
	}
	
	# 如果是決算回合，並且 API 支援，強制指定 response_format
	if is_final_turn:
		payload["response_format"] = { "type": "json_object" }

	var json_payload = JSON.stringify(payload)
	
	# === [新增詳細 Log] 記錄打出去的完整 Payload ===
	DebugLogger.log_msg("🚀 [AI Request] 準備發送 API 請求給模型: " + model_name)
	if is_final_turn:
		DebugLogger.log_msg("⚠️ 此回合為【最終決算回合 (JSON Schema)】")
	DebugLogger.log_msg("發送的完整 Payload 內容:\n" + JSON.stringify(payload, "  "))
	# ==========================================
	
	var err = http_request.request(api_endpoint, headers, HTTPClient.METHOD_POST, json_payload)

	if err != OK:
		DebugLogger.log_msg("[ERROR] Destiny HTTPRequest 發送失敗！錯誤碼: %d" % err)
		destiny_error_occurred.emit("網路發送失敗。")
		http_request.queue_free()

func _on_destiny_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest, is_final_turn: bool) -> void:
	http_node.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		destiny_error_occurred.emit("網路連線失敗。")
		return

	var response_text = body.get_string_from_utf8()

	if response_code == 200:
		var json = JSON.parse_string(response_text)
		
		# === [新增詳細 Log] 記錄 AI 回傳的完整 HTTP Response ===
		DebugLogger.log_msg("📥 [Destiny AI Raw Response] 收到完整伺服器回覆 Payload:")
		DebugLogger.log_msg(response_text)
		# ==========================================
		
		if typeof(json) == TYPE_DICTIONARY and json.has("choices"):
			var ai_reply_str = json.choices[0].message.content
			
			# === [新增詳細 Log] 記錄 AI 回傳的純淨對話內容 ===
			DebugLogger.log_msg("📥 [Destiny AI Content] 模型對話內容:")
			DebugLogger.log_msg(ai_reply_str)
			# ==========================================
			
			if is_final_turn:
				# 決算回合：嘗試解析 AI 吐回來的 JSON
				var effect_json = JSON.parse_string(ai_reply_str)
				if effect_json != null and typeof(effect_json) == TYPE_DICTIONARY:
					destiny_response_received.emit(effect_json)
				else:
					# 容錯處理：如果 AI 沒有乖乖吐 JSON，手動包裝一個無效果的 JSON
					DebugLogger.log_msg("[WARNING] AI 未回傳標準 JSON: " + ai_reply_str)
					destiny_response_received.emit({
						"dialog": ai_reply_str,
						"effects": []
					})
			else:
				# 一般回合：只回傳文字
				destiny_response_received.emit({
					"dialog": ai_reply_str
				})
		else:
			destiny_error_occurred.emit("AI 回傳格式異常。")
	else:
		DebugLogger.log_msg("[ERROR] 伺服器錯誤 %d: " % response_code + response_text)
		destiny_error_occurred.emit("伺服器錯誤，代碼：" + str(response_code))

# ---------------------------------------------------------
# 測試連線 (保留原本的)
# ---------------------------------------------------------

# 測試連線，並將結果輸出到 DebugLogger
func test_connection() -> void:
	if not is_ready:
		DebugLogger.log_msg("[ERROR] 無法測試：AI 設定檔未正確載入。")
		return
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_test_request_completed.bind(http_request))
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var payload = {
		"model": model_name,
		"temperature": temperature,
		"max_tokens": max_tokens,
		"messages": [
			{
				"role": "user",
				"content": "請回覆我一句話：'API 連線測試成功！'"
			}
		],
		"stream": false
	}
	
	var json_payload = JSON.stringify(payload)
	var err = http_request.request(api_endpoint, headers, HTTPClient.METHOD_POST, json_payload)
	
	if err != OK:
		DebugLogger.log_msg("[ERROR] HTTPRequest 發送失敗！錯誤碼: %d" % err)
		http_request.queue_free()

func _on_test_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	http_node.queue_free() # 釋放節點
	
	if result != HTTPRequest.RESULT_SUCCESS:
		DebugLogger.log_msg("[ERROR] 網路請求失敗 (Result: %d)" % result)
		return
		
	var response_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.parse_string(response_text)
		if typeof(json) == TYPE_DICTIONARY and json.has("choices"):
			var ai_reply = json.choices[0].message.content
			DebugLogger.log_msg("✅ [AI 回覆] " + ai_reply, true)
		else:
			DebugLogger.log_msg("[WARNING] 收到 HTTP 200，但回傳格式不如預期: " + response_text)
	else:
		DebugLogger.log_msg("[ERROR] 伺服器回傳錯誤代碼 %d！" % response_code)
		DebugLogger.log_msg("--> 詳細訊息: " + response_text)
