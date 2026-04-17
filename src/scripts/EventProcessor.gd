extends Node

var default_events: Dictionary = {}

# ==============================================================================
# AI 命運之神指令定義 (Bounded Freedom Schema)
# ==============================================================================
# 這份字典定義了 AI 能夠使用的所有合法指令與參數範圍。
# 它是「單一資料來源 (SSOT)」，不僅用於動態產生給 LLM 的 Prompt，
# 也用於在 Godot 端驗證 AI 傳回來的 JSON 是否合法。
const COMMAND_SCHEMA: Dictionary = {
	"add_cash": {
		"description": "增加玩家現金",
		"params": {"target": "Enum: ['self', 'all', 'others']", "amount": "Integer: 100~5000"}
	},
	"deduct_cash": {
		"description": "扣除玩家現金",
		"params": {"target": "Enum: ['self', 'all', 'others']", "amount": "Integer: 100~5000"}
	},
	"add_points": {
		"description": "增加玩家點數",
		"params": {"target": "Enum: ['self', 'all', 'others']", "amount": "Integer: 10~500"}
	},
	"deduct_points": {
		"description": "扣除玩家點數",
		"params": {"target": "Enum: ['self', 'all', 'others']", "amount": "Integer: 10~500"}
	},
	"add_item": {
		"description": "給予玩家特定道具",
		"params": {"target": "Enum: ['self', 'all', 'others']", "item_id": "String: 必須是 ALLOWED_ITEMS 之一"}
	},
	"remove_item": {
		"description": "沒收玩家特定道具 (若無該道具則無效)",
		"params": {"target": "Enum: ['self', 'all', 'others']", "item_id": "String: 必須是 ALLOWED_ITEMS 之一"}
	},
	"transfer_cash": {
		"description": "將資金從 target 轉移給觸發者 (self)",
		"params": {"target": "Enum: ['others']", "amount": "Integer: 100~5000"}
	}
}

# 目前遊戲內所有合法的道具 ID 清單 (對應 src/scripts/models/items/*.tres)
const ALLOWED_ITEMS: Array[String] = [
	"item_remote_dice",
	"item_roadblock",
	"item_turtle",
	"item_missile",
	"item_angel",
	"item_card_6"
]

## 動態產生給 AI 的 JSON Schema Prompt
## 讓 AI 知道它可以使用哪些積木來組合命運結果
func get_schema_prompt() -> String:
	var prompt: String = "【允許的指令清單 (Command List)】\n"
	prompt += "你只能使用以下指令組合 'effects' 陣列 (最多 2 個效果)：\n\n"

	for cmd in COMMAND_SCHEMA:
		var info = COMMAND_SCHEMA[cmd]
		prompt += "- 指令 `%s`: %s\n" % [cmd, info["description"]]
		prompt += "  參數: %s\n" % JSON.stringify(info["params"])

	prompt += "\n【允許的道具 ID (ALLOWED_ITEMS)】\n"
	prompt += JSON.stringify(ALLOWED_ITEMS) + "\n"

	return prompt

## 將效果字典轉為人類可讀的字串 (用於 UI 顯示)
func get_effect_description(effect: Dictionary) -> String:
	if not effect.has("cmd"):
		return ""
		
	var cmd = effect.get("cmd", "")
	# 強制轉型為 int，防止 AI 回傳 JSON 時將數字寫成字串 ("500" 而非 500)
	var amount: int = int(effect.get("amount", 0))
	var item_id = effect.get("item_id", "")
	var target = effect.get("target", "self")
	
	var target_name = "你"
	if target == "all": target_name = "所有人"
	elif target == "others": target_name = "其他人"
	
	match cmd:
		"add_cash": return "💰 %s獲得 $%d" % [target_name, amount]
		"deduct_cash": return "💸 %s失去 $%d" % [target_name, amount]
		"add_points": return "⭐ %s獲得 %d 點數" % [target_name, amount]
		"deduct_points": return "📉 %s失去 %d 點數" % [target_name, amount]
		"add_item": 
			var item_name = item_id.replace("item_", "").capitalize()
			return "🎁 %s獲得道具 [%s]" % [target_name, item_name]
		"remove_item":
			var item_name = item_id.replace("item_", "").capitalize()
			return "🔥 %s被沒收道具 [%s]" % [target_name, item_name]
		"transfer_cash": return "😈 從其他人身上偷取 $%d" % amount
		_: return "神秘的效果發生了"

# ==============================================================================

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
	# amount 改為可選 (例如 remote_dice 不需要 amount)，強制轉型防止 AI 回傳字串
	var amount: float = float(cmd_data.get("amount", 0.0)) 
	var item_id: String = cmd_data.get("item_id", "")

	# 安全驗證：阻擋 AI 產生未知的指令
	if not COMMAND_SCHEMA.has(cmd) and not cmd in ["place_roadblock", "set_dice", "remote_dice"]:
		DebugLogger.log_msg("[WARNING] EventProcessor 攔截到未知指令: " + cmd)
		return

	# 1. 決定目標對象 (Array[PlayerData])
	var target_players: Array[PlayerData] = _resolve_player_targets(target_str, trigger_player)

	# 2. 針對每一個受影響的玩家，執行動作
	for p in target_players:
		match cmd:
			"add_cash":
				var final_amount = clamp(int(amount), 1, 10000) # 防止破壞平衡
				p.add_cash(final_amount)
				DebugLogger.log_msg("事件效果：[%s] 獲得 $%d" % [p.name, final_amount], true)
			"deduct_cash":
				var final_amount = clamp(int(amount), 1, 10000)
				p.deduct_cash(final_amount, true) # 事件扣款皆為強制
				DebugLogger.log_msg("事件效果：[%s] 失去 $%d" % [p.name, final_amount], true)
			"add_points":
				var final_amount = clamp(int(amount), 1, 1000)
				p._points += final_amount
				DebugLogger.log_msg("事件效果：[%s] 獲得 %d 點點數" % [p.name, final_amount], true)
			"deduct_points":
				var final_amount = clamp(int(amount), 1, 1000)
				p._points = max(0, p._points - final_amount) # 點數不為負
				DebugLogger.log_msg("事件效果：[%s] 失去 %d 點點數！" % [p.name, final_amount], true)
			"transfer_cash":
				# 從目標扣錢，加給觸發者
				var final_amount = clamp(int(amount), 1, 10000)
				var actual_deducted = min(p._cash + p._deposit, final_amount) # 最多扣到破產
				p.deduct_cash(actual_deducted, true)
				trigger_player.add_cash(actual_deducted)
				DebugLogger.log_msg("事件效果：[%s] 的 $%d 資金被轉移給了 [%s]" % [p.name, actual_deducted, trigger_player.name], true)
			"place_roadblock":
				DebugLogger.log_msg("事件效果：[%s] 放置了路障！(尚未實作地圖障礙物系統)" % p.name, true)
			"add_item":
				if item_id in ALLOWED_ITEMS:
					# 使用 ResourceManager 動態載入
					var res_path = "res://scripts/models/items/" + item_id + ".tres"
					var item_res = load(res_path) as ItemData
					if item_res:
						p._items.append(item_res)
						DebugLogger.log_msg("事件效果：[%s] 獲得了道具 [%s]" % [p.name, item_res.name], true)
					else:
						DebugLogger.log_msg("[ERROR] 無法載入道具資源: " + res_path)
				else:
					DebugLogger.log_msg("[ERROR] add_item 參數不合法或缺少 item_id！(收到: %s)" % item_id)
			"remove_item":
				if item_id in ALLOWED_ITEMS:
					# 尋找玩家身上有沒有這個道具
					var found_index = -1
					for i in range(p._items.size()):
						if p._items[i].id == item_id: # 假設 ItemData 有 id 屬性，或用 resource_path 判斷
							found_index = i
							break

					if found_index != -1:
						var removed_name = p._items[found_index].name
						p._items.remove_at(found_index)
						DebugLogger.log_msg("事件效果：[%s] 的道具 [%s] 被沒收了！" % [p.name, removed_name], true)
					else:
						DebugLogger.log_msg("事件效果：命運之神想沒收 [%s] 的 [%s]，但他根本沒有這個道具！" % [p.name, item_id], true)
				else:
					DebugLogger.log_msg("[ERROR] remove_item 參數不合法或缺少 item_id！")
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
