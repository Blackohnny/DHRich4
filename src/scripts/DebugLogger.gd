extends Node

# ---------------------------------------------------------
# DebugLogger: 全域的除錯視窗管理器 (AutoLoad)
# 負責建立、顯示、隱藏獨立的 OS 子視窗，並將 Log 印在裡面與實體檔案
# ---------------------------------------------------------

var debug_window: Window
var text_box: RichTextLabel
var is_enabled: bool = true # 預設開啟

# 綁定遊戲主畫面的狀態提示標籤
var status_label_ref: Label

# 綁定主控制器 (Main.gd) 供作弊按鈕呼叫
var main_controller: Node

# 實體 Log 檔案變數
var log_file: FileAccess
const LOG_FILE_PATH: String = "res://logs/dhrich4_debug.log"

func _ready() -> void:
	_init_log_file()

	if is_enabled:
		_create_debug_window()

# 讓外部腳本 (如 Main.gd) 將自己的 UI Label 註冊給 Logger
func register_status_label(label: Label) -> void:
	status_label_ref = label

# 註冊主控制器，讓作弊按鈕可以呼叫
func register_main_controller(main: Node) -> void:
	main_controller = main

# 初始化實體 Log 檔案
func _init_log_file() -> void:
	# 開啟檔案準備寫入 (Write 模式會清空舊的，如果想保留歷史紀錄可以改用 READ_WRITE 或 APPEND)
	log_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if log_file == null:
		print("無法建立 Log 檔案: ", LOG_FILE_PATH)
	else:
		var time_dict = Time.get_datetime_dict_from_system()
		log_file.store_string("=== DHRich4 Debug Log Session Started at %04d-%02d-%02d %02d:%02d:%02d ===\n" % [
			time_dict.year, time_dict.month, time_dict.day, 
			time_dict.hour, time_dict.minute, time_dict.second
		])
		log_file.flush()

# 建立獨立的 OS 子視窗
func _create_debug_window() -> void:
	if debug_window != null:
		return # 已經建過了

	# 1. 建立 Window 節點 (真正的作業系統視窗)
	debug_window = Window.new()
	debug_window.title = "DHRich4 - AI Debug Console"
	debug_window.size = Vector2i(600, 450)
	debug_window.position = Vector2i(100, 100) 

	# 【重要修正】：強制這是一個獨立的 OS 視窗，而不是被主視窗包住 (Embedded)
	debug_window.wrap_controls = true
	debug_window.transient = false # 確保它不會被強制置頂或黏在主視窗上

	# 設定視窗關閉行為：點擊 X 時只是隱藏，不要銷毀
	debug_window.close_requested.connect(func(): toggle_window(false))

	# 2. 建立主佈局容器 (VBoxContainer)
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_window.add_child(main_vbox)

	# 3. 建立文字顯示區 (RichTextLabel)
	text_box = RichTextLabel.new()
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL # 讓 Log 填滿剩餘的垂直空間
	text_box.scroll_following = true # 自動捲動到最底下
	text_box.add_theme_font_size_override("normal_font_size", 14)
	text_box.bbcode_enabled = true # 啟用 BBCode 來支援多色文字

	# 給文字框一個深色背景 (改用 PanelContainer 確保佈局正確展開)
	var bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	bg.add_theme_stylebox_override("panel", style)
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL # 讓 Panel 填滿上方空間
	
	bg.add_child(text_box)
	main_vbox.add_child(bg)

	# 4. 建立作弊按鈕區 (HBoxContainer) - 移動控制
	var cheat_hbox = HBoxContainer.new()
	main_vbox.add_child(cheat_hbox)

	# 加入 1~6 步的測試按鈕
	for i in range(1, 7):
		var btn = Button.new()
		btn.text = " %d步 " % i
		# 使用 bind 將參數綁定到回呼函式中
		btn.pressed.connect(_on_cheat_move_pressed.bind(i))
		cheat_hbox.add_child(btn)

	# 5. 建立 AI 工具按鈕區 (HBoxContainer) - AI 控制
	var ai_tools_hbox = HBoxContainer.new()
	main_vbox.add_child(ai_tools_hbox)

	# 加入 AI 重新讀取設定按鈕
	var btn_reload_ai = Button.new()
	btn_reload_ai.text = " 讀取 AI 設定 "
	btn_reload_ai.pressed.connect(_on_reload_ai_pressed)
	ai_tools_hbox.add_child(btn_reload_ai)

	# 加入 AI 測試連線按鈕
	var btn_test_ai = Button.new()
	btn_test_ai.text = " 測試 AI 連線 "
	btn_test_ai.pressed.connect(_on_test_ai_pressed)
	ai_tools_hbox.add_child(btn_test_ai)

	# 預留空按鈕
	var btn_test_news_ui = Button.new()
	btn_test_news_ui.text = " 測試晨報 UI "
	btn_test_news_ui.pressed.connect(_on_test_news_ui_pressed)
	ai_tools_hbox.add_child(btn_test_news_ui)

	# 加入印出全域設定按鈕
	var btn_print_settings = Button.new()
	btn_print_settings.text = " 列印全域設定 "
	btn_print_settings.pressed.connect(_on_print_settings_pressed)
	ai_tools_hbox.add_child(btn_print_settings)

	# 加入列印所有事件卡片按鈕
	var btn_print_events = Button.new()
	btn_print_events.text = " 列印所有事件 "
	btn_print_events.pressed.connect(_on_print_events_pressed)
	ai_tools_hbox.add_child(btn_print_events)

	# 6. 建立玩家人數切換按鈕區 (HBoxContainer)
	var players_hbox = HBoxContainer.new()
	main_vbox.add_child(players_hbox)
	
	for i in range(1, 5):
		var btn = Button.new()
		btn.text = " %d人遊戲 " % i
		btn.pressed.connect(_on_cheat_set_players.bind(i))
		players_hbox.add_child(btn)

	# 7. 將視窗加入到目前的 Scene Tree 中
	call_deferred("add_child", debug_window)
	log_msg("Debug Console Initialized. Log file saved at: " + ProjectSettings.globalize_path(LOG_FILE_PATH))

# ---------------------------------------------------------
# 作弊與開發工具按鈕事件處理 (Cheat Button Handlers)
# ---------------------------------------------------------

func _on_print_events_pressed() -> void:
	var processor = get_node_or_null("/root/EventProcessor")
	if processor != null:
		log_msg("📋 目前牌堆 (機會/命運) 所有事件清單：", true)
		for category in processor.default_events.keys():
			log_msg("【%s】牌堆 (共 %d 張):" % [category.to_upper(), processor.default_events[category].size()])
			for event in processor.default_events[category]:
				var id = event.get("id", "unknown")
				var title = event.get("title", "無標題")
				var weight = event.get("weight", 0)
				log_msg("  - [%s] %s (權重: %s)" % [id, title, str(weight)])
		log_msg("=========================")
	else:
		log_msg("[ERROR] 找不到 EventProcessor！")

func _on_cheat_set_players(count: int) -> void:
	if main_controller != null and main_controller.has_method("force_set_player_count"):
		main_controller.force_set_player_count(count)
	else:
		log_msg("[ERROR] Main Controller 未註冊或不支援 force_set_player_count！")

func _on_cheat_move_pressed(steps: int) -> void:
	if main_controller != null and main_controller.has_method("force_move"):
		main_controller.force_move(steps)
	else:
		log_msg("[ERROR] Main Controller 未註冊或不支援 force_move！")

func _on_reload_ai_pressed() -> void:
	var ai_manager = get_node_or_null("/root/AIManager")
	if ai_manager != null and ai_manager.has_method("load_config"):
		log_msg("🔄 重新讀取 AI 設定檔...")
		ai_manager.load_config()
	else:
		log_msg("[ERROR] AIManager 未註冊，無法重新讀取設定！")

func _on_test_news_ui_pressed() -> void:
	log_msg("📡 [測試] 強制開啟每日晨報 UI...")
	var news_manager = get_node_or_null("/root/NewsManager")
	if news_manager:
		var today_date: String = Time.get_date_string_from_system()
		news_manager._open_news_onboarding_ui(today_date)
	else:
		log_msg("[ERROR] 找不到 NewsManager！請先在 Project Settings 註冊 AutoLoad。")

func _on_test_ai_pressed() -> void:
	var ai_manager = get_node_or_null("/root/AIManager")
	if ai_manager == null or not ai_manager.has_method("is_ai_ready"):
		log_msg("[ERROR] AIManager 未註冊！")
		return
	
	if not ai_manager.is_ai_ready():
		log_msg("[ERROR] AI 未啟用，無法測試連線！請先讀取正確的設定檔。")
		return
		
	log_msg("📡 正在測試 AI API 連線至: " + ai_manager.api_endpoint)
	ai_manager.test_connection()

func _on_print_settings_pressed() -> void:
	var settings = SettingsManager.current
	log_msg("=== 遊戲全域設定 (GameSettings) ===")
	log_msg("  [Rules] 允許原路折返 (allow_backtracking): " + str(settings.rule_allow_backtracking))
	log_msg("  [Rules] 岔路選擇模式 (branch_selection_mode): " + str(settings.rule_branch_selection_mode) + " (0:手動, 1:隨機)")
	log_msg("  [Display] 全螢幕 (fullscreen): " + str(settings.display_fullscreen))
	log_msg("  [Display] 移動速度 (move_speed): " + str(settings.display_move_speed) + " (0:正常, 1:快速, 2:瞬間)")
	log_msg("  [Audio] 主音量 (master_volume): " + str(settings.audio_master_volume))
	log_msg("  [AI] 啟用 AI 對話 (ai_enabled): " + str(settings.ai_enabled))
	log_msg("===============================")
# ---------------------------------------------------------
# 全域呼叫的印 Log 函式
# ---------------------------------------------------------# update_ui: 如果為 true，這段文字會同時顯示在遊戲主畫面的提示框中
func log_msg(msg: String, update_ui: bool = false) -> void:
	# 加上時間戳記
	var time_dict = Time.get_datetime_dict_from_system()
	var time_str = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
	var formatted_msg = "[%s] %s" % [time_str, msg]
	
	# 1. 永遠印在底層編輯器的 Output (最保險)
	print("[Debug] " + formatted_msg)
	
	# 2. 如果視窗存在且開啟，印在獨立視窗上 (使用 bbcode 上色)
	if is_enabled and text_box != null:
		text_box.append_text("[color=gray][%s][/color] %s\n" % [time_str, msg])
		
	# 3. 同步寫入實體 Log 檔案
	if log_file != null and log_file.is_open():
		log_file.store_string(formatted_msg + "\n")
		log_file.flush() # 強制寫入硬碟，避免遊戲崩潰時遺失 Log
		
	# 4. 如果有要求，且綁定了 UI Label，就更新主畫面
	if update_ui and status_label_ref != null:
		# 主畫面不需要時間戳記，只要顯示精簡訊息
		status_label_ref.text = msg

# 在遊戲關閉時確保檔案正確關閉
func _exit_tree() -> void:
	if log_file != null and log_file.is_open():
		log_file.store_string("=== Session Ended ===\n")
		log_file.close()

# 開關視窗的 API
func toggle_window(show: bool) -> void:
	is_enabled = show
	if debug_window != null:
		debug_window.visible = show
		# 如果視窗被隱藏，Godot 的渲染引擎就會停止繪製這個 Viewport，效能開銷降為 0
