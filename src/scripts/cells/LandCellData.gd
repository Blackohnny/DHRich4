extends CellData
class_name LandCellData

## 地段所屬行政區 (區域連鎖 monopoly 判定用)
## 相同 district_id 的土地如果都被同一人買下，過路費會翻倍
@export var district_id: int = 0 

## 土地基礎售價
@export var price: int = 1000

## 基礎過路費 (空地狀態)
@export var base_toll: int = 200

# ---------------------------------------------------------
# 執行期的動態狀態 (Run-time State)
# (不加 @export，因為每次開局/讀檔都會重置或覆寫)
# ---------------------------------------------------------
var owner_id: int = -1 # -1: 無主, >0: 玩家 ID
var level: int = 0     # 0: 空地, 1: 房子, 2: 飯店... 最大 5 級
var is_monopoly: bool = false # 是否達成區域連鎖 (動態計算)

func _init(_name: String = "未命名空地", _pos: Vector2 = Vector2.ZERO, _price: int = 1000, _base_toll: int = 200, _district: int = 0):
	super(_name, _pos)
	self.price = _price
	self.base_toll = _base_toll
	self.district_id = _district
	self.owner_id = -1
	self.level = 0
	self.is_monopoly = false

# ---------------------------------------------------------
# 商業邏輯 API
# ---------------------------------------------------------

## 計算升級到下一級需要多少錢 (預設為地價的 50%)
func get_upgrade_cost() -> int:
	if level >= 5: return 0 # 已達滿級
	return int(price * 0.5)

## 計算目前的過路費 (根據等級與是否連鎖)
func get_current_toll() -> int:
	if owner_id == -1: return 0
	
	# 基礎過路費 + (每升一級增加 50% 的過路費)
	var toll: float = base_toll * (1.0 + (level * 0.5))
	
	# 如果達成區域連鎖，過路費翻倍
	if is_monopoly:
		toll *= 2.0
		
	return int(toll)

## 計算這塊地的總價值 (買價 + 所有升級花費)
func get_total_value() -> int:
	if owner_id == -1: return price
	return price + (level * get_upgrade_cost())
