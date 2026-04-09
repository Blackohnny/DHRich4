extends CellData
class_name DestinyCellData

@export var destiny_id: String = "random_penalty" # 查表或是寫死邏輯
@export var ai_prompt: String = "" # 預留給 Gemini 介入的提示詞

func _init(_name: String = "命運", _pos: Vector2 = Vector2.ZERO):
	super(_name, _pos)
