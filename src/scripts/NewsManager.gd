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
	DebugLogger.log_msg("📰 沒有今日的時事快取，開啟晨報 UI...")
	_open_news_onboarding_ui(today_date)

func _open_news_onboarding_ui(today_date: String) -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_node("UI"):
		DebugLogger.log_msg("[ERROR] 無法開啟晨報 UI，找不到 Main Scene 的 UI 節點。")
		return
		
	var onboarding_scene = preload("res://scenes/ui/NewsOnboardingUI.tscn")
	var ui_node = onboarding_scene.instantiate()
	main_scene.get_node("UI").add_child(ui_node)
	
	# Connect signals
	ui_node.search_requested.connect(_on_ui_search_requested.bind(ui_node))
	ui_node.generation_requested.connect(_on_ui_generation_requested.bind(ui_node, today_date))

func _on_ui_search_requested(topics: Array[String], ui_node: Node) -> void:
	DebugLogger.log_msg("📰 開始搜尋新聞主題: " + str(topics))
	# Disable search button while searching
	if ui_node.has_node("ColorRect/InputScreen/SearchButton"):
		ui_node.get_node("ColorRect/InputScreen/SearchButton").disabled = true
	
	_perform_rss_search(topics, ui_node)

func _perform_rss_search(topics: Array[String], ui_node: Node) -> void:
	var results: Array[Dictionary] = []
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	for topic in topics:
		if topic.is_empty():
			continue
			
		var url = "https://news.google.com/rss/search?q=" + topic.uri_encode() + "&hl=zh-TW&gl=TW&ceid=TW:zh-Hant"
		DebugLogger.log_msg("📡 正在抓取: " + url)
		
		var err = http_request.request(url)
		if err != OK:
			DebugLogger.log_msg("[ERROR] 無法發送 RSS 請求: " + str(err))
			continue
			
		# Wait for the request to complete
		var response = await http_request.request_completed
		var result = response[0]
		var response_code = response[1]
		var body = response[3]
		
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var xml_string = body.get_string_from_utf8()
			var parsed_item = _parse_first_rss_item(xml_string, topic)
			if not parsed_item.is_empty():
				results.append(parsed_item)
			else:
				DebugLogger.log_msg("[WARNING] 找不到關於 '%s' 的新聞。" % topic)
				results.append({
					"title": "找不到關於「" + topic + "」的新聞",
					"snippet": "請嘗試更換關鍵字。",
					"url": ""
				})
		else:
			DebugLogger.log_msg("[ERROR] RSS 請求失敗或回傳碼錯誤: " + str(response_code))
			
	http_request.queue_free()
	
	# Enable search button
	if ui_node and is_instance_valid(ui_node) and ui_node.has_node("ColorRect/InputScreen/SearchButton"):
		ui_node.get_node("ColorRect/InputScreen/SearchButton").disabled = false
		
	if ui_node and is_instance_valid(ui_node):
		ui_node.show_news_results(results)

func _parse_first_rss_item(xml_string: String, fallback_topic: String) -> Dictionary:
	# Find the first <item> block
	var item_start = xml_string.find("<item>")
	if item_start == -1:
		return {}
		
	var item_end = xml_string.find("</item>", item_start)
	if item_end == -1:
		return {}
		
	var item_content = xml_string.substr(item_start, item_end - item_start)
	
	# Extract <title>
	var title = _extract_tag_content(item_content, "<title>", "</title>")
	
	# Extract <link>
	var link = _extract_tag_content(item_content, "<link>", "</link>")
	
	# Extract <description> (often contains HTML in Google News RSS)
	var description_raw = _extract_tag_content(item_content, "<description>", "</description>")
	var snippet = _strip_html_tags(description_raw)
	
	# Clean up title basic XML entities
	title = _strip_html_tags(title)
	
	# Google News RSS description is usually just a re-hash of the title + source name.
	# We can try to extract just the source name from the description (it's usually at the end after some spaces).
	var source_name = ""
	var source_start = item_content.find("<source url=")
	if source_start != -1:
		var bracket_close = item_content.find(">", source_start)
		var source_end = item_content.find("</source>", bracket_close)
		if bracket_close != -1 and source_end != -1:
			source_name = "來源：" + item_content.substr(bracket_close + 1, source_end - bracket_close - 1).strip_edges()
	
	snippet = source_name
	
	if title.is_empty():
		title = "關於 " + fallback_topic + " 的新聞"
		
	return {
		"title": title,
		"snippet": snippet,
		"url": link
	}

func _extract_tag_content(source: String, start_tag: String, end_tag: String) -> String:
	var start_idx = source.find(start_tag)
	if start_idx == -1:
		return ""
	start_idx += start_tag.length()
	
	var end_idx = source.find(end_tag, start_idx)
	if end_idx == -1:
		return ""
		
	var content = source.substr(start_idx, end_idx - start_idx).strip_edges()
	
	# Handle CDATA
	if content.begins_with("<![CDATA[") and content.ends_with("]]>"):
		content = content.substr(9, content.length() - 12)
		
	return content

func _strip_html_tags(html_string: String) -> String:
	# Google News sometimes encodes the entire HTML snippet inside the description tag.
	# We must decode the basic entities first, otherwise the <a href...> tags will look like
	# &lt;a href=...&gt; and the RegEx won't catch them as tags.
	var decoded = html_string.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&")
	
	var regex = RegEx.new()
	# Compile regex to match any HTML tag, including those with newlines inside them
	regex.compile("<[^>]+>")
	var stripped = regex.sub(decoded, " ", true) # Replace tags with space
	
	# Strip other common HTML entities that might be left over
	stripped = stripped.replace("&nbsp;", " ")
	stripped = stripped.replace("&middot;", "·")
	stripped = stripped.replace("&hellip;", "...")
	
	# Clean up multiple spaces and newlines
	var space_regex = RegEx.new()
	space_regex.compile("\\s+")
	stripped = space_regex.sub(stripped, " ", true)
	
	return stripped.strip_edges()

func _on_ui_generation_requested(news_items: Array[Dictionary], ui_node: Node, today_date: String) -> void:
	var ai_manager = get_node_or_null("/root/AIManager")
	if ai_manager == null or not ai_manager.is_ai_ready():
		DebugLogger.log_msg("[WARNING] AI 尚未連線，無法生成今日時事卡片。")
		ui_node.queue_free()
		return

	# 顯示載入中的鎖定 UI (Loading Popup)
	var loading_dialog = null
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("UI"):
		var confirm_scene = preload("res://scenes/ui/components/ConfirmDialog.tscn")
		loading_dialog = confirm_scene.instantiate()
		main_scene.get_node("UI").add_child(loading_dialog)
		loading_dialog.setup("連線中", "\n正在將真實新聞轉化為大富翁命運卡...\n(可能需要 5~15 秒)", false, "", "", true)

	# 綁定錯誤處理
	var on_error = func(msg: String):
		DebugLogger.log_msg("[ERROR] 時事卡片生成失敗: " + msg)
		if loading_dialog:
			loading_dialog.queue_free()
		ui_node.queue_free()

	ai_manager.news_generation_failed.connect(on_error)

	# 發送生成請求，並將剛剛搜到的新聞傳過去作為 Context
	ai_manager.request_daily_news_generation(today_date, news_items)

	# 等待 AI 回覆
	var news_data = await ai_manager.news_generation_completed

	ai_manager.news_generation_failed.disconnect(on_error)

	if loading_dialog:
		loading_dialog.queue_free() # 收起載入中視窗
		
	ui_node.queue_free() # 關閉晨報 UI

	if typeof(news_data) == TYPE_DICTIONARY:
		# 將新產生的新聞寫入快取檔案 (Save Cache)
		_save_news_cache(news_data)

		# 注入到牌堆
		_inject_to_processor(news_data)

		# 顯示成功彈窗
		if main_scene and main_scene.has_node("UI"):
			var success_dialog = preload("res://scenes/ui/components/ConfirmDialog.tscn").instantiate()
			main_scene.get_node("UI").add_child(success_dialog)
			success_dialog.setup("時事更新完成", "\n成功從真實新聞轉譯了 %s 張時事卡片！\n" % str(news_data.get("chance", []).size() + news_data.get("destiny", []).size()), false, "太棒了")

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
