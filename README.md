# DHRich4 - AI-Driven Monopoly 🎲

*(For Traditional Chinese, see [README.zh-TW.md](README.zh-TW.md))*

This is an AI-driven, single-player Monopoly-style game side project that integrates real-world data with Large Language Models (LLM). Built with **Godot Engine 4.6 (GDScript)**, it focuses on minimalist visuals, dynamic algorithms, and rich AI interactions.

## 🌟 Core Features (Planned)

*   **Minimalist Visuals**: Focus on game logic, APIs, and algorithms without requiring complex art assets.
*   **Dynamic Market**: Item and real estate prices fluctuate based on randomization or the player's supply/demand behaviors.
*   **Real-World Integration**: Connects to real-world news and stock market APIs to dynamically alter in-game stats (e.g., a surge in tech stocks increases tolls in specific zones).
*   **AI God of Fate**: When landing on a Chance/Fate tile, players interact directly with an AI (Gemini) through a chat interface. The AI determines rewards or punishments based on the player's attitude.

## 🛠️ Tech Stack & Architecture

*   **Game Engine**: [Godot Engine 4.6.1](https://godotengine.org/) (Standard version, GDScript)
*   **Language**: GDScript (with strict static typing conventions)
*   **Architecture**: MVC (Model-View-Controller) and robust State Machine implementations.
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