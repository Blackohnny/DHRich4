extends CellData
class_name ChanceCellData

@export var chance_id: String = "random_bonus" # 未來可查表或實作各別邏輯
@export var ai_prompt: String = "" # 預留給 Gemini 介入的提示詞

func _init(_name: String = "機會", _pos: Vector2 = Vector2.ZERO):
	super(_name, _pos)
