extends Node2D

# 遊戲狀態列舉 (State Machine)
enum GameState {
	WAITING_ROLL,  # 等待玩家擲骰子
	MOVING,        # 玩家移動動畫中 (鎖定輸入)
	WAITING_FORK,  # [未來擴充] 等待玩家選擇岔路
	EVENT_HANDLING # 處理格子事件 (買地/付錢/機會命運)
}

const PLAYER_SCENE = preload("res://scenes/PlayerEntity.tscn")

# 變數宣告
var current_state: GameState = GameState.WAITING_ROLL
var remaining_steps: int = 0

# 目前畫面上所有棋子的陣列 (Index 對應 player_id)
var player_entities: Array[PlayerEntity] = []

# 目前正在行動的棋子 (快取)
var active_player_entity: PlayerEntity

# 【架構重構】：使用外部的 BoardData 資源
@export var current_board: BoardData

# 取得場景上的節點參考
@onready var board_node: Node2D = $Board
@onready var players_node: Node2D = $Board/Players
@onready var info_label: Label = $UI/InfoLabel
@onready var debug_toggle_btn: Button = $UI/DebugToggleButton

# 載入預設圖片
var cell_texture: Texture2D

func _ready() -> void:
	# 在 _ready 階段動態載入圖片
	cell_texture = ResourceManager.load_image_with_fallback("151_Mew.png") 

	_init_board() # 載入或生成地圖資料
	_draw_board_cells()

	# 將主畫面的 UI 文字框註冊給 DebugLogger 統一管理
	DebugLogger.register_status_label(info_label)
	# 把自己註冊給 Logger，讓作弊按鈕可以呼叫
	DebugLogger.register_main_controller(self)

	# 綁定實體按鈕
	debug_toggle_btn.pressed.connect(func(): DebugLogger.toggle_window(not DebugLogger.is_enabled))

	# 遊戲開始，初始化所有玩家棋子
	if current_board and current_board.cells.size() > 0:
		_spawn_players()

func _process(_delta: float) -> void:
	# 按下 ESC 鍵來開關 Debug 視窗
	if Input.is_action_just_pressed("ui_cancel"):
		DebugLogger.toggle_window(not DebugLogger.is_enabled)

	# 狀態機：只有在 WAITING_ROLL 狀態才能擲骰子
	if current_state == GameState.WAITING_ROLL:
		# TODO: 判斷現在是不是真人玩家的回合
		var current_data = PlayerManager.get_current_turn_player()
		if current_data != null and not current_data.is_ai:
			if Input.is_action_just_pressed("ui_accept"):
				_roll_dice_and_move()

# --- 動態生成玩家棋子 ---
func _spawn_players() -> void:
	# 清空舊棋子
	for child in players_node.get_children():
		child.queue_free()
	player_entities.clear()
	
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null: return
	
	var players_data = pm.get_all_players()
	for data in players_data:
		var entity = PLAYER_SCENE.instantiate() as PlayerEntity
		players_node.add_child(entity)
		# 將棋子放在起點 (index 0)
		entity.setup(data.id, 0, current_board, data.avatar_filename)
		player_entities.append(entity)
		
	# 啟動第一回合
	_start_turn()

# --- 回合控制 ---
func _start_turn() -> void:
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null: return
	
	var current_data = pm.get_current_turn_player()
	
	# 更新 active_player_entity 快取
	# Player ID 不一定等於 Index (因為我們把 P1 的 ID 設為 1，但它在 Array 裡是 Index 0)
	# 必須用迴圈找出對應 ID 的 Entity
	for entity in player_entities:
		if entity.player_id == current_data.id:
			active_player_entity = entity
			break
	
	# 【細節】：把輪到的棋子拉到最上層，其他棋子降下去
	for entity in player_entities:
		entity.set_active_turn(entity == active_player_entity)
		
	current_state = GameState.WAITING_ROLL
	forced_dice_steps = 0
	DebugLogger.log_msg("=== 輪到 [%s] 的回合 ===" % current_data.name, true)
	
	# 如果是 AI，自動假裝思考後擲骰
	if current_data.is_ai:
		DebugLogger.log_msg("電腦思考中...")
		await get_tree().create_timer(1.0).timeout
		_roll_dice_and_move()
	else:
		DebugLogger.log_msg("請按空白鍵 (Space) 擲骰子。")

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
func force_set_player_count(count: int) -> void:
	if current_state != GameState.WAITING_ROLL:
		DebugLogger.log_msg("[WARNING] 必須在等待擲骰時才能更改遊戲人數！")
		return
		
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null:
		DebugLogger.log_msg("[ERROR] PlayerManager 未啟動，無法設定玩家數量！")
		return
		
	DebugLogger.log_msg("⚠️ 作弊：強制將遊戲人數重置為 %d 人！" % count, true)
	
	# 重置 PlayerManager 裡的玩家資料
	pm.players.clear()
	pm.current_turn_index = 0
	
	var default_avatars = [
		"155_Cyndaquil.png",
		"138_Omanyte.png",
		"376_Metagross.png",
		"151_Mew.png"
	]
	
	for i in range(count):
		var is_bot = (i > 1) # 前 2 個是真人，其他是電腦
		var p_name = "玩家 %d" % (i + 1) if not is_bot else "電腦 %d" % (i - 1)
		# 特別幫玩家 1 加上 (你)
		if i == 0: p_name = "玩家 1 (你)"
			
		var p_data = PlayerData.new(i, p_name, default_avatars[i % default_avatars.size()], is_bot)
		pm.players.append(p_data)
		
	# 清空並根據新的玩家人數動態生成棋子
	_spawn_players()
	
	DebugLogger.log_msg("遊戲人數已重置為 %d 人。切換狀態 UI 即可看到變化。" % count)

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

	var dice_roll: int = 0
	if forced_dice_steps > 0:
		dice_roll = forced_dice_steps
		DebugLogger.log_msg("🎲 玩家使用了道具，強制走 %d 步！" % dice_roll, true)
		forced_dice_steps = 0
	else:
		dice_roll = randi_range(1, 6)
		DebugLogger.log_msg("🎲 玩家骰出了 %d 點，開始移動..." % dice_roll, true)

	remaining_steps = dice_roll
	_process_next_step()


# 4. 處理下一步的遞迴邏輯 (處理有向圖走訪與步數消耗)
func _process_next_step() -> void:
	if remaining_steps <= 0:
		# 步數歸零，觸發落地事件
		_on_movement_completed()
		return

	var current_index: int = active_player_entity.current_cell_index
	var current_cell: CellData = current_board.cells[current_index]
	var next_nodes: Array = current_cell.next_nodes # 放寬為無型別陣列，避免 Godot 序列化型別錯誤

	if next_nodes.is_empty():
		DebugLogger.log_msg("[ERROR] 地圖斷線！第 %d 格沒有 next_nodes" % current_index)
		_on_movement_completed()
		return

	# 1. 建立有效的下一步清單
	var valid_next_nodes: Array[int] = []
	for node_index in next_nodes:
		var target_node_int = int(node_index) # 強制轉為整數
		
		# 防呆：檢查地圖連線是否超出邊界
		if target_node_int < 0 or target_node_int >= current_board.cells.size():
			DebugLogger.log_msg("[ERROR] 地圖設定錯誤！節點 %d 嘗試連向不存在的格子 %d" % [current_index, target_node_int])
			continue
		
		# 除非全域設定允許回走，否則過濾掉「剛走過來的路」
		if SettingsManager.current.rule_allow_backtracking:
			valid_next_nodes.append(target_node_int)
		elif target_node_int != active_player_entity.previous_cell_index:
			valid_next_nodes.append(target_node_int)

	# 2. 死路特判 (Dead End Handling - 單向道盡頭)
	# 如果過濾後沒路走，但原本是有連線的，代表這是醫院/監獄這類的死路盡頭
	if valid_next_nodes.is_empty() and not next_nodes.is_empty():
		DebugLogger.log_msg("⚠️ 遇到死巷 (單向道盡頭)，強制原路折返！", true)
		# 把原本的路加回來 (原路折返)
		for node_index in next_nodes:
			valid_next_nodes.append(int(node_index))

	if valid_next_nodes.is_empty():
		# 極端防呆 (不該發生)
		_on_movement_completed()
		return

	# 3. 決定目標節點
	var target_index: int = -1

	if valid_next_nodes.size() == 1:
		# 單行道或死巷折返，直接走
		target_index = valid_next_nodes[0]
		_execute_move_step(target_index)
	else:
		# 遇到岔路
		var current_data = PlayerManager.get_current_turn_player()
		
		if current_data.is_ai or SettingsManager.current.rule_branch_selection_mode == GameSettings.BranchSelectionMode.RANDOM:
			# AI 或是 全域設定為隨機選擇
			target_index = valid_next_nodes[randi() % valid_next_nodes.size()]
			DebugLogger.log_msg("🎲 遇到岔路，系統隨機選擇了路線...")
			_execute_move_step(target_index)
		else:
			# 真人玩家手動選擇
			current_state = GameState.WAITING_FORK
			_show_branch_selection_ui(valid_next_nodes)

# 執行單步移動與動畫
func _execute_move_step(target_index: int) -> void:
	# 扣除步數
	remaining_steps -= 1

	# 呼叫 PlayerEntity 執行單步移動，並等待動畫徹底完成 (Async/Await)
	await active_player_entity.move_one_step(target_index, current_board)

	# 動畫走完一格後，檢查路過事件 (Passing Event)
	_handle_passing_event(target_index)

	# 繼續下一步 (只有在當前的移動確實走完，才會啟動下一個遞迴)
	_process_next_step()

# --- 岔路 UI 邏輯 ---

func _show_branch_selection_ui(valid_next_nodes: Array[int]) -> void:
	DebugLogger.log_msg("⏸️ 遇到岔路，請點擊地圖上的按鈕選擇方向...", true)
	
	# 建立或取得存放岔路按鈕的容器 (放在 Board 節點下，跟隨世界座標)
	var branch_container = board_node.get_node_or_null("BranchUIContainer")
	if branch_container == null:
		branch_container = Node2D.new()
		branch_container.name = "BranchUIContainer"
		board_node.add_child(branch_container)
	
	for target_idx in valid_next_nodes:
		var target_cell = current_board.cells[target_idx]
		
		var btn = Button.new()
		btn.text = "往此走\n[%s]" % target_cell.name
		
		# 設定按鈕樣式 (綠色半透明圓角背景)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.7, 0.3, 0.9)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		
		# 設定 Hover 樣式 (更亮)
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.3, 0.9, 0.4, 1.0)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_font_size_override("font_size", 14)
		
		# 將按鈕放置於目標格子的中心偏上 (置中偏移)
		btn.custom_minimum_size = Vector2(100, 40)
		btn.position = target_cell.position - Vector2(50, 40)
		
		btn.pressed.connect(_on_branch_button_pressed.bind(target_idx))
		branch_container.add_child(btn)

func _on_branch_button_pressed(target_idx: int) -> void:
	# 移除所有岔路按鈕
	var branch_container = board_node.get_node_or_null("BranchUIContainer")
	if branch_container != null:
		for child in branch_container.get_children():
			child.queue_free()
			
	DebugLogger.log_msg("玩家選擇了路線，繼續移動...")
	
	# 恢復移動狀態
	current_state = GameState.MOVING
	_execute_move_step(target_idx)

func _handle_passing_event(cell_index: int) -> void:
	var current_cell: CellData = current_board.cells[cell_index]
	if current_cell is StartCellData:
		_passing_start_event(current_cell)
	else:
		pass # 其他格子路過暫時無事發生

func _on_movement_completed() -> void:
	current_state = GameState.EVENT_HANDLING 
	_handle_cell_event(active_player_entity.current_cell_index)

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
	var current_data = PlayerManager.get_current_turn_player()
	if cell is StartCellData:
		var start_cell = cell as StartCellData
		current_data.add_cash(start_cell.salary_amount)
	else:
		current_data.add_cash(2000)

func _landing_start_event(_cell: CellData) -> void:
	DebugLogger.log_msg("停在起點上。休息一回合。", true)
	_end_turn()

func _landing_land_event(cell: CellData) -> void:
	var current_data = PlayerManager.get_current_turn_player()
	
	if cell is LandCellData:
		var land = cell as LandCellData
		if land.owner_id == -1:
			# 無主地，處理購買邏輯 (先用 Auto-buy 測試)
			DebugLogger.log_msg("踩到無主地 [%s]，售價 $%d，自動購買測試..." % [land.name, land.price])
			if current_data.deduct_cash(land.price):
				land.owner_id = current_data.id
				DebugLogger.log_msg("購買成功！[%s] 擁有者變為玩家 %d" % [land.name, current_data.id])
			else:
				DebugLogger.log_msg("錢不夠，無法購買 [%s]！" % land.name)
		elif land.owner_id != current_data.id:
			# 別人的地，處理付過路費邏輯
			var owner_data = PlayerManager.get_player(land.owner_id)
			DebugLogger.log_msg("踩到別人的地 [%s]，需支付過路費 $%d！" % [land.name, land.base_toll])
			if current_data.deduct_cash(land.base_toll) and owner_data != null:
				owner_data.add_cash(land.base_toll)
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

		# 【優雅降級架構】檢查 AI 是否可用且已開啟
		var ai_manager = get_node_or_null("/root/AIManager")
		if ai_manager != null and ai_manager.is_ai_ready() and SettingsManager.current.ai_enabled:
			DebugLogger.log_msg("✨ 觸發 AI 機會事件 [%s]！準備連線..." % chance.chance_id, true)
			# TODO: Phase 5 實作 AI 互動介面與連線邏輯
			await get_tree().create_timer(1.5).timeout 
			_end_turn()
		else:
			# 傳統無 AI 模式 (Fallback)
			_trigger_traditional_chance_event(chance)
	else:
		DebugLogger.log_msg("觸發機會事件！(未設定)")
		await get_tree().create_timer(1.5).timeout 
		_end_turn()
# 傳統抽卡模式 (免 AI)
func _trigger_traditional_chance_event(chance: ChanceCellData) -> void:
	_draw_and_execute_card("chance")

func _trigger_traditional_destiny_event(destiny: DestinyCellData) -> void:
	_draw_and_execute_card("destiny")

func _draw_and_execute_card(category: String) -> void:
	var current_data = PlayerManager.get_current_turn_player()

	# 從 EventProcessor 取出已經載入並驗證過的 JSON
	var json_data = EventProcessor.default_events
	if json_data.is_empty() or not json_data.has(category):
		DebugLogger.log_msg("[ERROR] 事件庫是空的或找不到類別: " + category)
		_end_turn()
		return

	var events_list: Array = json_data[category]
	if events_list.is_empty():
		DebugLogger.log_msg("[ERROR] 事件庫是空的！")
		_end_turn()
		return

	# 根據 Weight 進行抽卡 (機率輪盤)
	var total_weight: float = 0.0
	for e in events_list:
		total_weight += float(e.get("weight", 1.0))

	# 使用 randf() * total_weight 來取得 0 ~ total_weight 之間的浮點數亂數
	var roll: float = randf() * total_weight
	var current_weight: float = 0.0
	var selected_card = null

	for e in events_list:
		current_weight += float(e.get("weight", 1.0))
		if roll < current_weight:
			selected_card = e
			break
	if selected_card == null:
		selected_card = events_list[0] # 防呆

	# 印出 UI
	var icon = "🎴" if category == "chance" else "💀"
	var type_str = "機會" if category == "chance" else "命運"
	DebugLogger.log_msg("%s [%s卡] %s: %s" % [icon, type_str, selected_card.get("title", ""), selected_card.get("description", "")], true)

	# 讓玩家看清楚卡片
	await get_tree().create_timer(2.0).timeout

	# 執行效果 (呼叫 EventProcessor)
	EventProcessor.execute_card(selected_card, current_data)

	await get_tree().create_timer(1.0).timeout
	_end_turn()
func _landing_destiny_event(cell: CellData) -> void:
	if cell is DestinyCellData:
		var destiny = cell as DestinyCellData
		var ai_manager = get_node_or_null("/root/AIManager")
		if ai_manager != null and ai_manager.is_ai_ready() and SettingsManager.current.ai_enabled:
			DebugLogger.log_msg("💀 觸發 AI 命運事件 [%s]！準備連線..." % destiny.destiny_id, true)
			# TODO: Phase 5
			await get_tree().create_timer(1.5).timeout 
			_end_turn()
		else:
			_trigger_traditional_destiny_event(destiny)
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
	var pm = get_node_or_null("/root/PlayerManager")
	if pm != null:
		var next_player = pm.advance_turn()
		if next_player != null:
			_start_turn()
			return
			
	# Fallback (防呆)
	current_state = GameState.WAITING_ROLL
	forced_dice_steps = 0
	DebugLogger.log_msg("回合結束。請按空白鍵 (Space) 擲骰子。", true)

# ---------------------------------------------------------
# 道具使用邏輯 (Inventory & Items)
# ---------------------------------------------------------
var forced_dice_steps: int = 0

func on_inventory_item_used(item_data: ItemData) -> void:
	if current_state != GameState.WAITING_ROLL:
		DebugLogger.log_msg("[警告] 只有在等待擲骰時才能使用道具！")
		return
		
	DebugLogger.log_msg("💥 玩家使用了道具：[%s]" % item_data.name, true)
	
	# 將道具的 effects 轉換為假卡片格式，丟給 EventProcessor 處理
	var mock_card = {"effects": item_data.effects}
	var current_player = PlayerManager.get_current_turn_player()
	
	var processor = get_node_or_null("/root/EventProcessor")
	if processor != null:
		processor.execute_card(mock_card, current_player)
	else:
		EventProcessor.new().execute_card(mock_card, current_player)

func open_remote_dice_ui() -> void:
	# 暫時用作弊視窗的按鈕代替，這裡應該要彈出一個 1-6 的按鈕視窗
	DebugLogger.log_msg("📡 開啟遙控骰子選擇介面！(尚未實作 UI，請使用作弊面板點擊「走 1 步」~「走 6 步」按鈕代替)", true)
	# 進入特殊狀態，等待玩家從外部輸入步數
	current_state = GameState.EVENT_HANDLING 

# ---------------------------------------------------------
