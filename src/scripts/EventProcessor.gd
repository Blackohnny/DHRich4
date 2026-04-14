extends Node

var default_events: Dictionary = {}

func _ready() -> void:
	_load_and_validate_default_events()

func _load_and_validate_default_events() -> void:
	var path = "res://data/events_default.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		DebugLogger.log_msg("[ERROR] EventProcessor 無法讀取預設事件庫: " + path)
		return
	var json_data = JSON.parse_string(file.get_as_text())
	if json_data == null:
		DebugLogger.log_msg("[ERROR] EventProcessor 解析 JSON 失敗: " + path)
		return
	default_events = json_data


## 根據卡片資料 (Dictionary) 解析並執行指令陣列
func execute_card(card_data: Dictionary, trigger_player: PlayerData) -> void:
	if not card_data.has("effects"):
		DebugLogger.log_msg("[EventProcessor] 無效的卡片資料，缺少 effects 欄位")
		return

	var effects: Array = card_data["effects"]
	for effect in effects:
		_execute_single_command(effect, trigger_player)

## 執行單一指令
func _execute_single_command(cmd_data: Dictionary, trigger_player: PlayerData) -> void:
	# 必填欄位檢查
	if not cmd_data.has("cmd") or not cmd_data.has("target"):
		DebugLogger.log_msg("[ERROR] 指令格式錯誤，缺少 cmd 或 target: " + str(cmd_data))
		return

	var cmd: String = cmd_data["cmd"]
	var target_str: String = cmd_data["target"]
	# amount 改為可選 (例如 remote_dice 不需要 amount)
	var amount: float = cmd_data.get("amount", 0.0) 
	var item_id: String = cmd_data.get("item_id", "")

	# 1. 決定目標對象 (Array[PlayerData])
	var target_players: Array[PlayerData] = _resolve_player_targets(target_str, trigger_player)

	# 2. 針對每一個受影響的玩家，執行動作
	for p in target_players:
		match cmd:
			"add_cash":
				p.add_cash(amount)
				DebugLogger.log_msg("事件效果：[%s] 獲得 $%d" % [p.name, amount], true)
			"deduct_cash":
				p.deduct_cash(amount, true) # 事件扣款皆為強制
				DebugLogger.log_msg("事件效果：[%s] 失去 $%d" % [p.name, amount], true)
			"deduct_points":
				p._points -= amount # 簡單扣點數，可以考慮在 PlayerData 加 deduct_points()
				DebugLogger.log_msg("事件效果：[%s] 失去 %d 點點數！" % [p.name, amount], true)
			"place_roadblock":
				DebugLogger.log_msg("事件效果：[%s] 放置了路障！(尚未實作地圖障礙物系統)" % p.name, true)
			"add_item":
				if item_id != "":
					# TODO: 從 ResourceManager 載入真正的 ItemData 實體
					DebugLogger.log_msg("事件效果：[%s] 獲得了道具 ID [%s] (尚未實作 ResourceManager 載入)" % [p.name, item_id], true)
				else:
					DebugLogger.log_msg("[ERROR] add_item 缺少 item_id 參數！")
			"set_dice":
				# 要求 Main.gd 在下一步強制走 amount 步
				var main = Engine.get_main_loop().current_scene
				if main and "forced_dice_steps" in main:
					main.forced_dice_steps = int(amount)
					DebugLogger.log_msg("事件效果：[%s] 的下一步被強制設定為 %d 步！" % [p.name, int(amount)], true)
			"remote_dice":
				# 要求 Main.gd 彈出選擇步數介面
				var main = Engine.get_main_loop().current_scene
				if main and main.has_method("open_remote_dice_ui"):
					main.open_remote_dice_ui()
			_:
				DebugLogger.log_msg("[ERROR] 未知的指令: " + cmd)

## 將 target 字串解析為實際受影響的玩家陣列
func _resolve_player_targets(target_str: String, trigger_player: PlayerData) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	match target_str:
		"self":
			result.append(trigger_player)
		"all":
			var pm = Engine.get_main_loop().current_scene.get_node_or_null("/root/PlayerManager")
			if pm: result = pm.get_all_players()
		"others":
			var pm = Engine.get_main_loop().current_scene.get_node_or_null("/root/PlayerManager")
			if pm:
				for p in pm.get_all_players():
					if p.id != trigger_player.id:
						result.append(p)
		_:
			DebugLogger.log_msg("[ERROR] 未知的目標字串: " + target_str)
	return result
