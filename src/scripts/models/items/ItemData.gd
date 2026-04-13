class_name ItemData
extends Resource

## 道具種類定義
enum ItemType {
	ACTIVE,  ## 主動使用 (例如：遙控骰子、路障)
	PASSIVE, ## 被動觸發 (例如：免死金牌、烏龜卡)
}

@export var id: String = ""
@export var name: String = "未命名道具"
@export_multiline var description: String = "這是一個神祕的道具。"
@export var icon: Texture2D
@export var type: ItemType = ItemType.ACTIVE
@export var price: int = 100

## 道具效果指令列表 (與 EventProcessor 共用格式)
## 範例: [{"cmd": "set_dice", "target": "self", "amount": 6}]
@export var effects: Array[Dictionary] = []
