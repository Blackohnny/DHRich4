class_name ConfirmDialogUI extends Control

## 當對話框被操作後發出。
## 參數 result: true 代表按下確認 (或唯一按鈕), false 代表按下取消。
signal dialog_resolved(result: bool)

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	
	# 對話框必須出現在最上層 (統一塗層管理)
	z_index = ZLayer.UI_OVERLAY

## 初始化對話框
## `is_dual_choice` 為 true 顯示「確認/取消」，為 false 只顯示「確定」
func setup(title: String, message: String, is_dual_choice: bool = true, confirm_text: String = "確認", cancel_text: String = "取消") -> void:
	title_label.text = title
	message_label.text = message
	
	confirm_button.text = confirm_text
	
	if is_dual_choice:
		cancel_button.text = cancel_text
		cancel_button.show()
	else:
		cancel_button.hide()
		# 將唯一的按鈕置中並變大
		confirm_button.custom_minimum_size.x = 200

func _on_confirm() -> void:
	dialog_resolved.emit(true)
	queue_free()

func _on_cancel() -> void:
	dialog_resolved.emit(false)
	queue_free()
