class_name LLMAIBrain extends PlayerBrain

# ---------------------------------------------------------
# LLMAIBrain: 連線真 AI (LLM)，目前以 Log 代替
# ---------------------------------------------------------

func decide_buy_land(land: LandCellData, player: PlayerData) -> bool:
	DebugLogger.log_msg("🤖 [LLM AI] 正在思考要不要買地... (⚠️ 未來將在這裡接上大語言模型 API)")
	# 暫時等同假 AI，無腦買
	return true

func decide_upgrade_land(land: LandCellData, upgrade_cost: int, player: PlayerData) -> bool:
	DebugLogger.log_msg("🤖 [LLM AI] 正在思考要不要升級... (⚠️ 未來將在這裡接上大語言模型 API)")
	# 暫時等同假 AI，無腦升級
	return true
