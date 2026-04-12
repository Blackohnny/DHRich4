extends Node

## 遊戲設定全域管理器 (Singleton)
## 負責管理與保存當前遊戲的設定狀態，確保所有系統讀取到一致的規則 (Single Source of Truth)。

var current: GameSettings = GameSettings.new()

func _ready() -> void:
	# 未來可在此實作從硬碟讀取使用者設定檔 (如 user://settings.json) 的邏輯
	pass
