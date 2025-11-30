/// <reference types="@mapeditor/tiled-api" />

/*
 * Map Warp/Link Tool for Golden Sun MMO
 *
 * Easily place warp points that link maps together.
 * Creates objects with proper properties for the TMX loader.
 *
 * Usage:
 * 1. Select the "Place Warp" tool from the toolbar
 * 2. Click on the map to place a warp point
 * 3. Fill in the properties in the dialog
 *
 * Warp Properties:
 * - target_map: Path to the target TMX file (e.g., "dungeon/cave.tmx")
 * - target_x: X tile coordinate to spawn at in target map
 * - target_y: Y tile coordinate to spawn at in target map
 * - warp_id: Unique ID for this warp (for two-way linking)
 * - trigger: "touch" (automatic) or "interact" (press action key)
 */

// Register the custom object type for warps
tiled.registerMapFormat("GoldenSunWarp", {
    name: "Golden Sun Warp Objects",
    extension: "gsw",
    // This is just to register the format, not actually used for import/export
    read: function(fileName) { return null; },
    write: function(map, fileName) { return undefined; }
});

// Action to create a new warp object layer if it doesn't exist
let createWarpLayerAction = tiled.registerAction("CreateWarpLayer", function(action) {
    let map = tiled.activeAsset;
    if (!map || !map.isTileMap) {
        tiled.alert("Please open a map first.");
        return;
    }

    // Check if Warps layer exists
    let warpsLayer = null;
    for (let i = 0; i < map.layerCount; i++) {
        let layer = map.layerAt(i);
        if (layer.name === "Warps" && layer.isObjectLayer) {
            warpsLayer = layer;
            break;
        }
    }

    if (warpsLayer) {
        tiled.alert("Warps layer already exists!");
        map.currentLayer = warpsLayer;
        return;
    }

    // Create the Warps object layer
    let newLayer = new ObjectGroup("Warps");
    newLayer.color = "#ff00ff"; // Magenta for visibility

    map.addLayer(newLayer);
    map.currentLayer = newLayer;

    tiled.log("Created 'Warps' object layer");
});
createWarpLayerAction.text = "Create Warps Layer";
createWarpLayerAction.shortcut = "Ctrl+Shift+W";

// Action to insert a warp at current position
let insertWarpAction = tiled.registerAction("InsertWarp", function(action) {
    let map = tiled.activeAsset;
    if (!map || !map.isTileMap) {
        tiled.alert("Please open a map first.");
        return;
    }

    // Find or create Warps layer
    let warpsLayer = null;
    for (let i = 0; i < map.layerCount; i++) {
        let layer = map.layerAt(i);
        if (layer.name === "Warps" && layer.isObjectLayer) {
            warpsLayer = layer;
            break;
        }
    }

    if (!warpsLayer) {
        // Create it
        warpsLayer = new ObjectGroup("Warps");
        warpsLayer.color = "#ff00ff";
        map.addLayer(warpsLayer);
    }

    // Get center of current view as default position
    let centerX = map.width * map.tileWidth / 2;
    let centerY = map.height * map.tileHeight / 2;

    // Create warp object
    let warp = new MapObject("Warp");
    warp.x = centerX;
    warp.y = centerY;
    warp.width = map.tileWidth;
    warp.height = map.tileHeight;
    warp.shape = MapObject.Rectangle;

    // Set custom properties
    warp.setProperty("type", "warp");
    warp.setProperty("target_map", "");
    warp.setProperty("target_x", 0);
    warp.setProperty("target_y", 0);
    warp.setProperty("warp_id", 0);
    warp.setProperty("trigger", "touch");

    warpsLayer.addObject(warp);

    tiled.log("Created warp object - set properties in the Properties panel");
    tiled.alert("Warp created at map center.\n\nSelect it and set properties:\n- target_map: destination TMX path\n- target_x/y: spawn coordinates\n- warp_id: unique ID\n- trigger: 'touch' or 'interact'");
});
insertWarpAction.text = "Insert Warp Point";
insertWarpAction.shortcut = "W";

// Custom tool for placing warps by clicking
let warpPlacementTool = tiled.registerTool("PlaceWarpTool", {
    name: "Place Warp",
    icon: "",
    usesSelectedTiles: false,

    activated: function() {
        this.statusInfo = "Click to place a warp point | Set properties after placing";
    },

    mousePressed: function(button, x, y, modifiers) {
        if (button !== Qt.LeftButton) return;

        let map = this.map;
        if (!map) return;

        // Snap to tile grid
        let tileX = Math.floor(x / map.tileWidth) * map.tileWidth;
        let tileY = Math.floor(y / map.tileHeight) * map.tileHeight;

        // Find or create Warps layer
        let warpsLayer = null;
        for (let i = 0; i < map.layerCount; i++) {
            let layer = map.layerAt(i);
            if (layer.name === "Warps" && layer.isObjectLayer) {
                warpsLayer = layer;
                break;
            }
        }

        if (!warpsLayer) {
            warpsLayer = new ObjectGroup("Warps");
            warpsLayer.color = "#ff00ff";
            map.addLayer(warpsLayer);
        }

        // Generate unique warp ID
        let maxId = 0;
        for (let obj of warpsLayer.objects) {
            let id = obj.property("warp_id");
            if (id && id > maxId) maxId = id;
        }

        // Create warp object
        let warp = new MapObject("Warp_" + (maxId + 1));
        warp.x = tileX;
        warp.y = tileY;
        warp.width = map.tileWidth;
        warp.height = map.tileHeight;
        warp.shape = MapObject.Rectangle;

        // Set default properties
        warp.setProperty("type", "warp");
        warp.setProperty("target_map", "");
        warp.setProperty("target_x", 0);
        warp.setProperty("target_y", 0);
        warp.setProperty("warp_id", maxId + 1);
        warp.setProperty("trigger", "touch");

        warpsLayer.addObject(warp);

        this.statusInfo = "Warp #" + (maxId + 1) + " placed at tile (" +
            Math.floor(tileX / map.tileWidth) + ", " +
            Math.floor(tileY / map.tileHeight) + ") - Set target_map in Properties!";
    }
});

// Tool for placing NPC spawn points
let npcSpawnTool = tiled.registerTool("PlaceNPCSpawnTool", {
    name: "Place NPC Spawn",
    icon: "",
    usesSelectedTiles: false,

    activated: function() {
        this.statusInfo = "Click to place an NPC spawn point";
    },

    mousePressed: function(button, x, y, modifiers) {
        if (button !== Qt.LeftButton) return;

        let map = this.map;
        if (!map) return;

        let tileX = Math.floor(x / map.tileWidth) * map.tileWidth;
        let tileY = Math.floor(y / map.tileHeight) * map.tileHeight;

        // Find or create NPCSpawns layer
        let spawnLayer = null;
        for (let i = 0; i < map.layerCount; i++) {
            let layer = map.layerAt(i);
            if (layer.name === "NPCSpawns" && layer.isObjectLayer) {
                spawnLayer = layer;
                break;
            }
        }

        if (!spawnLayer) {
            spawnLayer = new ObjectGroup("NPCSpawns");
            spawnLayer.color = "#00ff00";
            map.addLayer(spawnLayer);
        }

        // Generate unique spawn ID
        let maxId = 0;
        for (let obj of spawnLayer.objects) {
            let id = obj.property("spawn_id");
            if (id && id > maxId) maxId = id;
        }

        let spawn = new MapObject("NPC_" + (maxId + 1));
        spawn.x = tileX;
        spawn.y = tileY;
        spawn.width = map.tileWidth;
        spawn.height = map.tileHeight;
        spawn.shape = MapObject.Ellipse;

        spawn.setProperty("type", "npc_spawn");
        spawn.setProperty("spawn_id", maxId + 1);
        spawn.setProperty("npc_type", "");
        spawn.setProperty("npc_name", "");
        spawn.setProperty("dialog", "");
        spawn.setProperty("facing", "down");

        spawnLayer.addObject(spawn);

        this.statusInfo = "NPC spawn #" + (maxId + 1) + " placed - Set npc_type in Properties!";
    }
});

// Tool for placing player spawn point
let playerSpawnTool = tiled.registerTool("PlacePlayerSpawnTool", {
    name: "Place Player Spawn",
    icon: "",
    usesSelectedTiles: false,

    activated: function() {
        this.statusInfo = "Click to place player spawn point (one per map)";
    },

    mousePressed: function(button, x, y, modifiers) {
        if (button !== Qt.LeftButton) return;

        let map = this.map;
        if (!map) return;

        let tileX = Math.floor(x / map.tileWidth) * map.tileWidth;
        let tileY = Math.floor(y / map.tileHeight) * map.tileHeight;

        // Find or create Spawns layer
        let spawnLayer = null;
        for (let i = 0; i < map.layerCount; i++) {
            let layer = map.layerAt(i);
            if (layer.name === "PlayerSpawn" && layer.isObjectLayer) {
                spawnLayer = layer;
                break;
            }
        }

        if (!spawnLayer) {
            spawnLayer = new ObjectGroup("PlayerSpawn");
            spawnLayer.color = "#0088ff";
            map.addLayer(spawnLayer);
        }

        // Remove existing player spawn (only one allowed)
        let existingSpawns = [];
        for (let obj of spawnLayer.objects) {
            if (obj.property("type") === "player_spawn") {
                existingSpawns.push(obj);
            }
        }
        for (let obj of existingSpawns) {
            spawnLayer.removeObject(obj);
        }

        let spawn = new MapObject("PlayerSpawn");
        spawn.x = tileX;
        spawn.y = tileY;
        spawn.width = map.tileWidth;
        spawn.height = map.tileHeight;
        spawn.shape = MapObject.Ellipse;

        spawn.setProperty("type", "player_spawn");
        spawn.setProperty("facing", "down");

        spawnLayer.addObject(spawn);

        this.statusInfo = "Player spawn set at tile (" +
            Math.floor(tileX / map.tileWidth) + ", " +
            Math.floor(tileY / map.tileHeight) + ")";
    }
});

// Add menu entries
tiled.extendMenu("Map", [
    { separator: true },
    { action: "CreateWarpLayer" },
    { action: "InsertWarp" }
]);

tiled.log("Golden Sun MMO Map Tools loaded!");
tiled.log("  - Place Warp: Click to place warp points");
tiled.log("  - Place NPC Spawn: Click to place NPC spawns");
tiled.log("  - Place Player Spawn: Click to set player spawn");
