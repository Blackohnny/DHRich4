@tool
extends Node2D
class_name MapPreviewer

# --- 專門用於編輯器內預覽地圖連線的工具 ---
# 遊戲正式執行時，此節點可選擇隱藏或保留，不影響主邏輯。

@export var board_data: BoardData:
	set(value):
		board_data = value
		queue_redraw() # 當資源改變時，重新繪製

@export var preview_enabled: bool = true:
	set(value):
		preview_enabled = value
		queue_redraw()

# 繪圖設定
var cell_size: Vector2 = Vector2(60, 60)
var line_color: Color = Color(0.2, 0.8, 1.0, 0.6) # 淺藍色連線
var arrow_color: Color = Color(1.0, 0.2, 0.2, 0.8) # 紅色箭頭

# 當節點進入場景樹時
func _ready() -> void:
	# 如果不是在編輯器中執行，可以選擇自動隱藏預覽 (根據需求可註解掉)
	if not Engine.is_editor_hint():
		hide()
		set_process(false)

# 監聽資源變化 (當你在 Inspector 修改 .tres 時即時更新)
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and preview_enabled and board_data:
		# 雖然每幀呼叫有點耗效能，但在編輯器預覽階段是可接受的
		# 為了確保拖曳座標時能即時看到線條變化
		queue_redraw()

# 使用 Godot 底層的 CanvasItem 繪圖 API
func _draw() -> void:
	if not preview_enabled or not board_data or board_data.cells.is_empty():
		return
		
	# 預載字型 (用內建預設字型)
	var font := ThemeDB.fallback_font
	var font_size := 12
		
	# 第一階段：畫連線 (先畫線，才不會蓋住格子)
	for i in range(board_data.cells.size()):
		var cell: CellData = board_data.cells[i]
		if cell == null: continue
			
		var start_pos: Vector2 = cell.position
		
		for next_idx in cell.next_nodes:
			if next_idx >= 0 and next_idx < board_data.cells.size():
				var next_cell: CellData = board_data.cells[next_idx]
				if next_cell == null: continue
				
				var end_pos: Vector2 = next_cell.position
				
				# 畫主連線
				draw_line(start_pos, end_pos, line_color, 2.0, true)
				
				# 計算箭頭位置 (畫在線段的 70% 處，比較容易看清方向)
				var dir: Vector2 = (end_pos - start_pos).normalized()
				var arrow_pos: Vector2 = start_pos + (end_pos - start_pos) * 0.7
				
				# 畫一個簡單的三角形箭頭
				var arrow_p1: Vector2 = arrow_pos + dir * 10
				var arrow_p2: Vector2 = arrow_pos + dir.rotated(PI * 0.8) * 8
				var arrow_p3: Vector2 = arrow_pos + dir.rotated(-PI * 0.8) * 8
				draw_colored_polygon([arrow_p1, arrow_p2, arrow_p3], arrow_color)

	# 第二階段：畫方塊與文字
	for i in range(board_data.cells.size()):
		var cell: CellData = board_data.cells[i]
		if cell == null: continue
			
		var pos: Vector2 = cell.position
		var rect := Rect2(pos - cell_size / 2, cell_size)
		
		# 根據類型決定顏色
		var bg_color: Color = Color(0.3, 0.3, 0.3, 0.5) # 預設半透明灰
		if cell.type == CellData.CellType.START:
			bg_color = Color(0.8, 0.8, 0.2, 0.5) # 起點：半透明黃
		elif cell.type == CellData.CellType.EVENT:
			bg_color = Color(0.8, 0.2, 0.8, 0.5) # 事件：半透明紫
			
		# 畫格子背景與外框
		draw_rect(rect, bg_color, true)
		draw_rect(rect, Color.WHITE, false, 1.0)
		
		# 畫 Index 標籤 (置中偏上)
		var index_str: String = str(i)
		var text_size: Vector2 = font.get_string_size(index_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, pos - Vector2(text_size.x/2, 5), index_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
		# 畫名稱 (置中偏下)
		var name_str: String = cell.name
		var name_size: Vector2 = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2)
		draw_string(font, pos + Vector2(-name_size.x/2, 15), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color.LIGHT_GRAY)
