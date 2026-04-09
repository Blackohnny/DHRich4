extends CellData
class_name ShopCellData

@export var shop_id: String = "item_shop" # 未來開啟不同道具表的 ID

func _init(_name: String = "商店", _pos: Vector2 = Vector2.ZERO):
	super(_name, _pos)
