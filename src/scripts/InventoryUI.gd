class_name InventoryUI extends Control

signal item_used(item_data: ItemData)

@export var item_card_scene: PackedScene = preload("res://scenes/ui/components/ItemCard.tscn")

@onready var grid_container: GridContainer = %GridContainer
@onready var close_button: Button = %CloseButton

var _current_player: PlayerData

func _ready() -> void:
	close_button.pressed.connect(queue_free)

## 初始化背包介面，注入當前玩家資料
func setup(player: PlayerData) -> void:
	_current_player = player
	_refresh_ui()

func _refresh_ui() -> void:
	# 清除舊的卡牌
	for child in grid_container.get_children():
		child.queue_free()

	# 若背包是空的，顯示提示
	if _current_player._items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "背包裡空無一物。"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# 讓它跨欄置中顯示
		grid_container.columns = 1 
		grid_container.add_child(empty_label)
		return

	# 恢復欄位數
	grid_container.columns = 4

	# 生成新的卡牌
	for item in _current_player._items:
		var card: ItemCardUI = item_card_scene.instantiate() as ItemCardUI
		grid_container.add_child(card)
		card.setup_card(item)
		card.item_used.connect(_on_card_item_used)

## 當卡牌發出被使用的訊號時觸發
func _on_card_item_used(item_data: ItemData) -> void:
	# 先把道具從玩家身上移除 (消耗)
	_current_player.remove_item(item_data.id)
	
	item_used.emit(item_data)
	queue_free() # 使用道具後直接關閉背包介面
