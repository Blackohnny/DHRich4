extends Node2D

# 遊戲狀態列舉 (State Machine)
enum GameState {
	WAITING_ROLL,  # 等待玩家擲骰子
	MOVING,        # 玩家移動動畫中 (鎖定輸入)
	EVENT_HANDLING # 處理格子事件 (買地/付錢/機會命運)
}

# 變數宣告 (使用強型別以符合 C++ 習慣)
var current_state: GameState = GameState.WAITING_ROLL
var current_pos_index: int = 0

# 【架構重構】：使用外部的 BoardData 資源
@export var current_board: BoardData

# 取得場景上的節點參考
@onready var player: Sprite2D = $Player
@onready var board_node: Node2D = $Board
@onready var info_label: Label = $UI/InfoLabel
@onready var debug_toggle_btn: Button = $UI/DebugToggleButton

# 載入預設圖片
var cell_texture: Texture2D

func _ready() -> void:
	# 在 _ready 階段動態載入圖片
	cell_texture = ResourceManager.load_image_with_fallback("Mew.png") 
	player.texture = ResourceManager.load_image_with_fallback("Cyndaquil.png") 

	_init_board() # 載入或生成地圖資料
	_draw_board_cells()

	# 將主畫面的 UI 文字框註冊給 DebugLogger 統一管理
	DebugLogger.register_status_label(info_label)

	# 綁定實體按鈕
	debug_toggle_btn.pressed.connect(func(): DebugLogger.toggle_window(not DebugLogger.is_enabled))

	# 遊戲開始，將玩家放到第 0 格
	if current_board and current_board.cells.size() > 0:
		player.position = current_board.cells[0].position

		# --- 自動縮放玩家圖示 ---
		var p_tex_size: Vector2 = player.texture.get_size()
		var p_target_size: float = 60.0
		player.scale = Vector2(p_target_size / p_tex_size.x, p_target_size / p_tex_size.y)
		# --------------------------

	# 初始化狀態提示
	DebugLogger.log_msg("遊戲開始！按空白鍵 (Space) 擲骰子。", true)

func _process(delta: float) -> void:
	# 按下 ESC 鍵來開關 Debug 視窗 (Godot 預設 ui_cancel 就是 ESC)
	if Input.is_action_just_pressed("ui_cancel"):
		DebugLogger.toggle_window(not DebugLogger.is_enabled)

	# 狀態機：只有在 WAITING_ROLL 狀態才能擲骰子
	if current_state == GameState.WAITING_ROLL:
		if Input.is_action_just_pressed("ui_accept"):
			_roll_dice_and_move()

# 1. 初始化地圖資料 (如果是從編輯器掛載進來的，就不需要產生)
func _init_board() -> void:
	if current_board == null:
		# 嘗試載入專案內建的 default map
		current_board = load("res://data/map_default.tres")
		
		if current_board == null:
			# 如果連實體檔案都遺失了，這代表專案結構被破壞
			DebugLogger.log_msg("[FATAL ERROR] 找不到預設地圖檔 'map_default.tres'！遊戲無法繼續。")
			return
			
		DebugLogger.log_msg("成功載入專案預設地圖 (8字形)！總格數：" + str(current_board.cells.size()))
	else:
		DebugLogger.log_msg("成功載入外部關卡地圖資源！總格數：" + str(current_board.cells.size()))

# 2. (純視覺) 把棋盤畫出來
func _draw_board_cells() -> void:
	if current_board == null: return

	for i in range(current_board.cells.size()):
		var cell_data: CellData = current_board.cells[i]

		var cell: Sprite2D = Sprite2D.new()
		cell.texture = cell_texture
		cell.position = cell_data.position

		# --- 自動縮放格子圖示 ---
		var tex_size: Vector2 = cell.texture.get_size()
		var target_visual_size: float = 80.0
		cell.scale = Vector2(target_visual_size / tex_size.x, target_visual_size / tex_size.y)
		# --------------------------

		# 根據格子種類給予不同的顏色標示 (方便 Debug)
		if cell_data.type == CellData.CellType.START:
			cell.modulate = Color(0.8, 0.8, 0.2, 1.0) # 起點：黃色
		elif cell_data.type == CellData.CellType.EVENT:
			cell.modulate = Color(0.8, 0.2, 0.8, 1.0) # 事件：紫色
		else:
			cell.modulate = Color(0.3, 0.3, 0.3, 1.0) # 土地：灰色

		board_node.add_child(cell)

		# 加上數字標籤
		var label = Label.new()
		label.text = str(i)
		label.position = Vector2(-10, -10) # 微調文字置中
		cell.add_child(label)

# 3. 擲骰子並觸發移動
func _roll_dice_and_move() -> void:
	current_state = GameState.MOVING # 切換狀態：移動中

	# Godot 內建亂數，randi_range 產生指定範圍的整數
	var dice_roll: int = randi_range(1, 4) # 先用 1~4，避免一次走完一整圈

	DebugLogger.log_msg("🎲 玩家骰出了 %d 點，移動中..." % dice_roll, true)

	var target_index: int = (current_pos_index + dice_roll) % current_board.cells.size()
	_move_player_to(target_index)

# 4. 實作玩家平移動畫 (Tween)
func _move_player_to(target_index: int) -> void:
	var target_pos: Vector2 = current_board.cells[target_index].position

	var tween: Tween = create_tween()
	tween.tween_property(player, "position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(_on_tween_finished.bind(target_index))

func _on_tween_finished(target_index: int) -> void:
	current_pos_index = target_index

	current_state = GameState.EVENT_HANDLING 
	_handle_cell_event(current_pos_index)

# 5. 處理格子事件 (買地、機會命運等邏輯的進入點)
func _handle_cell_event(cell_index: int) -> void:
	var current_cell: CellData = current_board.cells[cell_index]

	# 將詳細資訊印到 DebugLogger，並同步更新到主畫面的 UI (第二個參數傳 true)
	var log_str = "📍 停在第 %d 格 [%s]" % [cell_index, current_cell.name]
	if current_cell.type == CellData.CellType.LAND:
		log_str += " (售價: $%d, 擁有者: %d)" % [current_cell.price, current_cell.owner_id]
	DebugLogger.log_msg(log_str, true)

	# 為了測試狀態機循環，我們先用定時器假裝處理了 1 秒鐘的事件，然後回到可擲骰子狀態
	await get_tree().create_timer(1.0).timeout 

	_end_turn()

# 6. 回合結束，準備下一回合
func _end_turn() -> void:
	current_state = GameState.WAITING_ROLL
	DebugLogger.log_msg("回合結束。請按空白鍵 (Space) 擲骰子。", true)
