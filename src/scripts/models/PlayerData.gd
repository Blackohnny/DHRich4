class_name PlayerData extends RefCounted

# ---------------------------------------------------------
# PlayerData: 玩家資料模型 (Model)
# 純粹的資料結構，不綁定任何節點或畫面，方便跨場景存取與存檔
# ---------------------------------------------------------

var id: int
var name: String
var avatar_filename: String
var is_ai: bool = false # 是否由電腦控制

# --- 財力資產 ---
var cash: int = 2000
var deposit: int = 500
var points: int = 150

# --- 影響力與道具 (未來擴充) ---
var properties: Array = [] # 持有的地產 ID 或參考
var items: Array = []      # 持有的道具 ID

func _init(_id: int, _name: String, _avatar: String, _is_ai: bool = false) -> void:
	self.id = _id
	self.name = _name
	self.avatar_filename = _avatar
	self.is_ai = _is_ai

# --- 資產操作 API ---
func add_cash(amount: int) -> void:
	cash += amount
	DebugLogger.log_msg("玩家 [%s] 獲得 $%d，目前現金: $%d" % [name, amount, cash], true)

func deduct_cash(amount: int) -> bool:
	if cash >= amount:
		cash -= amount
		DebugLogger.log_msg("玩家 [%s] 失去 $%d，目前現金: $%d" % [name, amount, cash], true)
		return true
	else:
		# TODO: 破產或抵押邏輯
		cash = 0
		DebugLogger.log_msg("玩家 [%s] 現金不足，宣告破產！" % name, true)
		return false
