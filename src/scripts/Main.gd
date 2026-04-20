extends Node2D
class_name MainController

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

# 快取所有格子的 Node2D，方便後續更新 Icon 與外觀
var cell_icon_nodes: Array[Node2D] = []

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
	cell_texture = ResourceManager.load_image_with_fallback("cell_circle.svg") 

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
		
	# 提示：如果尚未註冊 NewsManager
	if not get_node_or_null("/root/NewsManager"):
		DebugLogger.log_msg("【注意】若要啟用每日時事卡片，請在 Project Settings > AutoLoad 註冊 res://scripts/NewsManager.gd", true)

func _process(_delta: float) -> void:
	# 按下 ESC 鍵來開關 Debug 視窗
	if Input.is_action_just_pressed("ui_cancel"):
		DebugLogger.toggle_window(not DebugLogger.is_enabled)

	# 狀態機：只有在 WAITING_ROLL 狀態才能擲骰子
	if current_state == GameState.WAITING_ROLL:
		# TODO: 判斷現在是不是真人玩家的回合
		var current_data = get_node("/root/PlayerManager").get_current_turn_player()
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
		
	# --- 套用地圖專屬視角 (Dynamic Camera View) ---
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam != null:
		if current_board.initial_camera_pos != Vector2.ZERO:
			cam.position = current_board.initial_camera_pos
			DebugLogger.log_msg("套用地圖專屬鏡頭位置: " + str(cam.position))
		if current_board.initial_camera_zoom != Vector2.ZERO:
			cam.zoom = current_board.initial_camera_zoom
			DebugLogger.log_msg("套用地圖專屬縮放比例: " + str(cam.zoom))

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
		
		# --- 動態產生格子的專屬圖標節點 (IconNode) ---
		var icon_node = Node2D.new()
		icon_node.name = "IconNode"
		# ★ 關鍵解法：將 IconNode 從 cell(Sprite2D) 中抽離出來，直接作為 board_node 的子節點！
		# 因為 cell 先前已經被大幅度縮小 (scale) 處理過，如果 IconNode 是它的子節點，
		# 裡面的所有 UI、字體、圈圈大小都會繼承那個極小的縮放比例，導致肉眼看不見！
		# 解法：改用世界絕對座標 (格子位置 + 偏移量)，並保持 1:1 的縮放比例 (scale = 1.0)
		icon_node.position = cell_data.position + cell_data.icon_offset
		# ★ 統一塗層管理：利用 ZLayer enum 確保圖示顯示在格子上層
		icon_node.z_index = ZLayer.CELL_ICON
		icon_node.z_as_relative = false # 強制為全域絕對層級
		board_node.add_child(icon_node)
		cell_icon_nodes.append(icon_node)
		
		# (1) 建立所有格子通用的底層圈圈 (預設隱藏)
		# 為了避免每次畫圖的麻煩，我們用一個 ColorRect 來代替，並設定為圓角
		var bg_circle = ColorRect.new()
		bg_circle.name = "BgCircle"
		var circle_size = 70.0 # ★ 加大圈圈，配合格子視覺大小 80.0
		bg_circle.size = Vector2(circle_size, circle_size)
		# 將原點定在中心
		bg_circle.position = Vector2(-circle_size/2, -circle_size/2)
		# 利用 StyleBoxFlat 做圓角，讓他看起來像個圈圈
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 1.0, 1.0) # 顏色之後會被 modulate 覆蓋
		style.corner_radius_top_left = int(circle_size/2)
		style.corner_radius_top_right = int(circle_size/2)
		style.corner_radius_bottom_left = int(circle_size/2)
		style.corner_radius_bottom_right = int(circle_size/2)
		# 套用 StyleBox (不過 ColorRect 不能直接套 stylebox, 所以改用 Panel)
		# 改用 Panel
		bg_circle.free() # 刪掉剛剛建的 ColorRect
		var bg_panel = Panel.new()
		bg_panel.name = "BgCircle"
		bg_panel.size = Vector2(circle_size, circle_size)
		bg_panel.position = Vector2(-circle_size/2, -circle_size/2)
		bg_panel.add_theme_stylebox_override("panel", style)
		bg_panel.hide() # 預設不顯示圈圈
		icon_node.add_child(bg_panel)
		
		# (2) 建立 Owner 字樣 (例如 P1)
		var owner_label = Label.new()
		owner_label.name = "OwnerLabel"
		owner_label.text = ""
		owner_label.add_theme_font_size_override("font_size", 20) # ★ 加大文字
		owner_label.add_theme_color_override("font_color", Color.WHITE)
		owner_label.add_theme_color_override("font_outline_color", Color.BLACK)
		owner_label.add_theme_constant_override("outline_size", 3) # ★ 加粗外框
		owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 必須加上 custom_minimum_size，Godot 才能在腳本動態生成時正確分配空間
		owner_label.custom_minimum_size = Vector2(circle_size, circle_size)
		owner_label.position = Vector2(-circle_size/2, -circle_size/2 + 20) # ★ P1 往下移一點
		icon_node.add_child(owner_label)
		
		# (3) 建立頂層的 Emoji 標籤 (例如 🏠, 🏪, ❓)
		var top_label = Label.new()
		top_label.name = "TopLabel"
		top_label.add_theme_font_size_override("font_size", 48) # ★ 大幅加大 Emoji
		# 給予最小空間並置中，才不會因為字體大小被剪裁或擠壓到消失
		top_label.custom_minimum_size = Vector2(70, 70) # ★ 對應圈圈大小
		top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 稍微往上抬一點，不要被圈圈完全蓋住
		top_label.position = Vector2(-35, -50) # ★ 重新調整 Emoji 置中並微偏上
		icon_node.add_child(top_label)

		# 根據格子類型初始化預設 Emoji
		if cell_data is StartCellData:
			top_label.text = "🚩"
		elif cell_data is ChanceCellData:
			top_label.text = "❓"
		elif cell_data is DestinyCellData:
			top_label.text = "💀"
		elif cell_data is MinigameCellData:
			top_label.text = "🎮"
		elif cell_data is ShopCellData:
			top_label.text = "🏪"
		elif cell_data is LandCellData:
			top_label.text = "🪧" # Sell 牌
			
	# 初始畫完後，強制更新一次所有 LandCellData 的狀態
	# (用來處理如果一開始就有設定 owner 的情況，或是讀取存檔時)
	for i in range(current_board.cells.size()):
		update_cell_visual(i)


# --- 負責更新單一格子外觀 (MVC View Update) ---
func update_cell_visual(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= current_board.cells.size() or cell_index >= cell_icon_nodes.size():
		return
		
	var cell_data = current_board.cells[cell_index]
	var icon_node = cell_icon_nodes[cell_index]
	
	var bg_circle = icon_node.get_node("BgCircle") as Panel
	var owner_label = icon_node.get_node("OwnerLabel") as Label
	var top_label = icon_node.get_node("TopLabel") as Label
	
	if cell_data is LandCellData:
		var land = cell_data as LandCellData
		if land.owner_id == -1:
			# 無主地
			bg_circle.hide()
			owner_label.text = ""
			top_label.text = "🪧"
		else:
			# 有人擁有
			bg_circle.show()
			owner_label.text = "P" + str(land.owner_id + 1)
			
			# 根據玩家 ID 設定圈圈顏色
			var player_colors = [
				Color(0.2, 0.6, 1.0, 0.9), # P1: 藍色
				Color(1.0, 0.3, 0.3, 0.9), # P2: 紅色
				Color(0.3, 0.8, 0.3, 0.9), # P3: 綠色
				Color(0.9, 0.7, 0.1, 0.9)  # P4: 黃色
			]
			var c_idx = land.owner_id % player_colors.size()
			bg_circle.modulate = player_colors[c_idx]
			
			# 如果是連鎖 (Monopoly)，讓圈圈發光或是變稍微大一點
			if land.is_monopoly:
				bg_circle.scale = Vector2(1.2, 1.2)
			else:
				bg_circle.scale = Vector2(1.0, 1.0)
			
			# 根據等級設定房屋圖示
			if land.level == 0: top_label.text = "🪧" # 理論上不該發生 (買了就是LV1)
			elif land.level == 1: top_label.text = "⛺"
			elif land.level == 2: top_label.text = "🏠"
			elif land.level == 3: top_label.text = "🏡"
			elif land.level == 4: top_label.text = "🏢"
			elif land.level >= 5: top_label.text = "🏰"
	else:
		# 其他類型的格子目前不需要隨事件變動外觀，保持 _draw_board_cells 的初始化即可
		pass

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
		var current_data = get_node("/root/PlayerManager").get_current_turn_player()
		
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
		_landing_land_event(current_cell, cell_index)
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
	var current_data = get_node("/root/PlayerManager").get_current_turn_player()
	if cell is StartCellData:
		var start_cell = cell as StartCellData
		current_data.add_cash(start_cell.salary_amount)
	else:
		current_data.add_cash(2000)

func _landing_start_event(_cell: CellData) -> void:
	DebugLogger.log_msg("停在起點上。休息一回合。", true)
	_end_turn()

const CONFIRM_DIALOG_SCENE = preload("res://scenes/ui/components/ConfirmDialog.tscn")

func show_dialog(title: String, message: String, is_dual: bool = true, confirm_text: String = "確認", cancel_text: String = "取消") -> bool:
	var dialog = CONFIRM_DIALOG_SCENE.instantiate() as ConfirmDialogUI
	$UI.add_child(dialog) # 加在 UI 節點下以確保在最上層
	dialog.setup(title, message, is_dual, confirm_text, cancel_text)
	
	# 使用 await 等待 signal 發出
	var result: bool = await dialog.dialog_resolved
	return result

func _landing_land_event(cell: CellData, cell_index: int) -> void:
	var current_data = get_node("/root/PlayerManager").get_current_turn_player()
	
	# 切換狀態，避免玩家在等待對話框時做其他事
	current_state = GameState.EVENT_HANDLING

	if cell is LandCellData:
		var land = cell as LandCellData
		
		# --- 無主地 ---
		if land.owner_id == -1:
			var want_to_buy = await current_data.brain.decide_buy_land(land, current_data)
			if want_to_buy:
				if current_data.deduct_cash(land.price):
					land.owner_id = current_data.id
					land.level = 1 # 買下即為 1 級 (⛺)
					current_data.add_property(land)
					_check_monopoly(land.district_id, current_data.id)
					update_cell_visual(cell_index) # 更新視覺
					if current_data.brain is HumanBrain:
						DebugLogger.log_msg("購買成功！[%s] 擁有者變為玩家 %d" % [land.name, current_data.id])
					else:
						DebugLogger.log_msg("AI 自動購買成功！[%s]" % land.name)
				elif current_data.brain is HumanBrain:
					await show_dialog("餘額不足", "您的現金不夠購買這塊地！", false, "確定")
		
		# --- 別人的地 ---
		elif land.owner_id != current_data.id:
			var owner_data = get_node("/root/PlayerManager").get_player(land.owner_id)
			var current_toll = land.get_current_toll()
			var modifier = " (含區域連鎖翻倍!)" if land.is_monopoly else ""
			
			var msg = "您踩到了 [%s] 的地盤！\n地產名稱：[%s]\n必須支付過路費：$%d%s" % [owner_data.name, land.name, current_toll, modifier]
			
			if current_data.brain is HumanBrain:
				# 真人決策：彈出單選視窗 (強迫繳費)
				await show_dialog("支付過路費", msg, false, "繳納 ($%d)" % current_toll)
			
			current_data.deduct_cash(current_toll, true)
			if owner_data: owner_data.add_cash(current_toll)
		
		# --- 自己的地 ---
		else:
			var upgrade_cost = land.get_upgrade_cost()
			if land.level >= 5:
				if current_data.brain is HumanBrain:
					await show_dialog("歡迎回家", "您的地產 [%s] 已經達到最高等級 (5級)，無法再升級了！" % land.name, false, "確定")
				else:
					DebugLogger.log_msg("AI 踩到自己的地，已達最高等級。")
			else:
				var want_to_upgrade = await current_data.brain.decide_upgrade_land(land, upgrade_cost, current_data)
				if want_to_upgrade:
					if current_data.deduct_cash(upgrade_cost):
						land.level += 1
						update_cell_visual(cell_index) # 更新視覺
						if current_data.brain is HumanBrain:
							DebugLogger.log_msg("升級成功！[%s] 升為等級 %d，過路費提升為 $%d" % [land.name, land.level, land.get_current_toll()])
						else:
							DebugLogger.log_msg("AI 升級成功！[%s] 等級 %d" % [land.name, land.level])
					elif current_data.brain is HumanBrain:
						await show_dialog("餘額不足", "您的現金不夠升級這塊地！", false, "確定")

	else:
		DebugLogger.log_msg("[ERROR] 型別錯誤：格子宣稱是 LAND，但不是 LandCellData 實體！")

	await get_tree().create_timer(1.0).timeout 
	_end_turn()

func _check_monopoly(target_district: int, p_id: int) -> void:
	if current_board == null: return
	if target_district == 0: return # 0 是特殊或無所屬區
	
	# 收集該區的所有土地
	var district_lands: Array[LandCellData] = []
	for cell in current_board.cells:
		if cell is LandCellData and (cell as LandCellData).district_id == target_district:
			district_lands.append(cell as LandCellData)
			
	if district_lands.is_empty(): return
	
	# 檢查是否全被同一個人擁有
	var is_all_owned = true
	for land in district_lands:
		if land.owner_id != p_id:
			is_all_owned = false
			break
			
	# 如果全包了，更新該區所有土地的 is_monopoly 狀態
	if is_all_owned:
		DebugLogger.log_msg("🏆 恭喜玩家 %d 達成 [%d 區] 的區域連鎖！該區過路費全面翻倍！" % [p_id, target_district], true)
		for land in district_lands:
			land.is_monopoly = true


func _landing_chance_event(cell: CellData) -> void:
	if cell is ChanceCellData:
		var chance = cell as ChanceCellData
		DebugLogger.log_msg("🎴 觸發機會事件 [%s]，準備抽卡..." % chance.chance_id, true)
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
	var current_data = get_node("/root/PlayerManager").get_current_turn_player()

	# 從 EventProcessor 取出已經載入並驗證過的 JSON
	var json_data = get_node("/root/EventProcessor").default_events
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
	get_node("/root/EventProcessor").execute_card(selected_card, current_data)

	await get_tree().create_timer(1.0).timeout
	_end_turn()
func _landing_destiny_event(cell: CellData) -> void:
	if cell is DestinyCellData:
		var destiny = cell as DestinyCellData
		var ai_manager = get_node_or_null("/root/AIManager")
		if ai_manager != null and ai_manager.is_ai_ready() and SettingsManager.current.ai_enabled:
			DebugLogger.log_msg("💀 觸發 AI 命運事件 [%s]！" % destiny.destiny_id, true)
			await _run_ai_destiny_dialog("命運之神的審判")
		else:
			_trigger_traditional_destiny_event(destiny)
	else:
		DebugLogger.log_msg("觸發命運事件！(未設定)")
		await get_tree().create_timer(1.0).timeout 
		_end_turn()

# ==============================================================================
# AI 命運之神互動流程 (Phase 5)
# ==============================================================================
func _run_ai_destiny_dialog(title: String) -> void:
	current_state = GameState.EVENT_HANDLING
	var current_player = get_node("/root/PlayerManager").get_current_turn_player()
	var ai_manager = get_node("/root/AIManager")
	
	# 動態抽取角色 (Persona)
	var persona = ai_manager.get_random_persona()
	var npc_name = persona.get("name", "神秘存在")
	var final_title = "遭遇: " + npc_name
	
	var total_rounds = 4 # 玩家可以回覆 3 次，第 4 次為神明結算

	# 載入並實例化對話框 UI
	var dialog_scene = preload("res://scenes/ui/components/DestinyDialogUI.tscn")
	var dialog: DestinyDialogUI = dialog_scene.instantiate()
	get_node("UI").add_child(dialog)
	dialog.setup(final_title, npc_name, total_rounds - 1) # 傳入 3，代表玩家有 3 次回覆機會

	var chat_history: Array = []
	
	# 綁定錯誤處理
	var on_error = func(msg: String):
		DebugLogger.log_msg("[ERROR] AI 對話發生錯誤: " + msg)
		dialog.show_final_judgment("通訊中斷，" + npc_name + "離開了。")
	ai_manager.destiny_error_occurred.connect(on_error)
	
	# === 進行 N 個來回的對話迴圈 ===
	for current_round in range(1, total_rounds + 1):
		# 1. AI 講話 (除了最後一回合外，都是單純的對話)
		var is_final = (current_round == total_rounds)
		ai_manager.request_destiny_event(chat_history, current_player.name, persona, is_final)
		var ai_res = await ai_manager.destiny_response_received

		var final_dialog: String
		var effects: Array
		var need_final_resolution: bool = false

		if is_final:
			# 正常的第四回合決算
			final_dialog = ai_res.get("dialog", "無言以對。")
			effects = ai_res.get("effects", [])
			need_final_resolution = true
		else:
			# 一般回合：檢查是否包含提早結束的 [JUDGE] 關鍵字
			var ai_msg = ai_res.get("dialog", "人類，回答我，你渴望力量嗎？")

			if ai_msg.contains("[JUDGE]"):
				DebugLogger.log_msg("【AI 提早進入裁決階段】")
				# 如果 AI 說出 [JUDGE]，代表它生氣了或決定好結果了。
				# 為了讓它產出穩定的 JSON，我們立即手動強制觸發一次 is_final = true 的 Request。
				ai_manager.request_destiny_event(chat_history, current_player.name, persona, true)
				var final_res = await ai_manager.destiny_response_received
				final_dialog = final_res.get("dialog", "無言以對。")
				effects = final_res.get("effects", [])
				need_final_resolution = true
			else:
				# 正常的對話流程
				chat_history.append({"role": "assistant", "content": ai_msg})
				dialog.add_ai_message(ai_msg)

				# 如果是 AI 電腦，就跳過 UI 輸入，直接隨機回覆
				if current_player.is_ai:
					var mock_replies = ["給我錢！", "我什麼都不要。", "請賜予我奇蹟！", "你這傢伙在說什麼？"]
					var mock_reply = mock_replies[randi() % mock_replies.size()]
					await get_tree().create_timer(1.5).timeout
					dialog._submit_player_text(mock_reply)

				# 等待玩家按下送出
				var player_text = await dialog.player_replied
				chat_history.append({"role": "user", "content": player_text})

		if need_final_resolution:
			# === 執行最終裁決的共通邏輯 ===

			# 關閉原有的聊天對話框
			if dialog != null:
				dialog.queue_free()

			# 顯示最終結果的獨立彈窗 (ConfirmDialog)
			var confirm_scene = preload("res://scenes/ui/components/ConfirmDialog.tscn")
			var confirm_ui: ConfirmDialogUI = confirm_scene.instantiate()
			get_node("UI").add_child(confirm_ui)

			var result_msg = final_dialog + "\n\n"

			if not effects.is_empty():
				var mock_card = {"effects": effects}
				var processor = get_node("/root/EventProcessor")
				var summary_text = ""
				for effect in effects:
					summary_text += processor.get_effect_description(effect) + "\n"

				result_msg += "[ 命運的影響 ]\n" + summary_text
				DebugLogger.log_msg("=== AI 裁決結果 ===\n" + summary_text.strip_edges(), true)
				processor.execute_card(mock_card, current_player)
			else:
				result_msg += "[ 命運的影響 ]\n沒有任何實質影響。"
				DebugLogger.log_msg(npc_name + " 沒有給予任何實質影響。", true)

			confirm_ui.setup("最終裁決", result_msg, false, "關閉")

			# 等待玩家按下確認後才結束回合
			await confirm_ui.dialog_resolved
			break # 無論是第幾回合，完成裁決就結束整個 Destiny 迴圈

	# ==============================	
	ai_manager.destiny_error_occurred.disconnect(on_error)
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
	var current_player = get_node("/root/PlayerManager").get_current_turn_player()
	
	var processor = get_node_or_null("/root/EventProcessor")
	if processor != null:
		processor.execute_card(mock_card, current_player)
	else:
		DebugLogger.log_msg("[ERROR] 無法取得 EventProcessor")

func open_remote_dice_ui() -> void:
	# 暫時用作弊視窗的按鈕代替，這裡應該要彈出一個 1-6 的按鈕視窗
	DebugLogger.log_msg("📡 開啟遙控骰子選擇介面！(尚未實作 UI，請使用作弊面板點擊「走 1 步」~「走 6 步」按鈕代替)", true)
	# 進入特殊狀態，等待玩家從外部輸入步數
	current_state = GameState.EVENT_HANDLING 

# ---------------------------------------------------------
