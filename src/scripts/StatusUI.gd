extends CanvasLayer
class_name StatusUI

# --- UI 元件參考 ---
@onready var close_btn: Button = %CloseBtn
@onready var player_tabs: TabBar = %PlayerTabs
@onready var avatar_rect: TextureRect = %AvatarRect # 右上角大頭像

# 左側：財力區
@onready var cash_label: Label = %CashLabel
@onready var deposit_label: Label = %DepositLabel
@onready var net_worth_label: Label = %NetWorthLabel
@onready var points_label: Label = %PointsLabel # 商店點數

# 左側：狀態 BUFF 區
@onready var buff_container: VBoxContainer = %BuffContainer

# 右側：影響力/道具分頁區
@onready var info_tabs: TabContainer = %InfoTabs
@onready var property_list: Tree = %PropertyList # 改用 Tree 實作表格
@onready var item_list: GridContainer = %ItemList # 改用 Grid 準備放圖片

# --- 資料綁定 ---
var current_viewing_player_id: int = 0

func _ready() -> void:
	# 綁定關閉按鈕
	if close_btn: close_btn.pressed.connect(_on_close_pressed)
	
	# 綁定玩家切換分頁
	if player_tabs: player_tabs.tab_clicked.connect(_on_player_tab_clicked)
	
	# 初始化分頁名稱 (根據 PlayerManager 資料)
	_setup_tabs()
	
	# 設定 Tree (地產表格) 的標題
	property_list.set_column_title(0, "名稱")
	property_list.set_column_title(1, "等級")
	property_list.set_column_title(2, "價格")
	property_list.set_column_title(3, "過路費")
	
	# 設定欄位寬度比例
	property_list.set_column_expand_ratio(0, 3)
	property_list.set_column_expand_ratio(1, 1)
	property_list.set_column_expand_ratio(2, 1)
	property_list.set_column_expand_ratio(3, 1)

func setup(initial_player_id: int) -> void:
	current_viewing_player_id = initial_player_id
	if player_tabs:
		player_tabs.current_tab = initial_player_id
	_refresh_ui_for_player(current_viewing_player_id)

func _on_close_pressed() -> void:
	queue_free()

func _on_player_tab_clicked(tab: int) -> void:
	# 這裡的 tab index 剛好對應我們測試用的 player_id (0, 1, 2)
	_refresh_ui_for_player(tab)

func _setup_tabs() -> void:
	if not player_tabs: return
	player_tabs.clear_tabs()
	
	# 防呆：如果沒有抓到 PlayerManager，可能引擎還沒重新啟動
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null:
		player_tabs.add_tab("玩家 1 (你)")
		return
		
	var players = pm.get_all_players()
	for p in players:
		player_tabs.add_tab(p.name)

func _refresh_ui_for_player(player_id: int) -> void:
	# 防呆抓取資料
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null: return
	
	var target_player: PlayerData = pm.get_player(player_id)
	if target_player == null: return
	
	# 【真正的資訊遮蔽】：UI 應該代表「打開這個視窗的真人玩家」的視角
	# 目前在單機多人模式下，打開視窗的人就是「現在輪到回合的真人玩家」
	var my_viewer_id = 0
	var current_player = pm.get_current_turn_player()
	if current_player != null and not current_player.is_ai:
		my_viewer_id = current_player.id

	var view = target_player.get_public_view(my_viewer_id)
	var can_see_all = (view.cash != -1) # 透過回傳值判斷是否有權限看到明細
	
	# 刷新大頭貼
	if avatar_rect and view.avatar != "":
		avatar_rect.texture = ResourceManager.load_image_with_fallback(view.avatar)
	
	# 1. 刷新財力
	if can_see_all:
		cash_label.text = "現金: $%d" % view.cash
		deposit_label.text = "存款: $%d" % view.deposit
		points_label.text = "點數: %d P" % view.points
	else:
		cash_label.text = "現金: ???"
		deposit_label.text = "存款: ???"
		points_label.text = "點數: ???"
		
	net_worth_label.text = "總資產: 估計約 $%d" % view.net_worth
		
	# 2. 刷新地產表格 (Tree)
	property_list.clear()
	var root = property_list.create_item() # 隱藏的根節點
	
	if can_see_all:
		for prop_data in view.properties_detail:
			_add_property_row(root, prop_data)
	else:
		_add_property_row(root, ["未知地產 x %d" % view.properties_count, "???", "???", "???"])
		
	# 3. 刷新道具圖片 (GridContainer)
	_clear_container(item_list)
	if can_see_all:
		for item_name in view.items_detail:
			_add_item_icon(item_list, item_name)
	else:
		var unknown_label = Label.new()
		unknown_label.text = "未知道具/卡片 x %d" % view.items_count
		item_list.add_child(unknown_label)
		
	# 4. 刷新狀態
	_clear_container(buff_container)
	_add_list_item(buff_container, "無異常狀態")

# --- 輔助函式 ---
func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_list_item(container: Control, text: String) -> void:
	var lbl = Label.new()
	lbl.text = "- " + text
	lbl.add_theme_font_size_override("font_size", 18)
	container.add_child(lbl)

# 新增地產表格的橫列
func _add_property_row(root: TreeItem, columns_data: Array) -> void:
	var item = property_list.create_item(root)
	for i in range(columns_data.size()):
		item.set_text(i, columns_data[i])

# 新增道具圖片按鈕
func _add_item_icon(container: GridContainer, item_name: String) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.text = item_name # TODO: 未來換成 btn.icon = load("res://...png")
	container.add_child(btn)
