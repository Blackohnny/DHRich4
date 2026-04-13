class_name ItemCardUI extends PanelContainer

# 當玩家點擊「使用」按鈕時發出，並將持有的 ItemData 實體拋出去
signal item_used(item_data: ItemData)

var _item: ItemData

@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var use_button: Button = %UseButton

func _ready() -> void:
	use_button.pressed.connect(_on_use_button_pressed)

## 由外部呼叫，注入資料
func setup_card(item_data: ItemData) -> void:
	_item = item_data
	
	if _item:
		name_label.text = _item.name
		desc_label.text = _item.description
	else:
		name_label.text = "空"
		desc_label.text = ""
		use_button.disabled = true

func _on_use_button_pressed() -> void:
	if _item:
		item_used.emit(_item)
