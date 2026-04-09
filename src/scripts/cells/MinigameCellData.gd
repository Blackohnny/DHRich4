extends CellData
class_name MinigameCellData

@export var minigame_id: String = "dice_guessing" # 可查表開啓對應的遊戲場景
@export var difficulty: int = 1 # 預設難度

func _init(_name: String = "小遊戲", _pos: Vector2 = Vector2.ZERO):
	super(_name, _pos)
