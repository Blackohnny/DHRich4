extends Sprite2D
class_name PlayerEntity

# 玩家專屬狀態 (State)
var current_cell_index: int = 0
var previous_cell_index: int = -1
var money: int = 2000 # 預設起始資金 (Phase 3 預留)
var player_id: int = 0 # 支援多玩家的 ID (0: 本地玩家, 1+: AI 或遠端)

# 移動動畫相關 (Animation)
var move_speed: float = 0.25 # 走一格需要的秒數 (步進式)

# 定義 Signal (MVC 解耦)
signal step_finished # 走完一格觸發
signal movement_completed # 整個移動流程結束觸發

# ---------------------------------------------------------
# 公開方法 (Public Methods)
# ---------------------------------------------------------

# 初始化玩家位置
func setup(start_index: int, board: BoardData) -> void:
	if board == null or board.cells.is_empty():
		return
		
	current_cell_index = start_index
	previous_cell_index = -1
	
	# 設定初始座標
	var start_cell: CellData = board.cells[start_index]
	self.position = start_cell.position
	
	# --- 自動縮放玩家圖示 ---
	if texture:
		var p_tex_size: Vector2 = texture.get_size()
		var p_target_size: float = 60.0
		self.scale = Vector2(p_target_size / p_tex_size.x, p_target_size / p_tex_size.y)

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
	tween.tween_property(self, "position", target_pos, move_speed).set_trans(Tween.TRANS_LINEAR)
	
	# 動畫結束後更新狀態並發出 Signal
	tween.finished.connect(func():
		current_cell_index = target_index
		emit_signal("step_finished")
	)

# 資產操作 API
func add_money(amount: int) -> void:
	money += amount
	DebugLogger.log_msg("玩家 %d 獲得 $%d，目前餘額: $%d" % [player_id, amount, money], true)

func deduct_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		DebugLogger.log_msg("玩家 %d 失去 $%d，目前餘額: $%d" % [player_id, amount, money], true)
		return true
	else:
		money = 0
		DebugLogger.log_msg("玩家 %d 破產了！" % player_id, true)
		return false
