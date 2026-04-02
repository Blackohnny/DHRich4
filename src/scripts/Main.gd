extends Node2D

# 遊戲狀態列舉 (State Machine)
enum GameState {
	WAITING_ROLL,  # 等待玩家擲骰子
	MOVING,        # 玩家移動動畫中 (鎖定輸入)
	EVENT_HANDLING # 處理格子事件 (買地/付錢/機會命運)
}

# 變數宣告 (使用強型別以符合 C++ 習慣)
var current_state: GameState = GameState.WAITING_ROLL
var map_positions: Array[Vector2] = []
var current_pos_index: int = 0

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

	_generate_board_positions()
	_draw_board_cells()
	
	# 綁定實體按鈕
	debug_toggle_btn.pressed.connect(func(): DebugLogger.toggle_window(not DebugLogger.is_enabled))

	# 遊戲開始，將玩家放到第 0 格
	if map_positions.size() > 0:
		player.position = map_positions[0]

		# --- 自動縮放玩家圖示 ---
		var p_tex_size: Vector2 = player.texture.get_size()
		var p_target_size: float = 60.0
		player.scale = Vector2(p_target_size / p_tex_size.x, p_target_size / p_tex_size.y)
		# --------------------------
		
	# 初始化狀態提示
	_update_ui_state("遊戲開始！按空白鍵 (Space) 擲骰子。")

func _process(delta: float) -> void:
	# 按下 ESC 鍵來開關 Debug 視窗 (Godot 預設 ui_cancel 就是 ESC)
	if Input.is_action_just_pressed("ui_cancel"):
		DebugLogger.toggle_window(not DebugLogger.is_enabled)

	# 狀態機：只有在 WAITING_ROLL 狀態才能擲骰子
	if current_state == GameState.WAITING_ROLL:
		if Input.is_action_just_pressed("ui_accept"):
			_roll_dice_and_move()

# 1. 產生環狀棋盤的每一格座標
func _generate_board_positions() -> void:
	var center_x: float = 576.0 # 畫面寬度 1152 的一半
	var center_y: float = 324.0 # 畫面高度 648 的一半
	var cell_size: float = 100.0 # 每格間距

	# 為了簡單示範，我們做一個 4x4 的方形環狀軌道 (共 12 格)
	# 順序：上緣(向右) -> 右緣(向下) -> 下緣(向左) -> 左緣(向上)

	# 上緣 (3格)
	for i in range(3): map_positions.append(Vector2(center_x - cell_size + (i * cell_size), center_y - cell_size))
	# 右緣 (3格)
	for i in range(3): map_positions.append(Vector2(center_x + cell_size, center_y - cell_size + (i * cell_size)))
	# 下緣 (3格)
	for i in range(3): map_positions.append(Vector2(center_x + cell_size - (i * cell_size), center_y + cell_size))
	# 左緣 (3格)
	for i in range(3): map_positions.append(Vector2(center_x - cell_size, center_y + cell_size - (i * cell_size)))

# 2. (純視覺) 把棋盤畫出來
func _draw_board_cells() -> void:
	for i in range(map_positions.size()):
		var cell: Sprite2D = Sprite2D.new()
		cell.texture = cell_texture
		cell.position = map_positions[i]

		# --- 自動縮放格子圖示 ---
		# 取得這張圖片原始的寬度與高度
		var tex_size: Vector2 = cell.texture.get_size()
		# 我們希望每格最後在畫面上的大小是 80x80
		var target_visual_size: float = 80.0
		# 計算 X 和 Y 需要縮放的比例
		cell.scale = Vector2(target_visual_size / tex_size.x, target_visual_size / tex_size.y)
		# --------------------------

		cell.modulate = Color(0.3, 0.3, 0.3, 1.0) # 灰色

		# 把這格加到場景上
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

	_update_ui_state("骰出: %d 點，移動中..." % dice_roll)

	var target_index: int = (current_pos_index + dice_roll) % map_positions.size()
	_move_player_to(target_index)

# 4. 實作玩家平移動畫 (Tween)
func _move_player_to(target_index: int) -> void:
	var target_pos: Vector2 = map_positions[target_index]

	var tween: Tween = create_tween()
	# 將串接寫在同一行，避免縮排解析錯誤
	tween.tween_property(player, "position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 將匿名函式改為實體函式綁定，寫法更乾淨且不易有縮排問題
	tween.finished.connect(_on_tween_finished.bind(target_index))

func _on_tween_finished(target_index: int) -> void:
	current_pos_index = target_index
	
	# 移動結束，切換狀態為：處理事件
	current_state = GameState.EVENT_HANDLING 
	_handle_cell_event(current_pos_index)

# 5. 處理格子事件 (買地、機會命運等邏輯的進入點)
func _handle_cell_event(cell_index: int) -> void:
	_update_ui_state("目前停在第 %d 格。正在處理事件..." % cell_index)
	
	# 為了測試狀態機循環，我們先用定時器假裝處理了 1 秒鐘的事件，然後回到可擲骰子狀態
	await get_tree().create_timer(1.0).timeout # Godot 的 Coroutine 延遲寫法 (超好用!)
	
	_end_turn()

# 6. 回合結束，準備下一回合
func _end_turn() -> void:
	current_state = GameState.WAITING_ROLL
	_update_ui_state("回合結束。請按空白鍵 (Space) 擲骰子。")

# 統一管理 UI 更新
func _update_ui_state(msg: String) -> void:
	info_label.text = msg
	DebugLogger.log_msg(msg)
