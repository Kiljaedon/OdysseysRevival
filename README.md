# GoldenSunMMO Development Project

Welcome to the GoldenSunMMO development project. This is the **main development environment** where all source code, assets, and tools live.

## Critical Information

**This folder contains ALL source code and assets for GoldenSunMMO development.**

For clarity on the project structure and where to work, read: [PROJECT_STRUCTURE.md](../Documents/development/PROJECT_STRUCTURE.md)

## Quick Start

1. Open this project in Godot 4.5+
2. All source code is in `source/` directory
3. All assets are in `assets/` directory
4. All documentation is in `../Documents/` directory
5. Development tools are in `tools/` directory

## Project Structure

```
GoldenSunMMO-Dev/
├── source/                 # Source code
│   ├── client/            # Client game logic
│   ├── server/            # Server game logic
│   └── common/            # Shared code
│
├── assets/                # Game content
│   ├── sprites/           # Sprite sheets
│   ├── character_sprites/ # Individual sprites
│   ├── maps/              # TMX map files
│   ├── characters/        # Character definitions
│   └── effects/           # Visual effects
│
├── tools/                 # Development tools
│   ├── odyssey_sprite_maker.*
│   └── (other tools)
│
├── tiled_projects/       # Tiled map editor projects
├── project.godot         # Godot configuration
└── export_presets.cfg    # Build configurations
```

## Important Notes for Claude/Gemini Code Sessions

### Where to Work

Always work in this folder (`GoldenSunMMO-Dev/`). This is the single source of truth.

### Key Directories

- **Source code:** `source/` - Edit game logic here
- **Assets:** `assets/` - All sprites, maps, characters, effects
- **Tools:** `tools/` - Development utilities
- **Documentation:** `../Documents/` - Read guides and notes here

### What is Production/?

The `Production/` folder at the root level (`C:\Users\dougd\GoldenSunMMO\Production\`) is **build output only**. It is:
- Created by export presets
- Not a development project
- Never edited directly
- Can be deleted and recreated anytime

Do NOT work in Production/. It is auto-generated from this project.

## Documentation

Essential reading before starting work:

1. **PROJECT_STRUCTURE.md** - Explains folder layout and workflow (in `../Documents/development/`)
2. **CLAUDE.md** - Development notes and completed systems (in `../Documents/meta/`)
3. **DEPLOYMENT_GUIDE.md** - How to build and deploy (in `../Documents/setup/`)

All documentation is in: `../Documents/`

## Development Tools Included

- **Sprite Maker** - Create and configure character animations
- **Map Editor Integration** - Works with Tiled (external tool)
- **Character Creator** - Build character definitions

## Getting Started

1. Open this project in Godot
2. Read `../Documents/development/PROJECT_STRUCTURE.md`
3. Read `../Documents/meta/CLAUDE.md` for system overview
4. Start working in the `source/` directory

## Building

To create builds/exports:
1. Use Godot's export presets from this project
2. Exports go to `../Production/` folder
3. Then you can distribute binaries from Production/

## Need Help?

- **Project structure:** See `../Documents/development/PROJECT_STRUCTURE.md`
- **System architecture:** See `../Documents/architecture/`
- **Development notes:** See `../Documents/meta/CLAUDE.md`
- **All documentation:** See `../Documents/` directory

---

**This is the main development environment. All work happens here.**