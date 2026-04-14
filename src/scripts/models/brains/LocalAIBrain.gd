class_name LocalAIBrain extends PlayerBrain

# ---------------------------------------------------------
# LocalAIBrain: 本地假 AI，無腦操作
# ---------------------------------------------------------

func decide_buy_land(land: LandCellData, player: PlayerData) -> bool:
	# 假 AI：能買就無腦買，不在乎破產
	return true

func decide_upgrade_land(land: LandCellData, upgrade_cost: int, player: PlayerData) -> bool:
	# 假 AI：能升級就無腦升級
	return true
