extends Node

## 事件處理器 (Singleton)
## 負責解析 JSON 卡片資料中的 effects 陣列，並執行對應的指令 (Command Pattern)

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
	DebugLogger.log_msg("=== 預設事件庫載入成功 ===")
	
	if default_events.has("chance"):
		DebugLogger.log_msg("  載入 [機會] 卡片: %d 張" % default_events["chance"].size())
		for card in default_events["chance"]:
			DebugLogger.log_msg("    - %s (權重: %s)" % [card.get("title", "未命名"), str(card.get("weight", 1))])
			
	if default_events.has("destiny"):
		DebugLogger.log_msg("  載入 [命運] 卡片: %d 張" % default_events["destiny"].size())
		for card in default_events["destiny"]:
			DebugLogger.log_msg("    - %s (權重: %s)" % [card.get("title", "未命名"), str(card.get("weight", 1))])
	DebugLogger.log_msg("============================")

func execute_card(card_data: Dictionary, trigger_player: PlayerData) -> void:
	var effects = card_data.get("effects", [])
	
	for effect in effects:
		var cmd = effect.get("cmd", "")
		var target = effect.get("target", "self")
		var amount = effect.get("amount", 0)
		var item_id = effect.get("item_id", "")
		
		var target_players = _resolve_player_targets(target, trigger_player)
		
		for p in target_players:
			match cmd:
				"add_cash":
					p.add_cash(amount)
					DebugLogger.log_msg("事件效果：[%s] 獲得 $%d" % [p.name, amount], true)
				"deduct_cash":
					p.deduct_cash(amount)
					DebugLogger.log_msg("事件效果：[%s] 失去 $%d" % [p.name, amount], true)
				"add_item":
					if item_id != "":
						p.add_item(item_id, amount)
						DebugLogger.log_msg("事件效果：[%s] 獲得了道具 [%s]" % [p.name, item_id], true)
					else:
						DebugLogger.log_msg("[ERROR] add_item 缺少 item_id 參數！")
				_:
					DebugLogger.log_msg("[ERROR] 未知的指令: " + cmd)

## 將 target 字串解析為實際受影響的玩家陣列
func _resolve_player_targets(target_str: String, trigger_player: PlayerData) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	var pm = get_node_or_null("/root/PlayerManager")
	if pm == null: return result
	
	match target_str:
		"self":
			result.append(trigger_player)
		"all":
			result = pm.get_all_players()
		"others":
			for p in pm.get_all_players():
				if p.id != trigger_player.id:
					result.append(p)
		"random":
			var players = pm.get_all_players()
			if not players.is_empty():
				result.append(players.pick_random())
	
	return result
