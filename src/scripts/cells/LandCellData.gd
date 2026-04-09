extends CellData
class_name LandCellData

@export var price: int = 1000
@export var base_toll: int = 200

# 執行期的動態狀態 (不 export，因為每次開局都會重置)
var owner_id: int = -1 # -1: 無主, 0: 玩家
var level: int = 0

func _init(_name: String = "未命名空地", _pos: Vector2 = Vector2.ZERO, _price: int = 1000):
	super(_name, _pos)
	self.price = _price
	self.owner_id = -1
	self.level = 0
