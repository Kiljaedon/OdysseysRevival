# Battle Instance System Plan

## Overview
When a player attacks an NPC on the world map, they enter a **private battle instance** using a **dedicated battle map** (not the world map). The battle map:
1. Has the **same boundaries/collision** as the world map it's linked to
2. Contains **pre-placed spawn points** for player and enemies
3. Is a **self-contained arena** (isolated per player/group)
4. Spawns **1-3 enemies** in logical groups (bandits, raiders, mixed types)

## Directory Structure
```
maps/
├── World Maps/
│   └── sample_map.tmx         # Exploration map
└── Battle Maps/
    └── sample_map_battle.tmx  # Battle arena (same boundaries, different spawn points)
```

## Battle Map Requirements

### TMX Structure
Each battle map must have:
1. **Same dimensions** as linked world map (e.g., 20x15 tiles)
2. **Same collision layer** (copied from world map)
3. **Spawn Points object layer** with:
   - `player_spawn` - Where player team spawns
   - `enemy_spawn_1`, `enemy_spawn_2`, `enemy_spawn_3` - Enemy positions

### Spawn Point Properties (in TMX)
```xml
<objectgroup name="SpawnPoints">
  <object name="player_spawn" x="1280" y="1600">
    <properties>
      <property name="type" value="player"/>
      <property name="facing" value="up"/>
    </properties>
  </object>
  <object name="enemy_spawn_1" x="1280" y="400">
    <properties>
      <property name="type" value="enemy"/>
      <property name="facing" value="down"/>
      <property name="captain" value="true"/>
    </properties>
  </object>
  <object name="enemy_spawn_2" x="1100" y="500">
    <properties>
      <property name="type" value="enemy"/>
      <property name="facing" value="down"/>
    </properties>
  </object>
  <object name="enemy_spawn_3" x="1460" y="500">
    <properties>
      <property name="type" value="enemy"/>
      <property name="facing" value="down"/>
    </properties>
  </object>
</objectgroup>
```

## Implementation Steps

### Phase 1: Battle Map Loader
**File: `source/server/managers/battle_map_loader.gd` (NEW)**

Responsible for:
- Loading battle map TMX files
- Parsing spawn point positions
- Providing spawn data to RealtimeCombatManager

```gdscript
class_name BattleMapLoader
extends Node

var battle_maps: Dictionary = {}  # map_name -> battle_map_data
var spawn_points: Dictionary = {}  # map_name -> {player_spawn, enemy_spawns[]}

func load_battle_map(world_map_name: String) -> Dictionary:
    """Load the battle map linked to a world map"""
    var battle_map_path = "res://maps/Battle Maps/%s_battle.tmx" % world_map_name

    if not FileAccess.file_exists(battle_map_path):
        # Auto-generate if missing (copy from world map)
        battle_map_path = _create_battle_map_from_world(world_map_name)

    var map_data = _parse_battle_map_tmx(battle_map_path)
    battle_maps[world_map_name] = map_data
    return map_data

func get_spawn_points(world_map_name: String) -> Dictionary:
    """Get spawn positions for battle on this map"""
    if not spawn_points.has(world_map_name):
        load_battle_map(world_map_name)
    return spawn_points.get(world_map_name, {})

func _parse_spawn_points(xml_content: String, map_name: String) -> void:
    """Extract spawn point objects from TMX"""
    var spawns = {
        "player_spawn": Vector2(1280, 1600),  # Default
        "enemy_spawns": [],
        "player_facing": "up",
        "enemy_facings": []
    }

    # Parse SpawnPoints objectgroup from TMX
    # ... TMX parsing code ...

    spawn_points[map_name] = spawns
```

### Phase 2: Auto-Generate Battle Maps
When a world map exists but no battle map:
1. Copy the world map TMX
2. Remove NPC spawn objects
3. Remove transition zones
4. Add default spawn points (player south, enemies north)
5. Save as `{world_map}_battle.tmx`

```gdscript
func _create_battle_map_from_world(world_map_name: String) -> String:
    """Auto-generate a battle map from world map"""
    var world_path = "res://maps/World Maps/%s.tmx" % world_map_name
    var battle_path = "res://maps/Battle Maps/%s_battle.tmx" % world_map_name

    # Read world map
    var world_content = FileAccess.open(world_path, FileAccess.READ).get_as_text()

    # Modify for battle:
    # - Keep tile layers and collision
    # - Remove NPC spawns and transitions
    # - Add SpawnPoints layer with defaults

    var battle_content = _transform_to_battle_map(world_content)

    # Write battle map
    var file = FileAccess.open(battle_path, FileAccess.WRITE)
    file.store_string(battle_content)
    file.close()

    return battle_path
```

### Phase 3: Modify RealtimeCombatManager
**File: `source/server/managers/realtime_combat_manager.gd`**

Update `create_battle()` to:
1. Get battle map for the world map player is on
2. Load spawn points from battle map
3. Spawn player at `player_spawn` position
4. Spawn 1-3 enemies at `enemy_spawn_X` positions

```gdscript
# Add battle_map_loader reference
var battle_map_loader: BattleMapLoader = null

func create_battle(peer_id: int, npc_id: int, player_data: Dictionary, squad_data: Array, enemy_data: Array, world_map_name: String = "sample_map") -> int:
    var battle_id = next_battle_id
    next_battle_id += 1

    # Get battle map spawn points
    var spawns = battle_map_loader.get_spawn_points(world_map_name)
    var player_spawn = spawns.player_spawn
    var enemy_spawns = spawns.enemy_spawns

    # Battle map name for client
    var battle_map_name = "%s_battle" % world_map_name

    var battle = {
        "id": battle_id,
        "state": "active",
        "participants": [peer_id],
        "world_map": world_map_name,
        "battle_map_name": battle_map_name,
        "map_width": map_width,
        "map_height": map_height,
        "units": {},
        # ... rest unchanged
    }

    # Spawn at designated positions
    _spawn_player_unit(battle, peer_id, player_data, player_spawn, spawns.player_facing)
    _spawn_squad_units(battle, peer_id, squad_data, player_spawn)
    _spawn_enemy_units_at_points(battle, enemy_data, enemy_spawns, spawns.enemy_facings)

    # ... rest unchanged
```

### Phase 4: Enemy Group System (Future)
Define logical enemy groups that spawn together:

```gdscript
# Enemy group definitions (can be JSON later)
const ENEMY_GROUPS = {
    "bandits": {
        "name": "Bandit Gang",
        "composition": [
            {"type": "Rogue", "role": "captain", "count": 1},
            {"type": "RogueBandit", "role": "minion", "count": 1-2}
        ]
    },
    "raiders": {
        "name": "Raider Party",
        "composition": [
            {"type": "OrcWarrior", "role": "captain", "count": 1},
            {"type": "Goblin", "role": "minion", "count": 2}
        ]
    },
    "mages": {
        "name": "Dark Cult",
        "composition": [
            {"type": "DarkMage", "role": "captain", "count": 1},
            {"type": "DarkMage", "role": "minion", "count": 1}
        ]
    },
    "mixed": {
        "name": "Mercenary Band",
        "composition": [
            {"type": "EliteGuard", "role": "captain", "count": 1},
            {"type": "Rogue", "role": "minion", "count": 1},
            {"type": "DarkMage", "role": "minion", "count": 1}
        ]
    }
}
```

### Phase 5: Instance Isolation

Each battle instance is completely isolated:
- Has unique `instance_id`
- Only participants can interact
- World map state unchanged
- NPC on world map frozen/hidden during battle

```gdscript
# Track instance isolation
var battle_instances: Dictionary = {}  # instance_id -> battle_data
var player_to_instance: Dictionary = {}  # peer_id -> instance_id
var npc_in_battle: Dictionary = {}  # npc_id -> instance_id (freeze world NPC)

func create_instance(peer_id: int, npc_id: int, world_map: String) -> String:
    var instance_id = "battle_%d_%d" % [peer_id, Time.get_ticks_msec()]

    # Mark NPC as in battle (freeze on world map)
    npc_in_battle[npc_id] = instance_id

    # Track player's instance
    player_to_instance[peer_id] = instance_id

    return instance_id

func end_instance(instance_id: String) -> void:
    # Find and release NPC
    for npc_id in npc_in_battle:
        if npc_in_battle[npc_id] == instance_id:
            npc_in_battle.erase(npc_id)
            break

    # Release player
    for peer_id in player_to_instance:
        if player_to_instance[peer_id] == instance_id:
            player_to_instance.erase(peer_id)

    battle_instances.erase(instance_id)
```

## Spawn Distance Visualization

```
Battle Map Layout:
┌──────────────────────────────────────┐
│                                      │
│     E2         E1(Capt)        E3    │  Enemy spawns (north)
│      ↓           ↓              ↓    │  All facing DOWN
│                                      │
│                                      │
│             ~6-8 tiles               │  Safe distance
│                                      │
│                                      │
│      S1          P           S2      │  Player + Squad (south)
│      ↑           ↑           ↑       │  All facing UP
│                 S3                   │
└──────────────────────────────────────┘

E1 = enemy_spawn_1 (captain)
E2 = enemy_spawn_2
E3 = enemy_spawn_3
P  = player_spawn
S1-S3 = squad positions (relative to P)
```

## File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `source/server/managers/battle_map_loader.gd` | NEW | Load battle maps, parse spawn points |
| `source/server/managers/realtime_combat_manager.gd` | MODIFY | Use battle map spawns |
| `source/server/server_world.gd` | MODIFY | Initialize battle_map_loader |
| `source/server/managers/map_manager.gd` | MODIFY | Track battle map paths |
| `maps/Battle Maps/sample_map_battle.tmx` | NEW | First battle map with spawn points |

## Data Flow

```
1. Player attacks NPC on world map (sample_map)
   ↓
2. Server: RealtimeCombatManager.create_battle()
   ├── battle_map_loader.get_spawn_points("sample_map")
   │   └── Returns {player_spawn, enemy_spawns[]}
   ├── Create isolated instance
   ├── Freeze world NPC (mark as in_battle)
   └── Spawn units at designated positions
   ↓
3. Server sends rt_battle_start to client with:
   ├── battle_map_name: "sample_map_battle"
   ├── unit positions from spawn points
   └── battle arena bounds
   ↓
4. Client: RealtimeBattleLauncher
   ├── Load sample_map_battle.tmx as arena
   ├── Render tilemap
   └── Position units
   ↓
5. Battle plays out in isolated instance
   ├── Movement bounded by battle map collision
   ├── Other players can't see/join
   └── World state unchanged
   ↓
6. Battle ends → Instance destroyed → Player returns to world map
   └── World NPC unfrozen (or respawns if defeated)
```

## Testing Checklist

- [ ] Battle map auto-generates from world map if missing
- [ ] Spawn points load correctly from TMX
- [ ] Player spawns at player_spawn position
- [ ] Enemies spawn at enemy_spawn positions (1-3)
- [ ] Minimum distance between player and enemies maintained
- [ ] World NPC frozen during battle
- [ ] Client loads correct battle map tileset
- [ ] Battle collision uses battle map collision layer
- [ ] Instance isolation works (other players can't see)
- [ ] PvP works with two players in same instance
