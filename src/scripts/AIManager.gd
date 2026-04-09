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
# AI 通訊核心 (Phase 5 測試用)
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
