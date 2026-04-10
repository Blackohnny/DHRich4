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

# --- 按鈕事件處理 ---
func _on_settings_pressed() -> void:
	DebugLogger.log_msg("⚙️ 開啟設定選單 (尚未實作)", true)

func _on_status_pressed() -> void:
	DebugLogger.log_msg("📊 開啟玩家狀態 (尚未實作)", true)

func _on_inventory_pressed() -> void:
	DebugLogger.log_msg("🎒 開啟背包 (尚未實作)", true)

func _on_map_pressed() -> void:
	DebugLogger.log_msg("🗺️ 開啟大地圖 (尚未實作)", true)
