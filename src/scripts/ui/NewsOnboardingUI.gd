extends Control
class_name NewsOnboardingUI

signal search_requested(topics: Array[String])
signal generation_requested(news_items: Array[Dictionary])

@onready var input_screen = $ColorRect/InputScreen
@onready var topic_1 = $ColorRect/InputScreen/HBoxContainer/Topic1
@onready var topic_2 = $ColorRect/InputScreen/HBoxContainer/Topic2
@onready var topic_3 = $ColorRect/InputScreen/HBoxContainer/Topic3
@onready var refresh_btn = $ColorRect/InputScreen/HBoxContainer/RefreshButton
@onready var search_btn = $ColorRect/InputScreen/SearchButton

@onready var result_screen = $ColorRect/ResultScreen
@onready var news_list = $ColorRect/ResultScreen/ScrollContainer/NewsList
@onready var generate_btn = $ColorRect/ResultScreen/GenerateButton

var current_news_items: Array[Dictionary] = []

var default_topics: Array[String] = [
	"台灣", "手遊", "貓咪", "日本旅遊", "櫻花", 
	"遊輪", "戰爭", "氣象", "台積電", "輝達",
	"棒球", "奧運", "外星人", "颱風", "地震",
	"蘋果發表會", "加密貨幣", "特斯拉", "李珠珢", 
	"李多慧", "李雅英", "Pokemon", "購物", "手搖飲"
]

func _ready() -> void:
	# 阻擋滑鼠與鍵盤事件穿透到下方的遊戲場景
	mouse_filter = Control.MOUSE_FILTER_STOP
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	result_screen.hide()
	input_screen.show()
	
	_on_refresh_pressed()
	refresh_btn.pressed.connect(_on_refresh_pressed)
	
	search_btn.pressed.connect(_on_search_pressed)
	generate_btn.pressed.connect(_on_generate_pressed)
	
	# Handle enter key to prevent it from leaking to the game
	topic_1.text_submitted.connect(_on_line_edit_submitted)
	topic_2.text_submitted.connect(_on_line_edit_submitted)
	topic_3.text_submitted.connect(_on_line_edit_submitted)

func _on_refresh_pressed() -> void:
	var topics_copy = default_topics.duplicate()
	topics_copy.shuffle()
	
	topic_1.placeholder_text = topics_copy[0]
	topic_2.placeholder_text = topics_copy[1]
	topic_3.placeholder_text = topics_copy[2]
	
	# Clear user input if any, so placeholders show up again
	topic_1.text = ""
	topic_2.text = ""
	topic_3.text = ""

func _on_line_edit_submitted(_text: String) -> void:
	if not search_btn.disabled:
		_on_search_pressed()

func _input(event: InputEvent) -> void:
	# 攔截所有會觸發大富翁遊戲主迴圈的按鍵 (例如空白鍵、Enter 鍵)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		# 只有當焦點不在輸入框時才強制攔截，確保玩家還能正常打字
		if not topic_1.has_focus() and not topic_2.has_focus() and not topic_3.has_focus():
			get_viewport().set_input_as_handled()

func _on_search_pressed() -> void:
	var topics: Array[String] = []
	
	# Absorb the input so background doesn't get it
	get_viewport().set_input_as_handled()
	
	var t1 = topic_1.text.strip_edges()
	var t2 = topic_2.text.strip_edges()
	var t3 = topic_3.text.strip_edges()
	
	if t1.is_empty(): t1 = topic_1.placeholder_text
	if t2.is_empty(): t2 = topic_2.placeholder_text
	if t3.is_empty(): t3 = topic_3.placeholder_text
	
	topics.append(t1)
	topics.append(t2)
	topics.append(t3)
	
	search_requested.emit(topics)

func show_news_results(news_items: Array[Dictionary]) -> void:
	current_news_items = news_items
	
	# Clear previous items
	for child in news_list.get_children():
		child.queue_free()
		
	# Populate new items
	for item in news_items:
		var card = _create_news_card(item)
		news_list.add_child(card)
		
	input_screen.hide()
	result_screen.show()

func _create_news_card(item: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = item.get("title", "無標題")
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)
	
	var snippet_label = Label.new()
	snippet_label.text = item.get("snippet", "無摘要內容")
	snippet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snippet_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(snippet_label)
	
	if item.has("url") and not item.get("url").is_empty():
		var link_btn = Button.new()
		link_btn.text = "閱讀完整新聞 (瀏覽器開啟)"
		link_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		link_btn.pressed.connect(func(): OS.shell_open(item.get("url")))
		vbox.add_child(link_btn)
		
	return panel

func _on_generate_pressed() -> void:
	generation_requested.emit(current_news_items)
