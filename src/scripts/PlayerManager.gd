
extends Node

# ---------------------------------------------------------
# PlayerManager: 玩家管理系統 (AutoLoad)
# 負責管理所有參與遊戲的玩家資料 (PlayerData)，並控制回合輪替
# ---------------------------------------------------------

var players: Array[PlayerData] = []
var current_turn_index: int = 0 # 陣列索引 (0, 1, 2...)

func _ready() -> void:
	SettingsManager.settings_changed.connect(_on_settings_changed)
	# (暫時在此初始化三個測試玩家。未來此步驟應該由大廳/開局介面呼叫)
	_setup_test_players()

# 測試用：初始化本機玩家與對手
func _setup_test_players() -> void:
	players.clear()
	current_turn_index = 0

	# 玩家 1 (本機控制) - 火球鼠
	var p1 = PlayerData.new(1, "玩家 1 (你)", "155_Cyndaquil.png", false)
	players.append(p1)

	# 玩家 2 (本機控制) - 菊石獸
	var p2 = PlayerData.new(2, "玩家 2", "138_Omanyte.png", false)
	players.append(p2)

	# 電腦 B - 巨金怪
	var p3 = PlayerData.new(3, "電腦 B", "376_Metagross.png", true)
	players.append(p3)

# 取得所有玩家
func get_all_players() -> Array[PlayerData]:
	return players

# 透過玩家 ID 尋找對應的 PlayerData
func get_player(id: int) -> PlayerData:
	for p in players:
		if p.id == id:
			return p
	return null

# 取得目前輪到誰回合的 PlayerData
func get_current_turn_player() -> PlayerData:
	if players.is_empty(): return null
	return players[current_turn_index]

# 回合輪替，回傳下一個玩家
func advance_turn() -> PlayerData:
	if players.is_empty(): return null
	current_turn_index = (current_turn_index + 1) % players.size()
	return get_current_turn_player()

# 當全域設定改變時，檢查是否需要動態換腦
func _on_settings_changed() -> void:
	var ai_enabled = SettingsManager.current.ai_enabled
	
	for p in players:
		if p.is_ai:
			if ai_enabled:
				# 玩家在設定裡開啟了 AI
				# 理想狀態下，應該在這裡先 ping 網路，成功才換。
				# 目前我們先寫死：如果是玩家 3，且現在的腦不是 LLM，就幫他換回 LLM
				if p.id == 3 and not p.brain is LLMAIBrain:
					p.brain = LLMAIBrain.new()
					DebugLogger.log_msg("系統已將玩家 [%s] 的大腦升級為連網 LLM。" % p.name, true)
			else:
				# 玩家在設定裡關閉了 AI
				# 發現真腦，強制降級為假腦
				if p.brain is LLMAIBrain:
					p.brain = LocalAIBrain.new()
					DebugLogger.log_msg("系統已將玩家 [%s] 的大腦降級為本地假 AI。" % p.name, true)
