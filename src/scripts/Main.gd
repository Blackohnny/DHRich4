extends Node2D

# 遊戲狀態列舉 (State Machine)
enum GameState {
	WAITING_ROLL,  # 等待玩家擲骰子
	MOVING,        # 玩家移動動畫中 (鎖定輸入)
	WAITING_FORK,  # [未來擴充] 等待玩家選擇岔路
	EVENT_HANDLING # 處理格子事件 (買地/付錢/機會命運)
}

# 變數宣告 (使用強型別以符合 C++ 習慣)
var current_state: GameState = GameState.WAITING_ROLL
var remaining_steps: int = 0

# 【架構重構】：使用外部的 BoardData 資源
@export var current_board: BoardData

# 取得場景上的節點參考
@onready var player: PlayerEntity = $Player as PlayerEntity
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
	# 把自己註冊給 Logger，讓作弊按鈕可以呼叫
	DebugLogger.register_main_controller(self)

	# 綁定實體按鈕
	debug_toggle_btn.pressed.connect(func(): DebugLogger.toggle_window(not DebugLogger.is_enabled))

	# 遊戲開始，初始化玩家
	if current_board and current_board.cells.size() > 0:
		player.setup(0, current_board)

	# 初始化狀態提示
	DebugLogger.log_msg("遊戲開始！按空白鍵 (Space) 擲骰子。", true)

func _process(_delta: float) -> void:
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

		DebugLogger.log_msg("成功載入專案預設地圖 (8字形)！")
	else:
		DebugLogger.log_msg("成功載入外部關卡地圖資源！")

	# --- 印出地圖的全域與格子參數 ---
	DebugLogger.log_msg("====== 地圖環境參數 ======")
	DebugLogger.log_msg("物價倍率: " + str(current_board.price_multiplier))
	DebugLogger.log_msg("薪水倍率: " + str(current_board.salary_multiplier))
	DebugLogger.log_msg("商店特產 (白名單): " + str(current_board.shop_specialties))
	DebugLogger.log_msg("商店違禁品 (黑名單): " + str(current_board.shop_banned_items))
	DebugLogger.log_msg("壞命運權重: " + str(current_board.bad_destiny_weight))
	DebugLogger.log_msg("==========================")

	DebugLogger.log_msg("總格數：" + str(current_board.cells.size()))
	for i in range(current_board.cells.size()):
		var cell = current_board.cells[i]
		var type_str = "未知"
		if cell is StartCellData: type_str = "起點"
		elif cell is LandCellData: type_str = "土地 (售價:$%d)" % (cell as LandCellData).price
		elif cell is ChanceCellData: type_str = "機會"
		elif cell is DestinyCellData: type_str = "命運"
		elif cell is MinigameCellData: type_str = "小遊戲"
		elif cell is ShopCellData: type_str = "商店"
		else: type_str = "空地"
		
		DebugLogger.log_msg("  [%02d] %s - %s" % [i, cell.name, type_str])

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
		if cell_data is StartCellData:
			cell.modulate = Color(0.8, 0.8, 0.2, 1.0) # 起點：黃色
		elif cell_data is ChanceCellData or cell_data is DestinyCellData or cell_data is MinigameCellData:
			cell.modulate = Color(0.8, 0.2, 0.8, 1.0) # 事件類：紫色
		elif cell_data is ShopCellData:
			cell.modulate = Color(0.2, 0.8, 0.2, 1.0) # 商店：綠色
		elif cell_data is LandCellData:
			cell.modulate = Color(0.3, 0.3, 0.3, 1.0) # 土地：深灰色
		elif cell_data.name == "未命名格子" and cell_data.next_nodes.is_empty():
			cell.modulate = Color(1.0, 0.0, 0.0, 1.0) # 未定義或錯誤：紅色
		else:
			cell.modulate = Color(0.5, 0.5, 0.5, 1.0) # 空地或預設 CellData：淺灰色

		board_node.add_child(cell)

		# 加上數字標籤
		var label = Label.new()
		label.text = str(i)
		label.position = Vector2(-10, -10) # 微調文字置中
		cell.add_child(label)

# --- 作弊與除錯 API ---
func force_move(steps: int) -> void:
	if current_state == GameState.WAITING_ROLL:
		current_state = GameState.MOVING
		remaining_steps = steps
		DebugLogger.log_msg("⚠️ 作弊：強制走 %d 步！" % steps, true)
		_process_next_step()
	else:
		DebugLogger.log_msg("[WARNING] 目前狀態不允許移動，請等回合結束！")

# 3. 擲骰子並觸發移動
func _roll_dice_and_move() -> void:
	current_state = GameState.MOVING # 切換狀態：移動中

	# Godot 內建亂數，randi_range 產生指定範圍的整數
	var dice_roll: int = randi_range(1, 6) 
	remaining_steps = dice_roll

	DebugLogger.log_msg("🎲 玩家骰出了 %d 點，開始移動..." % dice_roll, true)

	_process_next_step()

# 4. 處理下一步的遞迴邏輯 (處理有向圖走訪與步數消耗)
func _process_next_step() -> void:
	if remaining_steps <= 0:
		# 步數歸零，觸發落地事件
		_on_movement_completed()
		return

	var current_index: int = player.current_cell_index
	var current_cell: CellData = current_board.cells[current_index]
	var next_nodes: Array = current_cell.next_nodes # 放寬為無型別陣列，避免 Godot 序列化型別錯誤

	if next_nodes.is_empty():
		DebugLogger.log_msg("[ERROR] 地圖斷線！第 %d 格沒有 next_nodes" % current_index)
		_on_movement_completed()
		return

	# 尋找有效的下一步 (避免回走)
	var valid_next_nodes: Array[int] = []
	for node_index in next_nodes:
		var target_node_int = int(node_index) # 強制轉為整數
		if target_node_int != player.previous_cell_index:
			valid_next_nodes.append(target_node_int)

	if valid_next_nodes.is_empty():
		# 這是死路 (Dead end)，大富翁裡不該發生，但如果是地圖設計錯誤會走到這
		DebugLogger.log_msg("[WARNING] 走到死路，無法前進！第 %d 格" % current_index)
		_on_movement_completed()
		return

	var target_index: int = -1

	if valid_next_nodes.size() == 1:
		# 單行道，直接走
		target_index = valid_next_nodes[0]
	else:
		# 岔路處理 (目前先強制選第 0 條路，未來實作 WAITING_FORK)
		DebugLogger.log_msg("⚠️ 遇到岔路！暫時自動選擇路線...")
		target_index = valid_next_nodes[0]

	# 扣除步數
	remaining_steps -= 1

	# 呼叫 PlayerEntity 執行單步移動，並等待動畫完成 Signal
	player.move_one_step(target_index, current_board)
	await player.step_finished

	# 動畫走完一格後，檢查路過事件 (Passing Event)
	_handle_passing_event(target_index)

	# 繼續下一步
	_process_next_step()

func _handle_passing_event(cell_index: int) -> void:
	var current_cell: CellData = current_board.cells[cell_index]
	if current_cell is StartCellData:
		_passing_start_event(current_cell)
	else:
		pass # 其他格子路過暫時無事發生

func _on_movement_completed() -> void:
	current_state = GameState.EVENT_HANDLING 
	_handle_cell_event(player.current_cell_index)

# 5. 處理格子事件 (落地事件：買地、機會命運等邏輯的進入點)
func _handle_cell_event(cell_index: int) -> void:
	var current_cell: CellData = current_board.cells[cell_index]

	# 印出基本的踩點 Log
	var log_str = "📍 停在第 %d 格 [%s]" % [cell_index, current_cell.name]
	DebugLogger.log_msg(log_str, true)

	# Event Dispatcher: 根據類型路由到不同的 Handler
	if current_cell is StartCellData:
		_landing_start_event(current_cell)
	elif current_cell is LandCellData:
		_landing_land_event(current_cell)
	elif current_cell is ChanceCellData:
		_landing_chance_event(current_cell)
	elif current_cell is DestinyCellData:
		_landing_destiny_event(current_cell)
	elif current_cell is MinigameCellData:
		_landing_minigame_event(current_cell)
	elif current_cell is ShopCellData:
		_landing_shop_event(current_cell)
	elif current_cell.name == "未命名格子" and current_cell.next_nodes.is_empty():
		DebugLogger.log_msg("[WARNING] 踩到了未定義的格子 (NULL/Base)！", true)
		_end_turn()
	else:
		DebugLogger.log_msg("這是一片空地，什麼也沒發生。", true)
		_end_turn()

# ---------------------------------------------------------
# Event Handlers (事件處理函式)
# ---------------------------------------------------------

func _passing_start_event(cell: CellData) -> void:
	if cell is StartCellData:
		var start_cell = cell as StartCellData
		DebugLogger.log_msg("路過起點，領取薪水 $%d！" % start_cell.salary_amount)
		player.add_money(start_cell.salary_amount)
	else:
		DebugLogger.log_msg("路過起點，領取薪水 $2000！(預設)")
		player.add_money(2000)

func _landing_start_event(_cell: CellData) -> void:
	DebugLogger.log_msg("停在起點上。休息一回合。", true)
	_end_turn()

func _landing_land_event(cell: CellData) -> void:
	if cell is LandCellData:
		var land = cell as LandCellData
		if land.owner_id == -1:
			# 無主地，處理購買邏輯 (先用 Auto-buy 測試)
			DebugLogger.log_msg("踩到無主地 [%s]，售價 $%d，自動購買測試..." % [land.name, land.price])
			if player.deduct_money(land.price):
				land.owner_id = player.player_id
				DebugLogger.log_msg("購買成功！[%s] 擁有者變為玩家 %d" % [land.name, player.player_id])
			else:
				DebugLogger.log_msg("錢不夠，無法購買 [%s]！" % land.name)
		elif land.owner_id != player.player_id:
			# 別人的地，處理付過路費邏輯
			DebugLogger.log_msg("踩到別人的地 [%s]，需支付過路費 $%d！" % [land.name, land.base_toll])
			player.deduct_money(land.base_toll)
			# 未來: 將錢加給 owner
		else:
			# 自己的地
			DebugLogger.log_msg("踩到自己的地 [%s]，歡迎回家！" % land.name)
	else:
		DebugLogger.log_msg("[ERROR] 型別錯誤：格子宣稱是 LAND，但不是 LandCellData 實體！")
	
	await get_tree().create_timer(1.0).timeout 
	_end_turn()

func _landing_chance_event(cell: CellData) -> void:
	if cell is ChanceCellData:
		var chance = cell as ChanceCellData
		DebugLogger.log_msg("觸發機會事件 [%s]！" % chance.chance_id)
	else:
		DebugLogger.log_msg("觸發機會事件！(未設定)")
	await get_tree().create_timer(1.0).timeout 
	_end_turn()

func _landing_destiny_event(cell: CellData) -> void:
	if cell is DestinyCellData:
		var destiny = cell as DestinyCellData
		DebugLogger.log_msg("觸發命運事件 [%s]！" % destiny.destiny_id)
	else:
		DebugLogger.log_msg("觸發命運事件！(未設定)")
	await get_tree().create_timer(1.0).timeout 
	_end_turn()

func _landing_minigame_event(cell: CellData) -> void:
	if cell is MinigameCellData:
		var minigame = cell as MinigameCellData
		DebugLogger.log_msg("進入小遊戲 [%s]！難度: %d" % [minigame.minigame_id, minigame.difficulty])
	else:
		DebugLogger.log_msg("進入小遊戲！(未設定)")
	await get_tree().create_timer(1.0).timeout 
	_end_turn()

func _landing_shop_event(cell: CellData) -> void:
	if cell is ShopCellData:
		var shop = cell as ShopCellData
		DebugLogger.log_msg("進入商店 [%s]！" % shop.shop_id)
	else:
		DebugLogger.log_msg("進入商店！(未設定)")
	await get_tree().create_timer(1.0).timeout 
	_end_turn()

# 6. 回合結束，準備下一回合
func _end_turn() -> void:
	current_state = GameState.WAITING_ROLL
	DebugLogger.log_msg("回合結束。請按空白鍵 (Space) 擲骰子。", true)
