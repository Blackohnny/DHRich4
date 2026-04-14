extends CanvasLayer

# ---------------------------------------------------------
# UIManager: 負責管理遊戲主畫面的 UI 互動
# ---------------------------------------------------------

@onready var settings_btn: Button = %SettingsBtn
@onready var status_btn: Button = %StatusBtn
@onready var inventory_btn: Button = %InventoryBtn
@onready var map_btn: Button = %MapBtn

func _ready() -> void:
	# 綁定按鈕事件
	if settings_btn: settings_btn.pressed.connect(_on_settings_pressed)
	if status_btn: status_btn.pressed.connect(_on_status_pressed)
	if inventory_btn: inventory_btn.pressed.connect(_on_inventory_pressed)
	if map_btn: map_btn.pressed.connect(_on_map_pressed)

const STATUS_UI_SCENE = preload("res://scenes/ui/StatusUI.tscn")
const SETTING_UI_SCENE = preload("res://scenes/ui/SettingUI.tscn")
const INVENTORY_UI_SCENE = preload("res://scenes/ui/InventoryUI.tscn")

func _process(_delta: float) -> void:
	_update_buttons_state()

func _update_buttons_state() -> void:
	var can_open_all = false
	var can_open_status_only = false

	var main = get_tree().current_scene
	var pm = get_node_or_null("/root/PlayerManager")

	if main != null and "current_state" in main and pm != null:
		var current_player = pm.get_current_turn_player()
		if current_player != null and not current_player.is_ai:
				if main.current_state == MainController.GameState.WAITING_ROLL:
					can_open_all = true
				elif main.current_state == MainController.GameState.EVENT_HANDLING:
					can_open_status_only = true

	# 同步設定按鈕的可用狀態
	if settings_btn: settings_btn.disabled = not (can_open_all or can_open_status_only)
	if status_btn: status_btn.disabled = not (can_open_all or can_open_status_only)
	if inventory_btn: inventory_btn.disabled = not can_open_all
	if map_btn: map_btn.disabled = not (can_open_all or can_open_status_only)

# --- 按鈕事件處理 ---
func _on_settings_pressed() -> void:
	DebugLogger.log_msg("⚙️ 開啟設定選單", true)
	var setting_ui = SETTING_UI_SCENE.instantiate() as SettingUI
	add_child(setting_ui)
	
func _on_status_pressed() -> void:
	DebugLogger.log_msg("📊 開啟玩家狀態視窗", true)
	var status_ui = STATUS_UI_SCENE.instantiate() as StatusUI
	add_child(status_ui)
	
	# 動態抓取目前輪到回合的玩家 ID
	var pm = get_node_or_null("/root/PlayerManager")
	var target_id = 0
	if pm != null:
		var current_player = pm.get_current_turn_player()
		if current_player != null:
			target_id = current_player.id
			
	# 預設開啟該玩家的狀態分頁
	status_ui.setup(target_id)

func _on_inventory_pressed() -> void:
	DebugLogger.log_msg("🎒 開啟背包", true)
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null: return
	
	var current_player = pm.get_current_turn_player()
	if current_player == null: return
	
	var inv_ui = INVENTORY_UI_SCENE.instantiate() as InventoryUI
	add_child(inv_ui)
	inv_ui.setup(current_player)
	
	# 綁定卡牌使用事件到主場景
	var main = get_tree().current_scene
	if main.has_method("on_inventory_item_used"):
		inv_ui.item_used.connect(main.on_inventory_item_used)

func _on_map_pressed() -> void:
	DebugLogger.log_msg("🗺️ 開啟大地圖 (尚未實作)", true)
