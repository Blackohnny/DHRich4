class_name PlayerBrain extends RefCounted

# ---------------------------------------------------------
# PlayerBrain: 玩家思考大腦基底 (Strategy Pattern)
# 無狀態介面，所有的記憶與狀態必須儲存在 PlayerData 內
# ---------------------------------------------------------

## 決定是否購買無主地
func decide_buy_land(land: LandCellData, player: PlayerData) -> bool:
	return false

## 決定是否升級自己的地產
func decide_upgrade_land(land: LandCellData, upgrade_cost: int, player: PlayerData) -> bool:
	return false

## 未來可擴充：決定是否使用道具、決定岔路方向等
