extends Resource
class_name CellData

enum CellType {
	START, # 起點
	LAND,  # 可購買的空地
	EVENT, # 機會與命運 (AI 事件)
	SHOP,  # 商店
	NULL   # 未定義
}

@export var type: CellType = CellType.NULL
@export var name: String = "未命名格子"
@export var position: Vector2 = Vector2.ZERO
@export var price: int = 0
@export var owner_id: int = -1 # -1: 無主, 0: 玩家
@export var next_nodes: Array[int] = [] # 儲存相連格子的 Index (實作有向圖)

# 建構子 (提供預設值，讓 Resource 可以被編輯器實例化)
func _init(_type: CellType = CellType.NULL, _name: String = "", _pos: Vector2 = Vector2.ZERO, _price: int = 0):
	self.type = _type
	self.name = _name
	self.position = _pos
	self.price = _price
	self.owner_id = -1
	self.next_nodes = []