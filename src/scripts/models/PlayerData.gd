class_name PlayerData extends RefCounted

# ---------------------------------------------------------
# PlayerData: 玩家資料模型 (Model)
# 純粹的資料結構，不綁定任何節點或畫面，方便跨場景存取與存檔
# 加入資訊遮蔽 (Fog of War) 設計，保護底層資產不被偷看
# ---------------------------------------------------------

var id: int
var name: String
var avatar_filename: String
var is_ai: bool = false # 是否由電腦控制

# --- 財力資產 (私有變數，防止外部直接讀取) ---
var _cash: int = 2000
var _deposit: int = 500
var _points: int = 150

# --- 影響力與道具 (未來擴充) ---
var _properties: Array[LandCellData] = [] # 玩家擁有的地產
# 將 _items 改為存放 ItemData 資源的 Array (確保強型別)
var _items: Array[ItemData] = []

# --- AI 決策大腦與記憶 ---
var brain: PlayerBrain
var ai_memory: Dictionary = {"personality": "neutral"}

func _init(_id: int, _name: String, _avatar: String, _is_ai: bool = false) -> void:
	self.id = _id
	self.name = _name
	self.avatar_filename = _avatar
	self.is_ai = _is_ai

	if not _is_ai:
		brain = HumanBrain.new()
	else:
		# 測試配置：玩家 3 (電腦 B) 給予 LLM 腦，其他給 Local 假腦
		if _id == 3:
			brain = LLMAIBrain.new()
		else:
			brain = LocalAIBrain.new()
	
	# ===== 測試用：預設給予道具 =====
	if self.id == 1:
		var remote_dice = load("res://scripts/models/items/item_remote_dice.tres") as ItemData
		if remote_dice: _items.append(remote_dice)
		var card_6 = load("res://scripts/models/items/item_card_6.tres") as ItemData
		if card_6: _items.append(card_6)
		var roadblock = load("res://scripts/models/items/item_roadblock.tres") as ItemData
		if roadblock: _items.append(roadblock)
		var missile = load("res://scripts/models/items/item_missile.tres") as ItemData
		if missile: _items.append(missile)
		var turtle = load("res://scripts/models/items/item_turtle.tres") as ItemData
		if turtle: _items.append(turtle)
		var angel = load("res://scripts/models/items/item_angel.tres") as ItemData
		if angel: _items.append(angel)

# ---------------------------------------------------------
# 資訊遮蔽視圖 API (View Model / DTO)
# 任何外部系統 (UI 或 AI 對手) 想探查此玩家情報，必須透過此 API
# ---------------------------------------------------------
func get_public_view(viewer_id: int) -> Dictionary:
	var bb_mode = 0 # 0: OFF, 1: LEVEL_1, 2: LEVEL_2, 3: LEVEL_3
	var sm = Engine.get_main_loop().current_scene.get_node_or_null("/root/SettingsManager")
	if sm != null:
		bb_mode = sm.current.blackbox_mode
	var can_see_all = (viewer_id == self.id)

	# 計算公開的估計總資產 (暫時寫死房地產價值 2500)
	var estimated_net_worth = _cash + _deposit
	for prop in _properties:
		estimated_net_worth += prop.get_total_value()
	
	# 將 _items 的資料萃取出來傳遞給 UI，避免直接把 Resource 丟出去
	var items_view: Array[Dictionary] = []
	if can_see_all or bb_mode < 2:
		for item in _items:
			items_view.append({
				"id": item.id,
				"name": item.name,
				"description": item.description,
				"type": item.type,
				"price": item.price,
				"icon": item.icon # UI 需要 icon 顯示
			})



	# 根據 BlackBox 等級決定是否隱藏數值
	var show_cash = can_see_all or bb_mode < 1
	var show_items_count = can_see_all or bb_mode < 2
	var show_props_count = can_see_all or bb_mode < 3

	return {
		"id": self.id,
		"name": self.name,
		"avatar": self.avatar_filename,
		"net_worth": estimated_net_worth,

		"cash": _cash if show_cash else -1,
		"deposit": _deposit if show_cash else -1,
		"points": _points if show_cash else -1,

		"items_count": _items.size() if show_items_count else -1,
		"items_detail": items_view if (can_see_all or bb_mode < 2) else [],

		"properties_count": _properties.size() if show_props_count else -1,
		"properties_detail": _get_properties_detail_view() if (can_see_all or bb_mode < 3) else []
	}

# ---------------------------------------------------------
# 資產操作 API (內部信任呼叫)
# ---------------------------------------------------------
func add_cash(amount: int) -> void:
	_cash += amount
	DebugLogger.log_msg("玩家 [%s] 獲得 $%d，目前現金: $%d" % [name, amount, _cash], true)

func deduct_cash(amount: int, is_forced: bool = false) -> bool:
	if _cash >= amount:
		_cash -= amount
		DebugLogger.log_msg("玩家 [%s] 失去 $%d，目前現金: $%d" % [name, amount, _cash], true)
		return true
	else:
		if is_forced:
			# 如果是強制扣款 (例如付過路費)，才宣告破產並歸零
			_cash = 0
			DebugLogger.log_msg("玩家 [%s] 現金不足以支付 $%d，宣告破產！" % [name, amount], true)
			return false
		else:
			# 如果只是自願購買 (例如買地)，單純回傳失敗，不扣款也不破產
			DebugLogger.log_msg("玩家 [%s] 嘗試花費 $%d，但現金不足！" % [name, amount], true)
			return false


# ---------------------------------------------------------
# 地產增刪 API (Model)
# ---------------------------------------------------------
func add_property(land: LandCellData) -> void:
	if land and not _properties.has(land):
		_properties.append(land)

func remove_property(land: LandCellData) -> void:
	if land and _properties.has(land):
		_properties.erase(land)

# 將地產陣列轉換為 StatusUI 所需的 Dictionary 格式
func _get_properties_detail_view() -> Array[Dictionary]:
	var view: Array[Dictionary] = []
	for p in _properties:
		view.append({
			"name": p.name,
			"level": p.level,
			"value": p.get_total_value(),
			"toll": p.get_current_toll()
		})
	return view

# 道具增刪 API，直接接收 ItemData
func add_item(item: ItemData) -> void:
	if item:
		_items.append(item)
		DebugLogger.log_msg("玩家 [%s] 獲得道具: %s" % [name, item.name], true)

func remove_item(item_id: String) -> bool:
	for i in range(_items.size()):
		if _items[i].id == item_id:
			var removed_name = _items[i].name
			_items.remove_at(i)
			DebugLogger.log_msg("玩家 [%s] 失去道具: %s" % [name, removed_name], true)
			return true
	return false

# ---------------------------------------------------------
