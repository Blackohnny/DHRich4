# DHRich4 - AI-Driven Monopoly 🎲

*(For Traditional Chinese, see [README.zh-TW.md](README.zh-TW.md))*

This is an AI-driven, single-player Monopoly-style game side project that integrates real-world data with Large Language Models (LLM). Built with **Godot Engine 4.6 (GDScript)**, it focuses on minimalist visuals, dynamic algorithms, and rich AI interactions.

## 🌟 Core Features (Planned)

*   **Minimalist Visuals**: Focus on game logic, APIs, and algorithms without requiring complex art assets.
*   **Editor Live Preview**: Custom `@tool` MapPreviewer allows real-time WYSIWYG editing of board `.tres` resources directly within the Godot Editor.
*   **Dynamic Market**: Item and real estate prices fluctuate based on randomization or the player's supply/demand behaviors.
*   **Real-World Integration**: Connects to real-world news and stock market APIs to dynamically alter in-game stats (e.g., a surge in tech stocks increases tolls in specific zones).
*   **AI God of Fate**: When landing on a Chance/Fate tile, players interact directly with an AI (Gemini) through a chat interface. The AI determines rewards or punishments based on the player's attitude.

## 🛠️ Tech Stack & Architecture

*   **Game Engine**: [Godot Engine 4.6.1](https://godotengine.org/) (Standard version, GDScript)
*   **Language**: GDScript (with strict static typing conventions)
*   **Architecture (MVC & Component Composition)**:
    *   **Model (Data Layer)**:
        *   `PlayerManager.gd` (AutoLoad): Manages the global array of active players.
        *   `PlayerData.gd`: Encapsulates individual player assets, providing a DTO via `get_public_view()` to enforce True Fog of War and prevent AI cheating.
        *   `BoardData.tres` / `CellData.gd`: Stores map topology, cell types, and global economic settings.
    *   **View (Presentation Layer)**:
        *   `Main.tscn`: The host environment scene containing the camera, board background, and primary UI canvas.
        *   `PlayerEntity.tscn`: An independent pawn prefab, dynamically instantiated with assigned avatars.
        *   `StatusUI.tscn`: A modal window prefab utilizing Tree and Grid containers for player status, properties, and items.
    *   **Controller (Logic Layer)**:
        *   `Main.gd`: Houses the central State Machine, managing turn cycles, dice roll scheduling, and acting as the Event Dispatcher for cell landings.
        *   `UIManager.gd`: Handles primary screen clicks and dynamically instantiates UI popups like `StatusUI`.
        *   `Player.gd`: Attached to `PlayerEntity.tscn`, focused solely on position tweening and Z-Index highlighting.
*   **Resource Management (Data-Driven)**: 
    *   Custom dynamic loading and Fallback mechanisms strictly isolate private (copyrighted) assets from open-source assets.
    *   **Data-Driven Board System**: Hardcoded generation is abandoned in favor of Godot Custom Resources (`.tres`). Maps are implemented as Directed Graphs to support figure-8 layouts and branching paths.

## 🚀 How to Run Locally

### 1. Install Godot Engine
Download **Godot Engine 4.6.x (Standard version)** from the official website. The .NET/C# version is not required.

### 2. Clone the Repository
```bash
git clone https://github.com/Blackohnny/DHRich4.git
cd DHRich4
```

### 3. Import to Godot
1. Open the Godot Editor.
2. Click **"Import"**.
3. Select the `project.godot` file located inside the `src/` directory of this repository.
4. Click **"Import & Edit"**.
5. Press **F5** (or the Play button at the top right) to start the game!

## 🤖 How to Setup AI Features

One of the core features of this game is the "AI God of Destiny". To protect your privacy and API billing, this project does not include real API keys. If you want to test this feature locally, please follow these steps:

1. Navigate to the `src/` directory.
2. Find the `ai_config.example.json` file.
3. Make a copy of this file and rename it to `ai_config.json`.
4. Open `ai_config.json` and fill in your OpenAI-compatible Endpoint and your real API Key.
5. Start the game. When you land on a "Chance" or "Destiny" cell, you will experience real-time interactive events driven by AI!

*(Note: If you do not configure this file, or if the parameters are invalid, the game will gracefully degrade and switch to a traditional random card-drawing mode instead of crashing.)*

## 🗺️ Editor Map Live Preview & WYSIWYG Editing

This project utilizes Godot's `@tool` system to power a custom `MapPreviewer`, making level design incredibly intuitive without touching a single line of code.

### How to Live Edit Maps:
1. Open `src/scenes/Main.tscn` in the Godot Editor. You will see a blueprint of blocks and arrows connected in the center of the viewport.
2. In the **FileSystem** dock (bottom left), double-click to open `src/data/map_default.tres`.
3. In the **Inspector** dock (right), expand the `Cells` array.
4. Click on any grid element (`CellData`), and try dragging its `Position` values (X or Y axes).
5. **Live Update**: As you drag the coordinates, the boxes and arrows in the Main viewport will move **in real-time**!

### How to Preview Different Maps:
You can use the `MapPreviewer` to visualize any board data file:
1. Click the `MapPreviewer` node in the Scene Tree of `Main.tscn`.
2. Locate the **Board Data** property in the Inspector.
3. Drag and drop any other `.tres` map file from your FileSystem into this property, and the viewport will instantly switch to display the new layout.

---

## 🎨 Asset Management & Fallback System

To resolve the common conflict between using **custom/copyrighted images for personal enjoyment** and maintaining an **open-source repository**, this project implements a unique `ResourceManager` Fallback mechanism.

### Directory Structure & Loading Order
When the game runs, scripts dynamically load images in the following priority:

1.  🥇 `src/assets/private_images/` (Private / High-Res / Copyrighted images)
2.  🥈 `src/assets/public_images/` (Open-Source / Safe placeholders)
3.  🥉 `src/assets/icon.svg` (Godot default icon as the ultimate failsafe)

### How to Customize Your Game Visuals?

If you want to replace the default board cells or player icons with your favorite characters (e.g., official anime art), follow these steps:

1.  Prepare your image files (e.g., `Cyndaquil.png` or `Mew.png`).
2.  Place them inside the **`src/assets/private_images/`** directory.
3.  **Done!** Restart the game, and the engine will prioritize your high-quality images.

> **⚠️ Git Notice**
> The `.gitignore` file is strictly configured to **ignore all contents within the `private_images/` directory** (except for a `.placeholder` file to maintain the folder structure).
> Therefore, you can safely place any personal or copyrighted assets in this folder. They will **never** be pushed to GitHub, keeping the open-source repository clean and legal!

---
*For detailed development phases and planning, refer to [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)*