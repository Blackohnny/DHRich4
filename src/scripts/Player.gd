extends Sprite2D
class_name PlayerEntity

# 玩家實體對應的資料 ID
var player_id: int = 0 # 支援多玩家的 ID (0: 本地玩家, 1+: AI)

# 玩家專屬狀態 (State)
var current_cell_index: int = 0
var previous_cell_index: int = -1

# 移動動畫相關 (Animation)
var _base_move_speed: float = 0.25 # 走一格需要的秒數 (步進式)

# 根據全域設定取得實際移動速度
func get_current_move_speed() -> float:
	var settings = SettingsManager.current
	match settings.display_move_speed:
		GameSettings.MoveSpeed.FAST:
			return 0.1
		GameSettings.MoveSpeed.INSTANT:
			return 0.01 # 給一個極小值避免動畫完全斷裂或除以零
		GameSettings.MoveSpeed.NORMAL, _:
			return _base_move_speed

# 定義 Signal (MVC 解耦)
signal step_finished # 走完一格觸發
signal movement_completed # 整個移動流程結束觸發

# ---------------------------------------------------------
# 公開方法 (Public Methods)
# ---------------------------------------------------------

# 初始化玩家位置與外觀
func setup(id: int, start_index: int, board: BoardData, avatar_path: String) -> void:
	if board == null or board.cells.is_empty():
		return
		
	player_id = id
	current_cell_index = start_index
	previous_cell_index = -1
	
	# 設定初始座標
	var start_cell: CellData = board.cells[start_index]
	self.position = start_cell.position
	
	# 載入大頭像
	self.texture = ResourceManager.load_image_with_fallback(avatar_path)
	
	# --- 自動縮放玩家圖示 ---
	if texture:
		var p_tex_size: Vector2 = texture.get_size()
		var p_target_size: float = 60.0
		self.scale = Vector2(p_target_size / p_tex_size.x, p_target_size / p_tex_size.y)
	
	# 預設不突顯
	set_active_turn(false)

# 將自己拉到最上層 (Z-Index)
func set_active_turn(is_active: bool) -> void:
	if is_active:
		# 讓正在行動的棋子跑到最上面，並且稍微變大一點或變亮
		z_index = 10 
		modulate = Color(1.2, 1.2, 1.2, 1.0) # 微發光
	else:
		# 休息中的棋子沉到底下
		z_index = 0
		modulate = Color(1.0, 1.0, 1.0, 1.0)

# 執行單步移動 (被 Main 控制器呼叫)
func move_one_step(target_index: int, board: BoardData) -> void:
	if board == null or target_index >= board.cells.size():
		emit_signal("step_finished")
		return
		
	var target_cell: CellData = board.cells[target_index]
	var target_pos: Vector2 = target_cell.position
	
	# 記錄前一個位置 (防止回走)
	previous_cell_index = current_cell_index
	
	# 建立平移動畫 (Tween)
	var tween: Tween = create_tween()
	# 使用稍微快一點、線性的移動感來模擬「走步」
	var current_speed = get_current_move_speed()
	tween.tween_property(self, "position", target_pos, current_speed).set_trans(Tween.TRANS_LINEAR)
	
	# 動畫結束後更新狀態並發出 Signal
	tween.finished.connect(func():
		current_cell_index = target_index
		emit_signal("step_finished")
	)
