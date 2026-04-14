class_name HumanBrain extends PlayerBrain

# ---------------------------------------------------------
# HumanBrain: 負責呼叫 UI 並等待真人點擊
# ---------------------------------------------------------

func decide_buy_land(land: LandCellData, player: PlayerData) -> bool:
	var main = Engine.get_main_loop().current_scene
	if main and main.has_method("show_dialog"):
		var msg = "踩到無主空地！\n名稱：[%s]\n售價：$%d\n您目前的現金：$%d\n是否要購買？" % [land.name, land.price, player._cash]
		# await UI 視窗的結果並回傳
		var result = await main.show_dialog("購買土地", msg, true, "購買 ($%d)" % land.price, "放棄")
		return result
		
	return false

func decide_upgrade_land(land: LandCellData, upgrade_cost: int, player: PlayerData) -> bool:
	var main = Engine.get_main_loop().current_scene
	if main and main.has_method("show_dialog"):
		var msg = "歡迎回到自己的地產！\n名稱：[%s]\n目前等級：%d\n\n花費 $%d 升級房屋可以大幅提升過路費。\n是否要升級？" % [land.name, land.level, upgrade_cost]
		var result = await main.show_dialog("升級地產", msg, true, "升級 ($%d)" % upgrade_cost, "不需要")
		return result
		
	return false
