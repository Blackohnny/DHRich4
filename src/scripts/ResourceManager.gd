extends Node

# 單例模式 (Singleton/Autoload)：負責統一管理資源載入
# 在 Godot 中，我們會將這個腳本設定為 AutoLoad，讓全域都可以呼叫它

const PRIVATE_DIR: String = "res://assets/private_images/"
const PUBLIC_DIR: String  = "res://assets/public_images/"

# 動態載入圖片，具備 Fallback 機制
func load_image_with_fallback(file_name: String) -> Texture2D:
	var private_path: String = PRIVATE_DIR + file_name
	var public_path: String  = PUBLIC_DIR + file_name
	
	# 1. 優先檢查私有資料夾 (高畫質/版權圖)
	if ResourceLoader.exists(private_path):
		# print("Loaded private image: ", file_name)
		return load(private_path) as Texture2D
		
	# 2. 退而求其次檢查公開資料夾 (開源/安全圖)
	elif ResourceLoader.exists(public_path):
		# print("Loaded public image: ", file_name)
		return load(public_path) as Texture2D
		
	# 3. 真的找不到，回傳預設的 Godot 圖示避免程式崩潰
	else:
		push_warning("Resource missing in both private and public folders: " + file_name)
		return preload("res://assets/icon.svg")
