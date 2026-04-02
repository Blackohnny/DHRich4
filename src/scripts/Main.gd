extends Node2D

# --- 定義地圖格子的資料結構 ---
enum CellType {
	START, # 起點
	LAND,  # 可購買的空地
	EVENT, # 機會與命運 (AI 事件)
	SHOP,  # 商店
	NULL   # 未定義
}

class CellData:
	var type: CellType
	var name: String
	var position: Vector2
	var price: int
	var owner_id: int # -1: 無主, 0: 玩家
	
	# 建構子 (Constructor)
	func _init(_type: CellType, _name: String, _pos: Vector2, _price: int = 0):
		self.type = _type
		self.name = _name
		self.position = _pos
		self.price = _price
		self.owner_id = -1
# ------------------------------

# 遊戲狀態列舉 (State Machine)
enum GameState {
	WAITING_ROLL,  # 等待玩家擲骰子
	MOVING,        # 玩家移動動畫中 (鎖定輸入)
	EVENT_HANDLING # 處理格子事件 (買地/付錢/機會命運)
}

# 變數宣告 (使用強型別以符合 C++ 習慣)
var current_state: GameState = GameState.WAITING_ROLL
var map_cells: Array[CellData] = [] # 取代原本單純的 Vector2 陣列
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

	_generate_board_data() # 改名並升級為產生完整資料
	_draw_board_cells()

	# 將主畫面的 UI 文字框註冊給 DebugLogger 統一管理
	DebugLogger.register_status_label(info_label)

	# 綁定實體按鈕
	debug_toggle_btn.pressed.connect(func(): DebugLogger.toggle_window(not DebugLogger.is_enabled))
	# 遊戲開始，將玩家放到第 0 格
	if map_cells.size() > 0:
		player.position = map_cells[0].position

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

# 1. 產生環狀棋盤的每一格完整資料 (包含座標與屬性)
func _generate_board_data() -> void:
	var center_x: float = 576.0 # 畫面寬度 1152 的一半
	var center_y: float = 324.0 # 畫面高度 648 的一半
	var cell_size: float = 100.0 # 每格間距
	
	var temp_positions: Array[Vector2] = []

	# 產生 4x4 棋盤的 12 格外圍軌道 (去除角落重複)
	# 假設格子寬度是 cell_size。整個 4x4 方塊的寬度會是 cell_size * 4
	# 所以最左邊格子的中心點是 center - 1.5 * cell_size
	var offset = cell_size * 1.5 
	
	# 1. 上緣 (由左至右, 3格): index 0, 1, 2
	for i in range(3): 
		temp_positions.append(Vector2(center_x - offset + (i * cell_size), center_y - offset))
	# 2. 右緣 (由上至下, 3格): index 3, 4, 5
	for i in range(3): 
		temp_positions.append(Vector2(center_x + offset, center_y - offset + (i * cell_size)))
	# 3. 下緣 (由右至左, 3格): index 6, 7, 8
	for i in range(3): 
		temp_positions.append(Vector2(center_x + offset - (i * cell_size), center_y + offset))
	# 4. 左緣 (由下至上, 3格): index 9, 10, 11
	for i in range(3): 
		temp_positions.append(Vector2(center_x - offset, center_y + offset - (i * cell_size)))
	
	# 將座標轉換成帶有屬性的 CellData 物件
	for i in range(temp_positions.size()):
		var pos = temp_positions[i]
		if i == 0:
			map_cells.append(CellData.new(CellType.START, "起點", pos))
		elif i == 4 or i == 10:
			map_cells.append(CellData.new(CellType.EVENT, "機會命運", pos))
		else:
			# 隨機產生 1000 ~ 3000 的地價 (必須是 100 的倍數)
			var random_price = randi_range(10, 30) * 100
			map_cells.append(CellData.new(CellType.LAND, "土地 #" + str(i), pos, random_price))

# 2. (純視覺) 把棋盤畫出來
func _draw_board_cells() -> void:
	for i in range(map_cells.size()):
		var cell_data: CellData = map_cells[i]
		
		var cell: Sprite2D = Sprite2D.new()
		cell.texture = cell_texture
		cell.position = cell_data.position

		# --- 自動縮放格子圖示 ---
		var tex_size: Vector2 = cell.texture.get_size()
		var target_visual_size: float = 80.0
		cell.scale = Vector2(target_visual_size / tex_size.x, target_visual_size / tex_size.y)
		# --------------------------

		# 根據格子種類給予不同的顏色標示 (方便 Debug)
		if cell_data.type == CellType.START:
			cell.modulate = Color(0.8, 0.8, 0.2, 1.0) # 起點：黃色
		elif cell_data.type == CellType.EVENT:
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

	var target_index: int = (current_pos_index + dice_roll) % map_cells.size()
	_move_player_to(target_index)

# 4. 實作玩家平移動畫 (Tween)
func _move_player_to(target_index: int) -> void:
	var target_pos: Vector2 = map_cells[target_index].position

	var tween: Tween = create_tween()
	tween.tween_property(player, "position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(_on_tween_finished.bind(target_index))

func _on_tween_finished(target_index: int) -> void:
	current_pos_index = target_index
	
	current_state = GameState.EVENT_HANDLING 
	_handle_cell_event(current_pos_index)

# 5. 處理格子事件 (買地、機會命運等邏輯的進入點)
func _handle_cell_event(cell_index: int) -> void:
	var current_cell: CellData = map_cells[cell_index]
	
	# 將詳細資訊印到 DebugLogger，並同步更新到主畫面的 UI (第二個參數傳 true)
	var log_str = "📍 停在第 %d 格 [%s]" % [cell_index, current_cell.name]
	if current_cell.type == CellType.LAND:
		log_str += " (售價: $%d, 擁有者: %d)" % [current_cell.price, current_cell.owner_id]
	DebugLogger.log_msg(log_str, true)
	
	# 為了測試狀態機循環，我們先用定時器假裝處理了 1 秒鐘的事件，然後回到可擲骰子狀態
	await get_tree().create_timer(1.0).timeout 
	
	_end_turn()

# 6. 回合結束，準備下一回合
func _end_turn() -> void:
	current_state = GameState.WAITING_ROLL
	DebugLogger.log_msg("回合結束。請按空白鍵 (Space) 擲骰子。", true)
