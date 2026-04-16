extends Resource
class_name CellData

@export var name: String = "未命名格子"
@export var position: Vector2 = Vector2.ZERO
@export var icon_offset: Vector2 = Vector2(0, -80) # 預設在格子的正上方 40 像素
@export var next_nodes: Array = [] # 儲存相連格子的 Index (實作有向圖)。放寬型別避免 Godot 編輯器讀取錯誤

# 建構子 (提供預設值，讓 Resource 可以被編輯器實例化)
func _init(_name: String = "", _pos: Vector2 = Vector2.ZERO, _icon_offset: Vector2 = Vector2(0, -80)):
	self.name = _name
	self.position = _pos
	self.icon_offset = _icon_offset
	self.next_nodes = []
