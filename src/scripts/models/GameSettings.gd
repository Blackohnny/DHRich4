class_name GameSettings extends Resource

@export_group("Rules", "rule_")
## 允許回頭走 (走回上一個剛離開的節點)
@export var rule_allow_backtracking: bool = false

enum BranchSelectionMode { MANUAL, RANDOM }
## 岔路選擇模式 (手動選方向 或 系統隨機)
@export var rule_branch_selection_mode: BranchSelectionMode = BranchSelectionMode.MANUAL

@export_group("Display", "display_")
## 全螢幕模式
@export var display_fullscreen: bool = false

enum MoveSpeed { NORMAL, FAST, INSTANT }
## 棋子移動速度 (正常/快速/瞬間)
@export var display_move_speed: MoveSpeed = MoveSpeed.NORMAL

@export_group("Audio", "audio_")
## 主音量 (0.0 ~ 1.0)
@export var audio_master_volume: float = 1.0

@export_group("AI", "ai_")
## 啟用 AI 命運之神對話
@export var ai_enabled: bool = true

@export_group("BlackBox", "blackbox_")
enum BlackBoxMode { OFF, LEVEL_1, LEVEL_2, LEVEL_3 }
## 黑箱系統遮蔽層級
@export var blackbox_mode: BlackBoxMode = BlackBoxMode.OFF
