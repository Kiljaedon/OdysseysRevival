# Golden Sun MMO - World Building System
## Complete Implementation Plan

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WORLD BUILDING PIPELINE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   DATA LAYER (JSON databases)                                           │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐                   │
│   │  Items  │  │ Quests  │  │ Skills  │  │ Dialog  │                   │
│   └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘                   │
│        │            │            │            │                         │
│        └────────────┴─────┬──────┴────────────┘                         │
│                           ▼                                             │
│   CREATION TOOLS                                                        │
│   ┌───────────────────────────────────────────┐                         │
│   │           SPRITE MAKER (expanded)         │                         │
│   │  • Enemy NPCs (existing)                  │                         │
│   │  • Vendor NPCs (shop inventory)           │                         │
│   │  • Quest Giver NPCs (quest assignments)   │                         │
│   │  • Trainer NPCs (skill teaching)          │                         │
│   │  • Innkeeper NPCs (rest/save services)    │                         │
│   │  • Generic NPCs (dialog only)             │                         │
│   └───────────────────┬───────────────────────┘                         │
│                       ▼                                                 │
│   ┌───────────────────────────────────────────┐                         │
│   │              MAP LINKER                   │                         │
│   │  • View/navigate TMX maps                 │                         │
│   │  • Place warp transitions                 │                         │
│   │  • Place NPC spawns                       │                         │
│   │  • Place player spawn                     │                         │
│   │  • Place encounter zones                  │                         │
│   └───────────────────┬───────────────────────┘                         │
│                       ▼                                                 │
│   ┌───────────────────────────────────────────┐                         │
│   │              TILED                        │                         │
│   │  • Paint terrain/tiles                    │                         │
│   │  • Place structures                       │                         │
│   │  • Collision layers                       │                         │
│   └───────────────────────────────────────────┘                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Data Layer

### 1.1 Items Database

**File**: `data/items.json`

```json
{
  "meta": {
    "version": "1.0",
    "last_updated": "2025-11-30"
  },
  "items": {
    "health_potion": {
      "id": "health_potion",
      "name": "Health Potion",
      "description": "Restores 50 HP",
      "category": "consumable",
      "subcategory": "potion",
      "icon_row": 100,
      "icon_col": 0,
      "stackable": true,
      "max_stack": 99,
      "base_price": 25,
      "effect": {
        "type": "heal_hp",
        "value": 50
      },
      "requirements": null
    },
    "mana_potion": {
      "id": "mana_potion",
      "name": "Mana Potion",
      "description": "Restores 30 MP",
      "category": "consumable",
      "subcategory": "potion",
      "icon_row": 100,
      "icon_col": 1,
      "stackable": true,
      "max_stack": 99,
      "base_price": 30,
      "effect": {
        "type": "heal_mp",
        "value": 30
      },
      "requirements": null
    },
    "iron_sword": {
      "id": "iron_sword",
      "name": "Iron Sword",
      "description": "A sturdy iron blade",
      "category": "equipment",
      "subcategory": "weapon",
      "slot": "main_hand",
      "icon_row": 101,
      "icon_col": 0,
      "stackable": false,
      "max_stack": 1,
      "base_price": 150,
      "stats": {
        "phys_dmg": 12,
        "attack_speed": 1.0
      },
      "requirements": {
        "level": 1,
        "str": 8
      }
    },
    "leather_armor": {
      "id": "leather_armor",
      "name": "Leather Armor",
      "description": "Basic leather protection",
      "category": "equipment",
      "subcategory": "armor",
      "slot": "chest",
      "icon_row": 102,
      "icon_col": 0,
      "stackable": false,
      "max_stack": 1,
      "base_price": 100,
      "stats": {
        "phys_def": 5,
        "mag_def": 2
      },
      "requirements": {
        "level": 1
      }
    }
  }
}
```

**Item Categories**:
- `consumable`: potions, food, scrolls
- `equipment`: weapons, armor, accessories
- `material`: crafting ingredients
- `quest`: quest-specific items (not sellable)
- `key`: keys, passes (not sellable)
- `currency`: special currencies beyond gold

**Equipment Slots**:
- `main_hand`, `off_hand`
- `head`, `chest`, `legs`, `feet`, `hands`
- `neck`, `ring1`, `ring2`

---

### 1.2 Quests Database

**File**: `data/quests.json`

```json
{
  "meta": {
    "version": "1.0",
    "last_updated": "2025-11-30"
  },
  "quests": {
    "goblin_menace": {
      "id": "goblin_menace",
      "name": "The Goblin Menace",
      "description": "Clear the goblin infestation from the forest path.",
      "category": "main",
      "level_requirement": 1,
      "prerequisites": [],
      "steps": [
        {
          "step_id": 1,
          "type": "kill",
          "target": "Goblin",
          "count": 5,
          "description": "Kill 5 Goblins"
        },
        {
          "step_id": 2,
          "type": "talk",
          "target_npc": "GuardCaptain",
          "description": "Report to the Guard Captain"
        }
      ],
      "rewards": {
        "xp": 200,
        "gold": 100,
        "items": [
          { "item_id": "health_potion", "count": 3 }
        ]
      },
      "dialog": {
        "offer": "The forest path is overrun with goblins. We need someone to clear them out. Will you help?",
        "accept": "Thank you! Kill 5 goblins and report back.",
        "progress": "Have you dealt with those goblins yet?",
        "complete": "Excellent work! The road is safe again. Here's your reward."
      },
      "flags_on_complete": ["goblin_menace_done"]
    },
    "fetch_herbs": {
      "id": "fetch_herbs",
      "name": "Herbal Remedy",
      "description": "Collect medicinal herbs for the village healer.",
      "category": "side",
      "level_requirement": 1,
      "prerequisites": [],
      "steps": [
        {
          "step_id": 1,
          "type": "collect",
          "item_id": "forest_herb",
          "count": 10,
          "description": "Collect 10 Forest Herbs"
        },
        {
          "step_id": 2,
          "type": "deliver",
          "target_npc": "VillageHealer",
          "item_id": "forest_herb",
          "count": 10,
          "description": "Deliver herbs to the Village Healer"
        }
      ],
      "rewards": {
        "xp": 100,
        "gold": 50,
        "items": [
          { "item_id": "health_potion", "count": 5 }
        ]
      },
      "dialog": {
        "offer": "I'm running low on herbs for my remedies. Could you gather some from the forest?",
        "accept": "Wonderful! Bring me 10 forest herbs.",
        "progress": "Still need those herbs...",
        "complete": "Perfect! These will help many people. Take these potions as thanks."
      },
      "flags_on_complete": ["helped_healer"],
      "repeatable": false
    }
  }
}
```

**Quest Types**:
- `main`: Main story quests
- `side`: Optional side quests
- `daily`: Repeatable daily quests
- `guild`: Guild-specific quests

**Step Types**:
- `kill`: Kill X of enemy type
- `collect`: Gather X of item (from drops or world)
- `deliver`: Give items to NPC
- `talk`: Speak to NPC
- `explore`: Reach a location
- `escort`: Protect NPC to destination
- `interact`: Use object in world

---

### 1.3 Skills Database

**File**: `data/skills.json`

```json
{
  "meta": {
    "version": "1.0",
    "last_updated": "2025-11-30"
  },
  "skills": {
    "power_strike": {
      "id": "power_strike",
      "name": "Power Strike",
      "description": "A powerful melee attack dealing 150% weapon damage.",
      "category": "combat",
      "subcategory": "melee",
      "icon_row": 200,
      "icon_col": 0,
      "max_level": 5,
      "base_cost": {
        "ep": 10
      },
      "cooldown": 5.0,
      "effect": {
        "type": "damage",
        "damage_type": "physical",
        "multiplier": 1.5,
        "scaling": "str"
      },
      "level_scaling": {
        "multiplier_per_level": 0.1,
        "cost_per_level": 2
      },
      "requirements": {
        "level": 3,
        "class": ["warrior", "knight"]
      },
      "prerequisites": []
    },
    "fireball": {
      "id": "fireball",
      "name": "Fireball",
      "description": "Launch a ball of fire at enemies, dealing fire damage.",
      "category": "magic",
      "subcategory": "offensive",
      "element": "fire",
      "icon_row": 201,
      "icon_col": 0,
      "max_level": 10,
      "base_cost": {
        "mp": 15
      },
      "cooldown": 3.0,
      "effect": {
        "type": "damage",
        "damage_type": "magical",
        "base_damage": 25,
        "scaling": "int"
      },
      "level_scaling": {
        "damage_per_level": 8,
        "cost_per_level": 3
      },
      "requirements": {
        "level": 5,
        "class": ["mage", "sorcerer"]
      },
      "prerequisites": []
    },
    "heal": {
      "id": "heal",
      "name": "Heal",
      "description": "Restore HP to yourself or an ally.",
      "category": "magic",
      "subcategory": "support",
      "element": "holy",
      "icon_row": 202,
      "icon_col": 0,
      "max_level": 10,
      "base_cost": {
        "mp": 20
      },
      "cooldown": 2.0,
      "effect": {
        "type": "heal",
        "target": "single_ally",
        "base_heal": 40,
        "scaling": "wis"
      },
      "level_scaling": {
        "heal_per_level": 12,
        "cost_per_level": 4
      },
      "requirements": {
        "level": 2,
        "class": ["cleric", "paladin"]
      },
      "prerequisites": []
    },
    "whirlwind": {
      "id": "whirlwind",
      "name": "Whirlwind",
      "description": "Spin attack hitting all nearby enemies.",
      "category": "combat",
      "subcategory": "melee",
      "icon_row": 200,
      "icon_col": 1,
      "max_level": 5,
      "base_cost": {
        "ep": 25
      },
      "cooldown": 10.0,
      "effect": {
        "type": "damage",
        "damage_type": "physical",
        "multiplier": 0.8,
        "target": "aoe_circle",
        "radius": 2,
        "scaling": "str"
      },
      "level_scaling": {
        "multiplier_per_level": 0.1,
        "cost_per_level": 5
      },
      "requirements": {
        "level": 8,
        "class": ["warrior", "knight", "berserker"]
      },
      "prerequisites": ["power_strike"]
    }
  }
}
```

**Skill Categories**:
- `combat`: Physical combat abilities
- `magic`: Spells (offensive, defensive, support)
- `passive`: Always-active bonuses
- `crafting`: Crafting-related skills
- `gathering`: Resource gathering skills

---

### 1.4 Dialog Database (Optional Enhancement)

**File**: `data/dialogs.json`

For complex branching dialog trees. Simple dialogs can stay in NPC JSON.

```json
{
  "dialogs": {
    "guard_captain_intro": {
      "id": "guard_captain_intro",
      "nodes": {
        "start": {
          "text": "Halt! State your business in town.",
          "options": [
            { "text": "I'm an adventurer looking for work.", "next": "adventurer" },
            { "text": "Just passing through.", "next": "passing" },
            { "text": "[Attack]", "next": "attack", "flags_required": ["evil_path"] }
          ]
        },
        "adventurer": {
          "text": "An adventurer, eh? We could use someone like you. Goblins have been raiding the trade routes.",
          "options": [
            { "text": "I'll help.", "next": "accept_quest", "action": "start_quest:goblin_menace" },
            { "text": "What's in it for me?", "next": "reward_info" },
            { "text": "Not interested.", "next": "end" }
          ]
        },
        "reward_info": {
          "text": "The town will pay 100 gold, plus whatever you loot from those creatures.",
          "options": [
            { "text": "Deal.", "next": "accept_quest", "action": "start_quest:goblin_menace" },
            { "text": "I'll think about it.", "next": "end" }
          ]
        },
        "accept_quest": {
          "text": "Excellent! Clear out 5 goblins from the forest path and report back.",
          "options": [
            { "text": "Consider it done.", "next": "end" }
          ]
        },
        "passing": {
          "text": "Very well. Keep your nose clean and you won't have any trouble.",
          "next": "end"
        },
        "end": {
          "text": null,
          "action": "close_dialog"
        }
      }
    }
  }
}
```

---

## Part 2: Sprite Maker Expansion

### 2.1 New UI Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ODYSSEY SPRITE MAKER                              [↻ Refresh] [Back]  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─ SPRITE GRID ──────────────────────────────────────────────────────┐ │
│  │  [Row 1: sprites...]                                               │ │
│  │  [Row 2: sprites...]                                               │ │
│  │  [Click to select animation frames]                                │ │
│  │                                          [Page 1/13] [<] [>]       │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌─ CHARACTER INFO ───────────────────┐  ┌─ ROLE SETTINGS ───────────┐ │
│  │                                    │  │                           │ │
│  │  Name: [____________]              │  │  Role: [Enemy ▼]          │ │
│  │  Type: (•)Class  ( )NPC            │  │                           │ │
│  │                                    │  │  ┌─────────────────────┐  │ │
│  │  [Sprite Preview]  Current:        │  │  │ ENEMY SETTINGS      │  │ │
│  │  [  Animated   ]   walk_down       │  │  │ (current panel)     │  │ │
│  │                                    │  │  │                     │  │ │
│  │  Class List: [Knight ▼] [Delete]   │  │  │ Combat Role: [___]  │ │ │
│  │  NPC List:   [Goblin ▼] [Delete]   │  │  │ AI Type: [______]   │ │ │
│  │                                    │  │  │ Element: [____]     │  │ │
│  │  [Save Character]                  │  │  │ Level Range: [_-_]  │  │ │
│  └────────────────────────────────────┘  │  │                     │  │ │
│                                          │  │ Stats: STR DEX INT  │  │ │
│  ┌─ STATS PANEL ──────────────────────┐  │  │        [_] [_] [_]  │  │ │
│  │  Level: [1]                        │  │  │        VIT WIS CHA  │  │ │
│  │  STR: [10]  DEX: [10]  INT: [10]   │  │  │        [_] [_] [_]  │  │ │
│  │  VIT: [10]  WIS: [10]  CHA: [10]   │  │  │                     │  │ │
│  │  ─────────────────────────────     │  │  │ Loot: Gold [__]     │  │ │
│  │  HP: 100   MP: 80   EP: 60         │  │  │       XP [____]     │  │ │
│  │  Phys Dmg: 15  Mag Dmg: 12         │  │  └─────────────────────┘  │ │
│  │  Phys Def: 8   Mag Def: 6          │  │                           │ │
│  └────────────────────────────────────┘  └───────────────────────────┘ │
│                                                                         │
│  Status: Ready                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Role-Specific Panels

When role changes, swap out the ROLE SETTINGS panel:

**Enemy Panel** (existing, reorganized):
```
┌─ ENEMY SETTINGS ────────────────────────┐
│  Combat Role: [Melee ▼]                 │
│  AI Archetype: [AGGRESSIVE ▼]           │
│  Element: [None ▼]                      │
│  Level Range: [1] to [5]                │
│                                         │
│  ─── Loot Table ───                     │
│  Gold Reward: [10]                      │
│  XP Reward: [50]                        │
│  Item Drops: [+ Add Drop]               │
│  ┌────────────────────────────────────┐ │
│  │ Item         Chance   Min  Max     │ │
│  │ health_potion  25%     1    1  [X] │ │
│  │ goblin_ear     100%    1    2  [X] │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Description:                           │
│  [________________________________]     │
│  [________________________________]     │
└─────────────────────────────────────────┘
```

**Vendor Panel** (new):
```
┌─ VENDOR SETTINGS ───────────────────────┐
│  Shop Type: [General ▼]                 │
│  Buy Rate: [0.5] (pays 50% for items)   │
│  Restock Time: [24] hours               │
│                                         │
│  ─── Shop Inventory ───                 │
│  [+ Add Item]  [Import from Template]   │
│  ┌────────────────────────────────────┐ │
│  │ Item            Stock  Price  Mult │ │
│  │ health_potion    99    25    1.0 X │ │
│  │ mana_potion      99    30    1.0 X │ │
│  │ iron_sword        5   150    1.2 X │ │
│  │ leather_armor     3   100    1.1 X │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ─── Dialog ───                         │
│  Greeting: [Welcome, traveler!____]     │
│  No Money: [Come back with gold.__]     │
│  Purchase: [Excellent choice!____]      │
│  Farewell: [Safe travels!________]      │
└─────────────────────────────────────────┘
```

**Quest Giver Panel** (new):
```
┌─ QUEST GIVER SETTINGS ──────────────────┐
│                                         │
│  ─── Available Quests ───               │
│  [+ Add Quest]                          │
│  ┌────────────────────────────────────┐ │
│  │ Quest ID        Requires   Blocks  │ │
│  │ goblin_menace   -          done  X │ │
│  │ find_artifact   done       -     X │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ─── Dialog ───                         │
│  Greeting: [Adventurer! I need help]    │
│  No Quests: [Thank you for everything]  │
│  Quest Active: [How goes the task?__]   │
│                                         │
│  [ ] Use Complex Dialog Tree            │
│  Dialog ID: [guard_captain_intro ▼]     │
└─────────────────────────────────────────┘
```

**Trainer Panel** (new):
```
┌─ TRAINER SETTINGS ──────────────────────┐
│  Trainer Type: [Combat ▼]               │
│                                         │
│  ─── Skills Taught ───                  │
│  [+ Add Skill]                          │
│  ┌────────────────────────────────────┐ │
│  │ Skill          Lvl Req  Cost       │ │
│  │ power_strike      3     500g    X  │ │
│  │ whirlwind         8    2000g    X  │ │
│  │ shield_bash       5    1000g    X  │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ─── Dialog ───                         │
│  Greeting: [Ready to train?_______]     │
│  Too Low: [Come back when stronger]     │
│  No Gold: [Training costs money.__]     │
│  Success: [You've learned well!__]      │
└─────────────────────────────────────────┘
```

**Innkeeper Panel** (new):
```
┌─ INNKEEPER SETTINGS ────────────────────┐
│                                         │
│  ─── Services ───                       │
│  [✓] Rest (restore HP/MP)               │
│      Cost: [10] gold                    │
│      Heal: [100]%                       │
│                                         │
│  [✓] Set Respawn Point                  │
│                                         │
│  [ ] Storage Access (bank)              │
│      Slots: [20]                        │
│                                         │
│  ─── Dialog ───                         │
│  Greeting: [Need a room?_________]      │
│  Rest: [Sleep well, traveler.___]       │
│  No Money: [Can't stay for free._]      │
│  Set Spawn: [I'll remember you.__]      │
└─────────────────────────────────────────┘
```

**Generic NPC Panel** (new):
```
┌─ GENERIC NPC SETTINGS ──────────────────┐
│                                         │
│  Dialog Mode: (•)Random  ( )Sequential  │
│                                         │
│  ─── Dialog Lines ───                   │
│  [+ Add Line]                           │
│  ┌────────────────────────────────────┐ │
│  │ 1. "Nice weather today."        X  │ │
│  │ 2. "Have you heard the news?"   X  │ │
│  │ 3. "The king seems troubled..." X  │ │
│  └────────────────────────────────────┘ │
│                                         │
│  [ ] Has Complex Dialog Tree            │
│  Dialog ID: [___________________ ▼]     │
│                                         │
│  ─── Flags ───                          │
│  Only show if: [____________]           │
│  Hide if: [____________]                │
└─────────────────────────────────────────┘
```

### 2.3 Implementation Steps

1. **Add role field to character_data**
2. **Create role dropdown in UI**
3. **Create panel containers for each role**
4. **Implement show/hide logic based on role**
5. **Add item picker popup** (for vendors)
6. **Add quest picker popup** (for quest givers)
7. **Add skill picker popup** (for trainers)
8. **Update save/load to handle all roles**
9. **Test each NPC type creation**

---

## Part 3: Map Linker Tool

### 3.1 Full UI Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│  [Back to Menu]              MAP LINKER                    [Settings]   │
├──────────────┬──────────────────────────────────────┬───────────────────┤
│              │                                      │                   │
│  ─ MAPS ──   │         MAP PREVIEW                  │  ─ OBJECTS ─      │
│              │                                      │                   │
│  [🔍 Search] │  ┌──────────────────────────────┐    │  Warps (3)        │
│              │  │                              │    │  ├─ W1 → cave     │
│  📁 overworld│  │                              │    │  ├─ W2 → town     │
│    📁 areas  │  │     [Rendered TMX map        │    │  └─ W3 → shop_int │
│      └ forest│  │      with object markers]    │    │                   │
│      └ desert│  │                              │    │  NPC Spawns (4)   │
│    📄 main   │  │   [W1]●───────────────→      │    │  ├─ Goblin (x3)   │
│  📁 dungeons │  │                              │    │  ├─ ShopKeeper    │
│    📄 cave   │  │        ◆ Player Spawn        │    │  ├─ GuardCaptain  │
│    📄 ruins  │  │                              │    │  └─ Villager      │
│  📁 interiors│  │   [N1]■ Goblin               │    │                   │
│    📄 shop   │  │   [N2]■ ShopKeeper           │    │  Encounters (1)   │
│    📄 inn    │  │                              │    │  └─ Zone1: Goblin │
│              │  │   [E1]▨ Encounter Zone       │    │                   │
│              │  └──────────────────────────────┘    │  Player Spawn     │
│              │                                      │  └─ (320, 256)    │
│  [+ New]     │  Zoom: [+][-][100%]  [Fit]          │                   │
│  [↻ Refresh] │                                      │  [+ Warp]         │
│              │  ─── TOOLS ───                       │  [+ NPC Spawn]    │
│              │  [🚪 Warp] [👤 NPC] [⚔ Encounter]   │  [+ Encounter]    │
│              │  [◆ Player] [✋ Select] [🗑 Delete]  │  [◆ Player Spawn] │
│              │                                      │                   │
├──────────────┴──────────────────────────────────────┼───────────────────┤
│                                                     │                   │
│  ─── PROPERTIES ───────────────────────────────     │  ─── QUICK ───    │
│                                                     │                   │
│  Selected: Warp_1                                   │  [Save Map]       │
│  Position: (160, 320)  Size: (32, 32)              │  [Undo]           │
│                                                     │  [Redo]           │
│  Target Map: [cave ▼]  [Browse...]                 │                   │
│  Target Pos: X [5] Y [10]  [Pick on Map]           │  [Test Play]      │
│  Trigger: [Touch ▼]  (Touch / Interact / Auto)     │                   │
│  Warp ID: [1]                                       │                   │
│                                                     │                   │
│  [Delete Object]  [Duplicate]  [Go to Target →]    │                   │
│                                                     │                   │
└─────────────────────────────────────────────────────┴───────────────────┘
```

### 3.2 Features Detail

**Map Browser (Left Panel)**
- Tree view of maps/ directory
- Folders expand/collapse
- Search filter
- New map button (creates from template)
- Refresh button

**Map Preview (Center)**
- Renders full TMX map
- Shows colored markers:
  - 🟪 Magenta: Warps
  - 🟩 Green: NPC Spawns
  - 🟨 Yellow: Encounter Zones
  - 🟦 Blue: Player Spawn
- Connection lines from warps to edge (indicating they lead somewhere)
- Pan with middle mouse drag
- Zoom with scroll wheel
- Grid overlay toggle

**Object List (Right Panel)**
- Categorized list of all objects
- Click to select and center view
- Shows count for spawn groups
- Quick add buttons

**Properties Panel (Bottom)**
- Context-sensitive based on selection
- Direct editing of all object properties
- "Go to Target" for warps
- "Pick on Map" opens target map for coordinate selection

**Tools**
- Select: Click objects to select
- Warp: Click to place warp zone
- NPC: Click to place NPC spawn point
- Encounter: Click-drag to draw encounter zone
- Player: Click to set player spawn (moves existing)
- Delete: Click objects to remove

### 3.3 Object Properties

**Warp**:
```
- target_map: String (path to TMX)
- target_x: int (tile coordinate)
- target_y: int (tile coordinate)
- warp_id: int (unique per map)
- trigger: "touch" | "interact" | "auto"
- direction: "any" | "up" | "down" | "left" | "right"
- transition: "fade" | "instant" | "slide"
```

**NPC Spawn**:
```
- npc_id: String (matches NPC JSON filename)
- facing: "up" | "down" | "left" | "right"
- spawn_count: int (for enemy groups)
- respawn_time: int (seconds, 0 = no respawn)
- wander_radius: int (tiles, 0 = stationary)
- instance_dialog: String (override NPC dialog for this instance)
- instance_quests: Array (override quest list for this instance)
```

**Encounter Zone**:
```
- zone_id: String
- enemy_table: [
    { "npc_id": "Goblin", "weight": 70, "min": 1, "max": 3 },
    { "npc_id": "OrcWarrior", "weight": 30, "min": 1, "max": 1 }
  ]
- encounter_rate: float (0.0 - 1.0, chance per step)
- level_range: { "min": 1, "max": 5 }
- enabled_flags: Array (only active if player has these flags)
```

**Player Spawn**:
```
- facing: "up" | "down" | "left" | "right"
- is_default: bool (initial spawn for new characters)
```

### 3.4 Implementation Steps

1. **Basic scene structure**
   - 3-panel layout with splitters
   - Map tree browser
   - SubViewport for map rendering

2. **TMX loading and rendering**
   - Use existing TMXLoader
   - Load tileset and render layers
   - Add camera controls (pan/zoom)

3. **Object layer parsing**
   - Read existing warps, spawns, encounters from TMX
   - Create visual markers
   - Populate object list

4. **Selection system**
   - Click detection on markers
   - Highlight selected object
   - Show properties in panel

5. **Placement tools**
   - Tool mode state machine
   - Click handlers for each tool
   - Snap to grid option

6. **Property editing**
   - Dynamic property panel based on object type
   - Live updates to markers
   - Validation

7. **TMX saving**
   - Serialize objects back to TMX format
   - Preserve tile layers unchanged
   - Backup before save

8. **Navigation**
   - "Go to Target" loads target map
   - History stack for back button
   - "Pick on Map" mode for coordinate selection

---

## Part 4: Data Editors (Optional Future)

### 4.1 Item Editor

Simple tool to edit `data/items.json`:
- List all items
- Add/edit/delete items
- Icon picker from sprite sheet
- Stat editor for equipment
- Effect editor for consumables

### 4.2 Quest Editor

Tool to edit `data/quests.json`:
- Visual quest step builder
- Reward configuration
- Dialog writing
- Flag management
- Preview quest flow

### 4.3 Skill Editor

Tool to edit `data/skills.json`:
- Skill tree visualization
- Effect configuration
- Scaling calculator
- Animation preview

---

## Part 5: Implementation Order

### Week 1: Data Foundation
- [ ] Create `data/items.json` with 20-30 starter items
- [ ] Create `data/quests.json` with 5-10 starter quests
- [ ] Create `data/skills.json` with 15-20 starter skills
- [ ] Create DataLoader singleton to access databases

### Week 2: Sprite Maker - Core Expansion
- [ ] Add role dropdown (Enemy, Vendor, Quest Giver, Trainer, Innkeeper, Generic)
- [ ] Create panel container system (show/hide based on role)
- [ ] Implement Vendor panel with inventory editor
- [ ] Implement Generic NPC panel with dialog lines

### Week 3: Sprite Maker - Advanced Roles
- [ ] Implement Quest Giver panel with quest picker
- [ ] Implement Trainer panel with skill picker
- [ ] Implement Innkeeper panel with service options
- [ ] Create item/quest/skill picker popups

### Week 4: Map Linker - Foundation
- [ ] Create basic 3-panel layout
- [ ] Implement map tree browser
- [ ] TMX loading and rendering in SubViewport
- [ ] Pan/zoom camera controls

### Week 5: Map Linker - Objects
- [ ] Parse and display existing objects from TMX
- [ ] Implement selection system
- [ ] Create property panel for each object type
- [ ] Warp placement and editing

### Week 6: Map Linker - Full Features
- [ ] NPC spawn placement with NPC picker
- [ ] Encounter zone drawing
- [ ] Player spawn placement
- [ ] TMX saving

### Week 7: Map Linker - Polish
- [ ] Warp navigation ("Go to Target")
- [ ] History/undo system
- [ ] Coordinate picker mode
- [ ] Grid overlay and snapping

### Week 8: Testing & Polish
- [ ] Test full workflow: create NPC → place in map → test in game
- [ ] Fix bugs
- [ ] Performance optimization
- [ ] Documentation

---

## File Structure After Implementation

```
GoldenSunMMO-Dev/
├── data/
│   ├── items.json
│   ├── quests.json
│   ├── skills.json
│   └── dialogs.json (optional)
│
├── characters/
│   ├── classes/
│   │   └── Knight.json
│   ├── npcs/
│   │   ├── Goblin.json          (role: enemy)
│   │   ├── ShopKeeper.json      (role: vendor)
│   │   ├── GuardCaptain.json    (role: quest_giver)
│   │   ├── SwordMaster.json     (role: trainer)
│   │   ├── Innkeeper.json       (role: innkeeper)
│   │   └── Villager.json        (role: generic)
│   └── player_characters/
│
├── maps/
│   ├── overworld/
│   │   └── main.tmx
│   ├── dungeons/
│   │   └── cave.tmx
│   └── interiors/
│       ├── shop.tmx
│       └── inn.tmx
│
├── tools/
│   └── map_linker/
│       ├── map_linker.tscn
│       └── map_linker.gd
│
├── odyssey_sprite_maker.tscn    (expanded)
├── odyssey_sprite_maker.gd      (expanded)
│
└── source/
    └── common/
        ├── data/
        │   └── data_loader.gd   (singleton for loading JSON databases)
        └── maps/
            └── tmx_loader.gd    (already updated)
```

---

## Summary

**Total New Systems:**
1. Items Database + optional editor
2. Quests Database + optional editor
3. Skills Database + optional editor
4. Sprite Maker expansion (6 NPC roles)
5. Map Linker tool

**Workflow After Completion:**
1. Define items/quests/skills in JSON (or editors)
2. Create NPCs in Sprite Maker (pick role, set properties)
3. Paint maps in Tiled
4. Connect maps and place NPCs in Map Linker
5. Play test

This gives you a complete world-building pipeline without needing to manually edit JSON files or TMX object layers.
