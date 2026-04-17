class_name DestinyDialogUI extends Control

signal player_replied(text: String)
signal dialog_closed()

@onready var title_label: Label = %TitleLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var chat_history_label: RichTextLabel = %ChatHistoryLabel
@onready var player_input: LineEdit = %PlayerInput
@onready var send_button: Button = %SendButton
@onready var close_button: Button = %CloseButton

var _chat_history: String = ""
var _npc_name: String = "神明"
var _replies_left: int = 0

func _ready() -> void:
	# 綁定按鈕與輸入框事件
	send_button.pressed.connect(_on_send_pressed)
	player_input.text_submitted.connect(_on_input_submitted)
	close_button.pressed.connect(_on_close_pressed)
	
	# 設定全域圖層層級 (確保蓋在所有東西上面)
	z_index = ZLayer.UI_OVERLAY

## 初始化對話框 (由 Main.gd 或 AIManager 呼叫)
func setup(title: String = "命運的審判", npc_name: String = "神明", max_replies: int = 3) -> void:
	title_label.text = title
	_npc_name = npc_name
	_replies_left = max_replies
	_chat_history = "[color=gray][系統] 你可以回覆 %d 次。[/color]\n\n" % _replies_left
	chat_history_label.text = _chat_history + "[color=gray]%s正在降臨中 (首次連線喚醒模型可能需要 5~10 秒，請稍候)...[/color]" % _npc_name
	_set_input_enabled(false) # 一開始等 NPC 講話

## 新增神明 (AI) 的對話
func add_ai_message(text: String) -> void:
	_chat_history += "[color=gold][b]%s：[/b][/color] %s\n\n" % [_npc_name, text]
	_update_chat_history()
	_set_input_enabled(true) # 輪到玩家輸入
	player_input.grab_focus()

## 顯示最終審判結果並準備關閉
func show_final_judgment(text: String) -> void:
	_chat_history += "[color=red][b]最終裁決：[/b][/color] %s\n" % text
	_update_chat_history()
	_set_input_enabled(false)
	
	# 顯示關閉按鈕
	send_button.hide()
	player_input.hide()
	close_button.show()
	close_button.grab_focus()

## 將系統執行的實際效果用醒目文字顯示於對話框最底下
func show_effect_summary(effects_text: String) -> void:
	if effects_text.is_empty():
		return
	
	_chat_history += "\n[color=yellow][b]==== 命運的影響 ====\n"
	_chat_history += effects_text
	_chat_history += "================[/b][/color]\n"
	
	_update_chat_history()

func _on_send_pressed() -> void:
	_submit_player_text(player_input.text)

func _on_input_submitted(text: String) -> void:
	_submit_player_text(text)

func _submit_player_text(text: String) -> void:
	var clean_text = text.strip_edges()
	if clean_text.is_empty():
		return
		
	_replies_left -= 1
	var status_text = "[color=gray]%s正在思考裁決... (剩餘回覆次數: %d)[/color]" % [_npc_name, max(0, _replies_left)]
	
	# 更新 UI 顯示玩家講的話，並追加「思考中」的灰色文字
	_chat_history += "[color=lightblue][b]你：[/b][/color] %s\n\n" % clean_text
	
	# 特殊處理：因為這裡要加上暫時的灰色文字，所以不呼叫 _update_chat_history，而是手動更新並捲動
	chat_history_label.text = _chat_history + status_text
	_scroll_to_bottom()
	
	# 鎖定輸入並清空
	player_input.text = ""
	_set_input_enabled(false)
	
	# 發射訊號通知邏輯層 (讓 API 開始打字)
	player_replied.emit(clean_text)

func _on_close_pressed() -> void:
	dialog_closed.emit()
	queue_free()

func _set_input_enabled(enabled: bool) -> void:
	player_input.editable = enabled
	send_button.disabled = not enabled
	if not enabled:
		player_input.placeholder_text = "等待%s回應中..." % _npc_name
	else:
		player_input.placeholder_text = "向%s輸入你的回應... (還可回覆 %d 次)" % [_npc_name, _replies_left]

# 統一更新文字並強制捲動到底部
func _update_chat_history() -> void:
	chat_history_label.text = _chat_history
	_scroll_to_bottom()

# 利用 defer 確保在下一個 frame UI 佈局更新後才去調整 ScrollBar 的值
func _scroll_to_bottom() -> void:
	# 給 Godot 引擎兩個 Frame 去計算 RichTextLabel 真實渲染後的高度
	await get_tree().process_frame
	await get_tree().process_frame
	if scroll_container != null:
		var v_scroll = scroll_container.get_v_scroll_bar()
		if v_scroll != null:
			v_scroll.value = v_scroll.max_value
