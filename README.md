# Project Title: biu

Welcome to the development repository! This project is a high-octane action game built in **[Godot 4.5.1 (Mono/C# Edition)](https://godotengine.org/download)**. The core experience revolves around a "destruction-first" philosophy, where players use explosive forces to both dismantle the environment and navigate through it.

---

## 🚀 Core Mechanic: Explosive Navigation & Destruction

In this game, explosions aren't just for combat—they are your primary tool for movement and puzzle-solving.

* **Explosion:** Use your bomb to open your path to the next level! 
* **Navigation:** Master the art of "Explosive Dashing." By timing your movements with blasts, you can launch yourself across massive gaps or push multiple blocks. 

---

## 🛠 Getting Started

### Prerequisites

* **[Godot Engine 4.5.1 (.NET/Mono version)](https://godotengine.org/download):** Ensure you have the C# support installed.
* **[.NET SDK](https://dotnet.microsoft.com/download):** (Version 8.0 or newer recommended) to compile the C# scripts.

### How to Fork and Clone

1. **Fork** this repository by clicking the "Fork" button at the top right of this page.
2. **Clone** your fork to your local machine:
```bash
git clone https://github.com/YOUR_USERNAME/biu.git

```
> This url can be found at your forked project page.

> [!WARNING]
> Make sure the url is not ```WMsans/biu.git```, but your own username. 



### Opening the Project

1. Launch **Godot 4.5.1 (Mono)**.
2. In the Project Manager, click **Import**.
3. Browse to the folder where you cloned the repo and select the `project.godot` file.
4. Once the editor opens, click the **Build** button (hammer icon) in the top-right corner to compile the C# solution for the first time.

---

## 🎨 How to Contribute

We welcome contributions in both code and art!

### Contributing Art (How to Import PNGs)

To add new textures or sprites to the game:

1. Place your `.png` file into the `res::/textures/` directory within the project folder.
2. Switch back to the **Godot Editor**. It will automatically detect the new file and begin importing it.
3. **Configuration:** Select the image in the **FileSystem** dock.
4. Go to the **Import** tab (next to the Scene tab).
* For pixel art, ensure **Compress > Mode** is set to `Lossless` and **Filter** is set to `Nearest`.
* Click **Reimport** to apply changes.



### Contributing Code

1. [Fork this project](https://github.com/WMsans/biu/fork). 
2. [Optional] Create a new branch for your feature: `git checkout -b feature/your-feature-name`.
3. Write your logic in C#, GDScript or any language extension you like. Follow the existing naming conventions (PascalCase for methods and public variables).
4. Ensure the project builds successfully before committing.

---

## 🔃 Submitting a Pull Request (PR)

Once you've made your changes and pushed them to your fork:

1. Navigate to the original repository on GitHub.
2. You should see a yellow bar saying **"Compare & pull request"**. Click it.
3. Describe your changes:
* What does this PR add or fix?
* Are there any breaking changes?
* Attaching images explaining the changes are preferred. 


4. Click **Create pull request**.

A maintainer will review your code/assets shortly!
