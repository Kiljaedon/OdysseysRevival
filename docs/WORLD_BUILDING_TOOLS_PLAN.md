# World Building Tools - Implementation Plan

## Overview

Two tools work together to build the game world:

1. **Sprite Maker (expanded)** → Create all NPC types with their data
2. **Map Linker (new)** → Connect maps and place spawns

Tiled remains the tile/terrain painting tool.

---

## Part 1: Sprite Maker Expansion

### Current State
- Creates player classes and enemy NPCs
- Has: sprites, animations, combat stats, AI archetype, loot tables
- Saves to: `characters/classes/` and `characters/npcs/`

### New NPC Role System

Add a **Role** selector that changes what properties are shown:

```
┌─────────────────────────────────────────────────┐
│  NPC Role: [Enemy ▼]                            │
│            ├─ Enemy (current behavior)          │
│            ├─ Vendor                            │
│            ├─ Quest Giver                       │
│            ├─ Trainer                           │
│            ├─ Innkeeper                         │
│            └─ Generic (dialog only)             │
└─────────────────────────────────────────────────┘
```

### Role-Specific Properties

#### Enemy (existing)
```json
{
  "role": "enemy",
  "combat_role": "Melee|Ranged|Caster|Support",
  "ai_archetype": "AGGRESSIVE|DEFENSIVE|SUPPORT|BOSS",
  "base_stats": { "str": 10, "dex": 10, ... },
  "loot_table": { "gold_reward": 10, "xp_reward": 50, "items": [] },
  "level_range": { "min": 1, "max": 5 }
}
```

#### Vendor (new)
```json
{
  "role": "vendor",
  "shop_type": "general|weapons|armor|potions|magic",
  "inventory": [
    { "item_id": "health_potion", "stock": 10, "price_multiplier": 1.0 },
    { "item_id": "iron_sword", "stock": 3, "price_multiplier": 1.2 }
  ],
  "buy_rate": 0.5,           // Pays 50% of item value when buying from player
  "restock_hours": 24,       // Real-time hours to restock
  "dialog": {
    "greeting": "Welcome to my shop!",
    "no_money": "Come back when you have more gold.",
    "thanks": "Pleasure doing business!"
  }
}
```

#### Quest Giver (new)
```json
{
  "role": "quest_giver",
  "quests": [
    {
      "quest_id": "kill_goblins",
      "required_flags": [],              // Flags player must have to see quest
      "blocked_flags": ["goblins_done"]  // Flags that hide quest
    },
    {
      "quest_id": "find_artifact",
      "required_flags": ["goblins_done"],
      "blocked_flags": []
    }
  ],
  "dialog": {
    "greeting": "Adventurer! I need your help.",
    "no_quests": "Thank you for all your help.",
    "busy": "Come back when you've finished what I asked."
  }
}
```

#### Trainer (new)
```json
{
  "role": "trainer",
  "trainer_type": "combat|magic|crafting",
  "teaches": [
    {
      "skill_id": "power_strike",
      "required_level": 5,
      "cost": 500,
      "required_skills": []
    },
    {
      "skill_id": "whirlwind",
      "required_level": 10,
      "cost": 2000,
      "required_skills": ["power_strike"]
    }
  ],
  "dialog": {
    "greeting": "Ready to learn the ways of the warrior?",
    "not_ready": "You're not experienced enough yet.",
    "no_money": "Training isn't free, friend."
  }
}
```

#### Innkeeper (new)
```json
{
  "role": "innkeeper",
  "services": {
    "rest": { "cost": 10, "heal_percent": 100 },
    "save_spawn": true,    // Can set respawn point here
    "storage": false       // Bank access?
  },
  "dialog": {
    "greeting": "Need a room for the night?",
    "rest": "Sleep well, traveler.",
    "no_money": "No gold, no bed. Sorry."
  }
}
```

#### Generic NPC (new)
```json
{
  "role": "generic",
  "dialog": {
    "lines": [
      "Nice weather today.",
      "Have you heard about the goblins?",
      "The king hasn't been seen in weeks..."
    ],
    "mode": "random|sequential"  // Pick random line or cycle through
  }
}
```

### UI Changes to Sprite Maker

#### Step 1: Add Role Dropdown
- Add `OptionButton` for role selection below the Class/NPC type toggle
- Default to "Enemy" for NPCs, hide for Classes

#### Step 2: Create Role-Specific Panels
Each role gets its own collapsible panel section:

```
┌─ Sprite Selection ──────────────────────────────┐
│  [Current sprite grid - unchanged]              │
└─────────────────────────────────────────────────┘

┌─ Basic Info ────────────────────────────────────┐
│  Name: [___________]  Role: [Vendor ▼]          │
└─────────────────────────────────────────────────┘

┌─ Vendor Settings ───────────────────────────────┐  ← Shows based on role
│  Shop Type: [General ▼]                         │
│  Buy Rate: [0.5]  Restock Hours: [24]           │
│                                                 │
│  ┌─ Inventory ─────────────────────────────┐    │
│  │ Item ID          Stock    Price Mult    │    │
│  │ [health_potion]  [10]     [1.0]    [X]  │    │
│  │ [iron_sword]     [3]      [1.2]    [X]  │    │
│  │ [+ Add Item]                            │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─ Dialog ────────────────────────────────┐    │
│  │ Greeting: [Welcome to my shop!_______]  │    │
│  │ No Money: [Come back when you have..._] │    │
│  │ Thanks:   [Pleasure doing business!___] │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

#### Step 3: Save Location
All NPCs save to `characters/npcs/` with the role in the JSON:
- `characters/npcs/Goblin.json` (role: enemy)
- `characters/npcs/ShopKeeper.json` (role: vendor)
- `characters/npcs/OldMan.json` (role: quest_giver)

### Implementation Steps

1. **Add role system to character_data structure**
   - Add `role` field
   - Create role-specific data templates

2. **Create UI panels for each role**
   - VendorPanel, QuestGiverPanel, TrainerPanel, etc.
   - Show/hide based on role selection

3. **Update save/load functions**
   - Save role-specific data
   - Load and populate correct UI based on role

4. **Add item/quest/skill pickers**
   - Item picker for vendor inventory (needs item database)
   - Quest picker for quest givers (needs quest database)
   - Skill picker for trainers (needs skill database)

### Dependencies (may need to create)

- `data/items.json` - Item definitions for vendors
- `data/quests.json` - Quest definitions for quest givers
- `data/skills.json` - Skill definitions for trainers

---

## Part 2: Map Linker Tool

### Purpose
Visual tool for connecting maps and placing NPC/player spawns.

### Features

#### Map Viewing
- Load and render TMX maps
- Pan/zoom navigation
- Show all layers (bottom, middle, foreground)

#### Warp Placement
- Click to place warp zone
- Set target map from dropdown (scans maps/ folder)
- Set target coordinates (click on target map preview)
- Visual arrows showing connections
- Double-click warp to navigate to target map

#### NPC Spawn Placement
- Click to place spawn point
- Select NPC from dropdown (scans characters/npcs/)
- Shows NPC preview sprite
- Set facing direction
- Set instance-specific overrides (optional):
  - Custom dialog for this instance
  - Specific quest subset
  - Patrol path (future)

#### Player Spawn
- One per map
- Click to place/move
- Set facing direction

### UI Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Back]                    MAP LINKER                               │
├──────────────┬────────────────────────────────────┬─────────────────┤
│              │                                    │                 │
│  MAPS        │         MAP PREVIEW                │   OBJECTS       │
│              │                                    │                 │
│  ○ overworld │    ┌──────────────────────┐        │   Warps:        │
│  ○ dungeon   │    │                      │        │   ├ W1 → cave   │
│  ○ cave      │    │   [Rendered map      │        │   └ W2 → town   │
│  ○ town      │    │    with markers]     │        │                 │
│  ○ shop_int  │    │                      │        │   Spawns:       │
│              │    │   W1 ●────────→      │        │   ├ Goblin x3   │
│              │    │                      │        │   ├ Shopkeeper  │
│              │    │        ◆ Player      │        │   └ QuestGuy    │
│              │    │                      │        │                 │
│ [+ New Map]  │    │   ■ Goblin           │        │   [+ Warp]      │
│ [Refresh]    │    │   ■ Shopkeeper       │        │   [+ Spawn]     │
│              │    └──────────────────────┘        │   [+ Player]    │
│              │                                    │                 │
│              │    [Place Warp] [Place Spawn]      │   PROPERTIES    │
│              │    [Zoom +] [Zoom -] [Save]        │   ───────────   │
│              │                                    │   Target: cave  │
│              │                                    │   X: 5  Y: 10   │
│              │                                    │   Trigger: touch│
└──────────────┴────────────────────────────────────┴─────────────────┘
```

### Workflow Examples

#### Linking Two Maps

1. Open Map Linker from Development Tools
2. Select "overworld" from map list
3. Click [Place Warp]
4. Click on map where cave entrance is
5. In Properties panel:
   - Target Map: select "cave" from dropdown
   - Target X/Y: click [Pick on Map] → shows cave map → click spawn point
6. Click [Save]
7. Select "cave" map
8. Repeat to create return warp back to overworld

#### Placing NPCs

1. Select map from list
2. Click [Place Spawn]
3. Click location on map
4. In Properties panel:
   - NPC: select "Goblin" from dropdown (shows sprite preview)
   - Facing: Down
   - Count: 3 (spawns 3 goblins in area)
5. Click [Save]

### Data Storage

Warps and spawns save directly to the TMX file as object layers:

```xml
<objectgroup name="Warps">
  <object id="1" name="Warp_1" x="160" y="320" width="32" height="32">
    <properties>
      <property name="type" value="warp"/>
      <property name="target_map" value="cave.tmx"/>
      <property name="target_x" type="int" value="5"/>
      <property name="target_y" type="int" value="10"/>
      <property name="warp_id" type="int" value="1"/>
      <property name="trigger" value="touch"/>
    </properties>
  </object>
</objectgroup>

<objectgroup name="NPCSpawns">
  <object id="2" name="Goblin_1" x="256" y="384" width="32" height="32">
    <properties>
      <property name="type" value="npc_spawn"/>
      <property name="npc_id" value="Goblin"/>
      <property name="facing" value="down"/>
      <property name="spawn_count" type="int" value="3"/>
    </properties>
  </object>
</objectgroup>

<objectgroup name="PlayerSpawn">
  <object id="3" name="PlayerSpawn" x="320" y="320" width="32" height="32">
    <properties>
      <property name="type" value="player_spawn"/>
      <property name="facing" value="down"/>
    </properties>
  </object>
</objectgroup>
```

### Implementation Steps

1. **Create basic tool structure**
   - Scene with 3-panel layout
   - Map list, preview viewport, object list

2. **Map loading and rendering**
   - Load TMX using existing TMXLoader
   - Render to SubViewport
   - Add pan/zoom controls

3. **Object visualization**
   - Parse existing object layers from TMX
   - Draw colored markers for warps (magenta), spawns (green), player (blue)
   - Show connection lines for warps

4. **Placement mode**
   - Click-to-place for warps and spawns
   - Property editing panel
   - NPC dropdown populated from characters/npcs/

5. **TMX saving**
   - Write updated object layers back to TMX
   - Preserve all other TMX data (tiles, properties)

6. **Navigation**
   - Double-click warp to load target map
   - Back button history

---

## Implementation Order

### Phase 1: Sprite Maker Expansion (Do First)
1. Add role dropdown (Enemy, Vendor, Quest Giver, Trainer, Innkeeper, Generic)
2. Create Vendor panel UI
3. Create Quest Giver panel UI
4. Create Generic NPC panel (simple dialog)
5. Update save/load for new roles
6. Test creating each NPC type

### Phase 2: Map Linker Core
1. Basic 3-panel layout
2. Map list scanning
3. TMX loading and preview rendering
4. Pan/zoom controls

### Phase 3: Map Linker Objects
1. Parse and display existing warps/spawns from TMX
2. Click-to-place warp
3. Click-to-place NPC spawn
4. Property editing panel
5. TMX saving

### Phase 4: Map Linker Navigation
1. Warp following (click to load target map)
2. Map history (back button)
3. Visual connection arrows

### Phase 5: Polish
1. Trainer panel in Sprite Maker
2. Innkeeper panel in Sprite Maker
3. Item/Quest/Skill database creation
4. Picker dialogs for items/quests/skills

---

## File Changes Summary

### New Files
- `tools/map_linker/map_linker.tscn`
- `tools/map_linker/map_linker.gd`
- `data/items.json` (item database)
- `data/quests.json` (quest database)
- `data/skills.json` (skill database)

### Modified Files
- `odyssey_sprite_maker.gd` - Add role system and new panels
- `odyssey_sprite_maker.tscn` - Add new UI elements
- `source/common/maps/tmx_loader.gd` - Already updated for object parsing
- `source/client/gateway/gateway.gd` - Already updated with Map Linker button

---

## Questions to Resolve

1. **Item Database** - Do you have an existing item system? Need to know format.
2. **Quest System** - Is there a quest system started? Need to know format.
3. **Skill System** - Same question for skills/abilities.
4. **Patrol Paths** - Do NPCs need patrol routes? (Can add later)
5. **Encounter Zones** - Are random battles zone-based or step-based?
