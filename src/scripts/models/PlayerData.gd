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
var _properties: Array = [] # 持有的地產 ID 或參考
# 將 _items 改為存放 ItemData 資源的 Array (確保強型別)
var _items: Array[ItemData] = []

func _init(_id: int, _name: String, _avatar: String, _is_ai: bool = false) -> void:
	self.id = _id
	self.name = _name
	self.avatar_filename = _avatar
	self.is_ai = _is_ai
	
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
	var can_see_all = (viewer_id == self.id)

	# 計算公開的估計總資產 (暫時寫死房地產價值 2500)
	var estimated_net_worth = _cash + _deposit + 2500
	
	# 將 _items 的資料萃取出來傳遞給 UI，避免直接把 Resource 丟出去
	var items_view: Array[Dictionary] = []
	if can_see_all:
		for item in _items:
			items_view.append({
				"id": item.id,
				"name": item.name,
				"description": item.description,
				"type": item.type,
				"price": item.price,
				"icon": item.icon # UI 需要 icon 顯示
			})

	return {
		"id": self.id,
		"name": self.name,
		"avatar": self.avatar_filename,
		"net_worth": estimated_net_worth,

		# 敏感數值：無權限則回傳 -1 代表未知
		"cash": _cash if can_see_all else -1,
		"deposit": _deposit if can_see_all else -1,
		"points": _points if can_see_all else -1,

		# 道具與地產：無權限則只給數量，不給明細
		"items_count": _items.size(),
		"items_detail": items_view if can_see_all else [],

		"properties_count": _properties.size() + 2, # 測試假資料 2筆
		"properties_detail": [
			["台北 101", "2", "$5000", "$1500"],
			["高雄 85大樓", "1", "$2500", "$800"]
		] if can_see_all else []
	}

# ---------------------------------------------------------
# 資產操作 API (內部信任呼叫)
# ---------------------------------------------------------
func add_cash(amount: int) -> void:
	_cash += amount
	DebugLogger.log_msg("玩家 [%s] 獲得 $%d，目前現金: $%d" % [name, amount, _cash], true)

func deduct_cash(amount: int) -> bool:
	if _cash >= amount:
		_cash -= amount
		DebugLogger.log_msg("玩家 [%s] 失去 $%d，目前現金: $%d" % [name, amount, _cash], true)
		return true
	else:
		# TODO: 破產或抵押邏輯
		_cash = 0
		DebugLogger.log_msg("玩家 [%s] 現金不足，宣告破產！" % name, true)
		return false

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
