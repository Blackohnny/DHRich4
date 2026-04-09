extends Resource
class_name BoardData

# =====================================  =========================================
# 地圖全域環境設定 (Map Environment Settings)
# 這些變數定義了這張地圖的「世界觀」與「經濟體系」。
# ==============================================================================
@export_category("Map Environment")

@export_group("Economy & Prices")
## 物價倍率：影響所有土地購買價與過路費 (例如日本地圖可設為 1.5)
@export var price_multiplier: float = 1.0 
## 起點薪水倍率：可獨立調整薪水的通膨程度
@export var salary_multiplier: float = 1.0

@export_group("Shop Inventory Control")
## 商店特產 (白名單)：這張地圖專屬、一定會賣的特殊道具 ID 列表
@export var shop_specialties: Array[String] = []
## 違禁品 (黑名單)：這張地圖絕對不允許販售的常規道具 ID 列表
@export var shop_banned_items: Array[String] = []

@export_group("Event Probabilities")
## 壞命運機率權重：數值越高，抽到負面事件的機率越大 (預設 1.0)
@export var bad_destiny_weight: float = 1.0

# ==============================================================================
# 地圖拓樸結構 (Topology)
# 定義格子的實際排列與屬性。
# ==============================================================================
@export_category("Topology")
@export var cells: Array[CellData] = []
