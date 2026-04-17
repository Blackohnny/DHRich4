extends Node

# ---------------------------------------------------------
# NewsManager: 每日時事系統 (Daily News Events)
# 負責快取、抓取並向 EventProcessor 注入今日的 AI 隨機時事卡片
# ---------------------------------------------------------

# 根據使用者需求，放在遊戲執行檔所在的資料夾下 (專案目錄)
# 開發環境下等同於 res:// 的根目錄，匯出後則在 .exe 旁邊
var CACHE_FILE_PATH: String = ""

var is_news_injected: bool = false

func _ready() -> void:
	# 決定快取檔案的路徑
	if OS.has_feature("editor"):
		# 開發環境下，直接放在 res:// 下
		CACHE_FILE_PATH = "res://daily_news_events.json"
	else:
		# 匯出後 (Release)，放在執行檔 (.exe) 旁邊
		var base_dir = OS.get_executable_path().get_base_dir()
		CACHE_FILE_PATH = base_dir.path_join("daily_news_events.json")
		
	# 在遊戲啟動時嘗試載入今日時事
	# 使用 call_deferred 確保主場景 (Main.tscn) 已經完全載入
	call_deferred("_load_or_generate_daily_news")

func _load_or_generate_daily_news() -> void:
	var today_date: String = Time.get_date_string_from_system()
	
	# 1. 檢查快取檔案是否存在
	if FileAccess.file_exists(CACHE_FILE_PATH):
		var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.READ)
		if file != null:
			var json_string = file.get_as_text()
			file.close()
			
			var cache_data = JSON.parse_string(json_string)
			if typeof(cache_data) == TYPE_DICTIONARY:
				# 2. 比對日期 (Cache Hit)
				if cache_data.get("date", "") == today_date:
					DebugLogger.log_msg("📰 讀取到今日 [%s] 的時事卡片快取！" % today_date, true)
					_inject_to_processor(cache_data)
					return
				else:
					DebugLogger.log_msg("📰 發現過期的時事卡片 (舊: %s, 今: %s)，準備重新生成..." % [cache_data.get("date", ""), today_date])
	
	# 3. 檔案不存在或過期 (Cache Miss)，需要重新跟 AI 要一份
	DebugLogger.log_msg("📰 沒有今日的時事快取，準備向 AI 請求生成新的事件卡片...")
	_generate_new_daily_news(today_date)

## 向 AI 請求新的時事卡片
func _generate_new_daily_news(today_date: String) -> void:
	var ai_manager = get_node_or_null("/root/AIManager")
	if ai_manager == null or not ai_manager.is_ai_ready():
		DebugLogger.log_msg("[WARNING] AI 尚未連線，無法生成今日時事卡片。")
		return
		
	# === 顯示載入中的鎖定 UI (Loading Popup) ===
	var loading_dialog = null
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("UI"):
		var confirm_scene = preload("res://scenes/ui/components/ConfirmDialog.tscn")
		loading_dialog = confirm_scene.instantiate()
		main_scene.get_node("UI").add_child(loading_dialog)
		# 參數: title, message, is_dual_choice, confirm, cancel, hide_all_buttons
		loading_dialog.setup("連線中", "\n正在向神明祈求今日時事...\n(產生 %s 時事可能需要 5~15 秒)" % today_date, false, "", "", true)
	
	# 綁定錯誤處理
	var on_error = func(msg: String):
		DebugLogger.log_msg("[ERROR] 時事卡片生成失敗: " + msg)
		if loading_dialog:
			loading_dialog.queue_free()
	
	ai_manager.news_generation_failed.connect(on_error)
	
	# 發送生成請求
	ai_manager.request_daily_news_generation(today_date)
	
	# 等待 AI 回覆 (這可能會花 10~15 秒，因為產生的 token 比較多)
	var news_data = await ai_manager.news_generation_completed
	
	ai_manager.news_generation_failed.disconnect(on_error)
	
	if loading_dialog:
		loading_dialog.queue_free() # 收起載入中視窗
		
	if typeof(news_data) == TYPE_DICTIONARY:
		# 4. 將新產生的新聞寫入快取檔案 (Save Cache)
		_save_news_cache(news_data)
		
		# 5. 注入到牌堆
		_inject_to_processor(news_data)
		
		# 顯示成功彈窗
		if main_scene and main_scene.has_node("UI"):
			var success_dialog = preload("res://scenes/ui/components/ConfirmDialog.tscn").instantiate()
			main_scene.get_node("UI").add_child(success_dialog)
			success_dialog.setup("時事更新完成", "\n成功從神殿取得了今日的 %s 張時事卡片！\n" % str(news_data.get("chance", []).size() + news_data.get("destiny", []).size()), false, "太棒了")

## 將新聞資料寫入 user:// 作為快取
func _save_news_cache(data: Dictionary) -> void:
	var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		DebugLogger.log_msg("💾 已將今日時事卡片快取至: " + ProjectSettings.globalize_path(CACHE_FILE_PATH))
	else:
		DebugLogger.log_msg("[ERROR] 無法寫入時事快取檔案！")

## 將 JSON 字典丟給 EventProcessor
func _inject_to_processor(data: Dictionary) -> void:
	var processor = get_node_or_null("/root/EventProcessor")
	if processor != null:
		processor.inject_news_events(data)
		is_news_injected = true
	else:
		DebugLogger.log_msg("[ERROR] NewsManager 找不到 EventProcessor！")