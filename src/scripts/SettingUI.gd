extends CanvasLayer
class_name SettingUI

# --- 頁籤按鈕 ---
@onready var rules_tab_btn: Button = %RulesTabBtn
@onready var display_tab_btn: Button = %DisplayTabBtn
@onready var audio_tab_btn: Button = %AudioTabBtn
@onready var ai_tab_btn: Button = %AITabBtn

# --- 內容面板 ---
@onready var rules_panel: VBoxContainer = %RulesPanel
@onready var display_panel: VBoxContainer = %DisplayPanel
@onready var audio_panel: VBoxContainer = %AudioPanel
@onready var ai_panel: VBoxContainer = %AIPanel

# --- 設定元件 ---
@onready var close_btn: Button = %CloseBtn
@onready var backtrack_switch: SegmentedSwitch = %BacktrackSwitch
@onready var branch_mode_switch: SegmentedSwitch = %BranchModeSwitch
@onready var move_speed_option: OptionButton = %MoveSpeedOption
@onready var ai_toggle_switch: SegmentedSwitch = %AIToggleSwitch

func _ready() -> void:
	# 綁定頁籤切換事件
	rules_tab_btn.pressed.connect(_switch_tab.bind(rules_panel))
	display_tab_btn.pressed.connect(_switch_tab.bind(display_panel))
	audio_tab_btn.pressed.connect(_switch_tab.bind(audio_panel))
	if ai_tab_btn: ai_tab_btn.pressed.connect(_switch_tab.bind(ai_panel))
	
	# 綁定關閉事件
	close_btn.pressed.connect(_on_close_btn_pressed)
	
	# 綁定設定更新事件
	backtrack_switch.option_selected.connect(_on_backtrack_selected)
	branch_mode_switch.option_selected.connect(_on_branch_mode_selected)
	move_speed_option.item_selected.connect(_on_move_speed_selected)
	ai_toggle_switch.option_selected.connect(_on_ai_toggle_selected)
	
	# 初始化：讀取目前全域設定並套用至 UI
	_load_current_settings()
	
	# 預設開啟「遊戲規則」分頁
	_switch_tab(rules_panel)

func _load_current_settings() -> void:
	var settings = SettingsManager.current
	
	# 若 allow backtracking 為 true，代表「開啟」(左邊，index 0)，false 代表「關閉」(右邊，index 1)
	if settings.rule_allow_backtracking:
		backtrack_switch.selected_index = 0
	else:
		backtrack_switch.selected_index = 1
	
	# 若為 RANDOM (1)，則 selected_index 為 1 (右邊)
	if settings.rule_branch_selection_mode == GameSettings.BranchSelectionMode.MANUAL:
		branch_mode_switch.selected_index = 0
	else:
		branch_mode_switch.selected_index = 1
		
	# 更新移動速度
	move_speed_option.select(settings.display_move_speed)
	
	# 更新 AI 開關
	if settings.ai_enabled:
		ai_toggle_switch.selected_index = 0
	else:
		ai_toggle_switch.selected_index = 1

func _switch_tab(target_panel: Control) -> void:
	# 隱藏所有面板
	rules_panel.hide()
	display_panel.hide()
	audio_panel.hide()
	ai_panel.hide()
	
	# 顯示目標面板
	target_panel.show()

# --- 事件處理 ---

func _on_backtrack_selected(index: int) -> void:
	# index 0 代表左邊「開啟」(true)，index 1 代表右邊「關閉」(false)
	var allow = (index == 0)
	SettingsManager.current.rule_allow_backtracking = allow
	DebugLogger.log_msg("🔧 設定已變更: 允許回頭走 -> " + str(allow))

func _on_branch_mode_selected(index: int) -> void:
	if index == 0:
		SettingsManager.current.rule_branch_selection_mode = GameSettings.BranchSelectionMode.MANUAL
		DebugLogger.log_msg("🔧 設定已變更: 岔路選擇 -> 手動 (MANUAL)")
	else:
		SettingsManager.current.rule_branch_selection_mode = GameSettings.BranchSelectionMode.RANDOM
		DebugLogger.log_msg("🔧 設定已變更: 岔路選擇 -> 隨機 (RANDOM)")

func _on_move_speed_selected(index: int) -> void:
	SettingsManager.current.display_move_speed = index as GameSettings.MoveSpeed
	DebugLogger.log_msg("🔧 設定已變更: 棋子移動速度 -> " + str(index))

func _on_ai_toggle_selected(index: int) -> void:
	var enable = (index == 0)
	SettingsManager.current.ai_enabled = enable
	DebugLogger.log_msg("🔧 設定已變更: AI 命運之神對話 -> " + str(enable))

func _on_close_btn_pressed() -> void:
	SettingsManager.save_settings() # 觸發全域廣播
	queue_free()
