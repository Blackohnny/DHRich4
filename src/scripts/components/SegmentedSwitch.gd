extends PanelContainer
class_name SegmentedSwitch

## 發出的訊號：當選項被更改時。 index=0 代表左邊, index=1 代表右邊
signal option_selected(index: int)

@export var left_text: String = "選項 A":
	set(val):
		left_text = val
		if is_node_ready() and left_btn:
			left_btn.text = val

@export var right_text: String = "選項 B":
	set(val):
		right_text = val
		if is_node_ready() and right_btn:
			right_btn.text = val

@export var selected_index: int = 0:
	set(val):
		selected_index = clampi(val, 0, 1)
		if is_node_ready():
			_update_buttons()

@onready var left_btn: Button = %LeftBtn
@onready var right_btn: Button = %RightBtn

func _ready() -> void:
	# 套用初始文字
	left_btn.text = left_text
	right_btn.text = right_text
	
	# 綁定按鈕事件 (使用 Godot 的 ButtonGroup 特性)
	left_btn.pressed.connect(_on_btn_pressed.bind(0))
	right_btn.pressed.connect(_on_btn_pressed.bind(1))
	
	_update_buttons()

func _update_buttons() -> void:
	if selected_index == 0:
		left_btn.set_pressed_no_signal(true)
		right_btn.set_pressed_no_signal(false)
	else:
		left_btn.set_pressed_no_signal(false)
		right_btn.set_pressed_no_signal(true)

func _on_btn_pressed(index: int) -> void:
	if selected_index != index:
		selected_index = index
		option_selected.emit(index)
