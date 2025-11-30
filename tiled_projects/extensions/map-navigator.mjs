/// <reference types="@mapeditor/tiled-api" />

/*
 * Map Navigator for Golden Sun MMO - Tiled Extension
 *
 * Click on warp objects to instantly open the linked map!
 * Perfect for world-building and verifying map connections.
 *
 * Features:
 * - Double-click a warp to open the target map
 * - Automatically positions view at the arrival location
 * - Shows warp info in status bar on hover
 * - "Follow Warp" action in right-click menu
 *
 * Warp objects must have these properties:
 * - type: "warp"
 * - target_map: relative path to target TMX (e.g., "dungeon/cave.tmx")
 * - target_x: X tile coordinate in target map
 * - target_y: Y tile coordinate in target map
 */

// Store the base path for maps
let mapsBasePath = "";

// Action to follow a selected warp
let followWarpAction = tiled.registerAction("FollowWarp", function(action) {
    let map = tiled.activeAsset;
    if (!map || !map.isTileMap) {
        tiled.alert("Please open a map first.");
        return;
    }

    // Get selected objects
    let selectedObjects = map.selectedObjects;
    if (selectedObjects.length === 0) {
        tiled.alert("Please select a warp object first.\n\nWarp objects have:\n- type = 'warp'\n- target_map = path to destination");
        return;
    }

    // Find first warp in selection
    let warp = null;
    for (let obj of selectedObjects) {
        if (obj.property("type") === "warp") {
            warp = obj;
            break;
        }
    }

    if (!warp) {
        tiled.alert("Selected object is not a warp.\n\nWarp objects need property 'type' = 'warp'");
        return;
    }

    let targetMap = warp.property("target_map");
    if (!targetMap || targetMap === "") {
        tiled.alert("This warp has no target_map set!\n\nSet the 'target_map' property to the destination TMX path.");
        return;
    }

    // Resolve the path relative to current map
    let currentPath = map.fileName;
    let targetPath = resolveMapPath(currentPath, targetMap);

    tiled.log("Following warp to: " + targetPath);

    // Try to open the target map
    let targetAsset = tiled.open(targetPath);
    if (!targetAsset) {
        tiled.alert("Could not open target map:\n" + targetPath + "\n\nMake sure the file exists!");
        return;
    }

    // Center view on target coordinates
    let targetX = warp.property("target_x") || 0;
    let targetY = warp.property("target_y") || 0;

    // Convert tile coords to pixel coords
    let pixelX = targetX * targetAsset.tileWidth + targetAsset.tileWidth / 2;
    let pixelY = targetY * targetAsset.tileHeight + targetAsset.tileHeight / 2;

    // Try to center the view (this may not work in all Tiled versions)
    if (tiled.mapEditor && tiled.mapEditor.currentMapView) {
        tiled.mapEditor.currentMapView.centerOn(pixelX, pixelY);
    }

    tiled.log("Arrived at map: " + targetMap + " position: (" + targetX + ", " + targetY + ")");
});
followWarpAction.text = "Follow Warp";
followWarpAction.shortcut = "F";

// Action to go back to previous map
let mapHistory = [];
let currentMapIndex = -1;

let goBackAction = tiled.registerAction("GoBackMap", function(action) {
    if (currentMapIndex > 0) {
        currentMapIndex--;
        let prevPath = mapHistory[currentMapIndex];
        tiled.open(prevPath);
        tiled.log("Went back to: " + prevPath);
    } else {
        tiled.log("No previous map in history");
    }
});
goBackAction.text = "Go Back (Map History)";
goBackAction.shortcut = "Alt+Left";

// Action to list all warps in current map
let listWarpsAction = tiled.registerAction("ListWarps", function(action) {
    let map = tiled.activeAsset;
    if (!map || !map.isTileMap) {
        tiled.alert("Please open a map first.");
        return;
    }

    let warps = [];
    for (let i = 0; i < map.layerCount; i++) {
        let layer = map.layerAt(i);
        if (layer.isObjectLayer) {
            for (let obj of layer.objects) {
                if (obj.property("type") === "warp") {
                    warps.push({
                        name: obj.name,
                        x: Math.floor(obj.x / map.tileWidth),
                        y: Math.floor(obj.y / map.tileHeight),
                        target: obj.property("target_map") || "(not set)",
                        targetX: obj.property("target_x") || 0,
                        targetY: obj.property("target_y") || 0,
                        id: obj.property("warp_id") || 0
                    });
                }
            }
        }
    }

    if (warps.length === 0) {
        tiled.alert("No warps found in this map.\n\nUse 'Place Warp' tool to add warps.");
        return;
    }

    let msg = "Warps in " + map.fileName + ":\n\n";
    for (let w of warps) {
        msg += "• " + w.name + " (ID:" + w.id + ")\n";
        msg += "  At: (" + w.x + ", " + w.y + ")\n";
        msg += "  → " + w.target + " (" + w.targetX + ", " + w.targetY + ")\n\n";
    }

    tiled.alert(msg);
});
listWarpsAction.text = "List All Warps";
listWarpsAction.shortcut = "Ctrl+W";

// Action to create a return warp in target map
let createReturnWarpAction = tiled.registerAction("CreateReturnWarp", function(action) {
    let map = tiled.activeAsset;
    if (!map || !map.isTileMap) {
        tiled.alert("Please open a map first.");
        return;
    }

    let selectedObjects = map.selectedObjects;
    if (selectedObjects.length === 0) {
        tiled.alert("Please select a warp object first.");
        return;
    }

    let warp = null;
    for (let obj of selectedObjects) {
        if (obj.property("type") === "warp") {
            warp = obj;
            break;
        }
    }

    if (!warp) {
        tiled.alert("Selected object is not a warp.");
        return;
    }

    let targetMap = warp.property("target_map");
    if (!targetMap) {
        tiled.alert("This warp has no target_map set!");
        return;
    }

    // Store info for the return warp
    let returnInfo = {
        sourceMap: getRelativePath(map.fileName),
        sourceX: Math.floor(warp.x / map.tileWidth),
        sourceY: Math.floor(warp.y / map.tileHeight),
        sourceWarpId: warp.property("warp_id") || 0,
        targetX: warp.property("target_x") || 0,
        targetY: warp.property("target_y") || 0
    };

    // Open target map
    let currentPath = map.fileName;
    let targetPath = resolveMapPath(currentPath, targetMap);
    let targetAsset = tiled.open(targetPath);

    if (!targetAsset) {
        tiled.alert("Could not open target map: " + targetPath);
        return;
    }

    // Find or create Warps layer
    let warpsLayer = null;
    for (let i = 0; i < targetAsset.layerCount; i++) {
        let layer = targetAsset.layerAt(i);
        if (layer.name === "Warps" && layer.isObjectLayer) {
            warpsLayer = layer;
            break;
        }
    }

    if (!warpsLayer) {
        warpsLayer = new ObjectGroup("Warps");
        warpsLayer.color = "#ff00ff";
        targetAsset.addLayer(warpsLayer);
    }

    // Find highest warp ID in target map
    let maxId = 0;
    for (let obj of warpsLayer.objects) {
        let id = obj.property("warp_id");
        if (id && id > maxId) maxId = id;
    }

    // Create return warp
    let returnWarp = new MapObject("Return_" + (maxId + 1));
    returnWarp.x = returnInfo.targetX * targetAsset.tileWidth;
    returnWarp.y = returnInfo.targetY * targetAsset.tileHeight;
    returnWarp.width = targetAsset.tileWidth;
    returnWarp.height = targetAsset.tileHeight;
    returnWarp.shape = MapObject.Rectangle;

    returnWarp.setProperty("type", "warp");
    returnWarp.setProperty("target_map", returnInfo.sourceMap);
    returnWarp.setProperty("target_x", returnInfo.sourceX);
    returnWarp.setProperty("target_y", returnInfo.sourceY);
    returnWarp.setProperty("warp_id", maxId + 1);
    returnWarp.setProperty("trigger", "touch");

    warpsLayer.addObject(returnWarp);

    tiled.log("Created return warp in " + targetMap);
    tiled.alert("Return warp created!\n\nIn: " + targetMap + "\nAt: (" + returnInfo.targetX + ", " + returnInfo.targetY + ")\nLeads to: " + returnInfo.sourceMap);
});
createReturnWarpAction.text = "Create Return Warp in Target";
createReturnWarpAction.shortcut = "Ctrl+R";

// Warp navigation tool - double-click to follow warps
let warpNavigatorTool = tiled.registerTool("WarpNavigator", {
    name: "Warp Navigator",
    icon: "",
    usesSelectedTiles: false,

    activated: function() {
        this.statusInfo = "Double-click a warp to follow it | Single-click to select";
        this.hoveredWarp = null;
    },

    deactivated: function() {
        this.hoveredWarp = null;
    },

    mouseMoved: function(x, y, modifiers) {
        let map = this.map;
        if (!map) return;

        // Find warp under cursor
        let warp = this.findWarpAt(x, y);

        if (warp) {
            let target = warp.property("target_map") || "(not set)";
            let tx = warp.property("target_x") || 0;
            let ty = warp.property("target_y") || 0;
            this.statusInfo = "Warp: " + warp.name + " → " + target + " (" + tx + ", " + ty + ") | Double-click to follow";
            this.hoveredWarp = warp;
        } else {
            this.statusInfo = "Double-click a warp to follow it | Single-click to select";
            this.hoveredWarp = null;
        }
    },

    mouseDoubleClicked: function(button, x, y, modifiers) {
        if (button !== Qt.LeftButton) return;

        let warp = this.findWarpAt(x, y);
        if (!warp) {
            this.statusInfo = "No warp here - double-click on a warp object";
            return;
        }

        let targetMap = warp.property("target_map");
        if (!targetMap || targetMap === "") {
            this.statusInfo = "This warp has no target_map set!";
            return;
        }

        // Follow the warp
        let currentPath = this.map.fileName;
        let targetPath = resolveMapPath(currentPath, targetMap);

        // Add to history
        if (mapHistory.length === 0 || mapHistory[mapHistory.length - 1] !== currentPath) {
            mapHistory.push(currentPath);
            currentMapIndex = mapHistory.length - 1;
        }

        tiled.log("Following warp to: " + targetPath);
        let targetAsset = tiled.open(targetPath);

        if (targetAsset) {
            mapHistory.push(targetPath);
            currentMapIndex = mapHistory.length - 1;

            // Try to center on arrival point
            let tx = warp.property("target_x") || 0;
            let ty = warp.property("target_y") || 0;
            this.statusInfo = "Arrived at " + targetMap + " (" + tx + ", " + ty + ")";
        } else {
            this.statusInfo = "Could not open: " + targetPath;
        }
    },

    mousePressed: function(button, x, y, modifiers) {
        if (button !== Qt.LeftButton) return;

        let warp = this.findWarpAt(x, y);
        if (warp) {
            // Select the warp
            this.map.selectedObjects = [warp];
        }
    },

    findWarpAt: function(x, y) {
        let map = this.map;
        if (!map) return null;

        for (let i = 0; i < map.layerCount; i++) {
            let layer = map.layerAt(i);
            if (!layer.isObjectLayer) continue;

            for (let obj of layer.objects) {
                if (obj.property("type") !== "warp") continue;

                // Check if point is inside object bounds
                let ox = obj.x;
                let oy = obj.y;
                let ow = obj.width || map.tileWidth;
                let oh = obj.height || map.tileHeight;

                if (x >= ox && x <= ox + ow && y >= oy && y <= oy + oh) {
                    return obj;
                }
            }
        }

        return null;
    }
});

// Helper to resolve relative map paths
function resolveMapPath(currentMapPath, relativePath) {
    // Get directory of current map
    let lastSlash = Math.max(currentMapPath.lastIndexOf('/'), currentMapPath.lastIndexOf('\\'));
    let currentDir = currentMapPath.substring(0, lastSlash + 1);

    // Handle ../ in relative path
    let targetPath = relativePath;
    while (targetPath.startsWith("../")) {
        targetPath = targetPath.substring(3);
        lastSlash = Math.max(currentDir.lastIndexOf('/', currentDir.length - 2), currentDir.lastIndexOf('\\', currentDir.length - 2));
        currentDir = currentDir.substring(0, lastSlash + 1);
    }

    return currentDir + targetPath;
}

// Helper to get relative path from absolute
function getRelativePath(absolutePath) {
    // Try to find "maps/" in path and return everything after
    let mapsIndex = absolutePath.indexOf("maps/");
    if (mapsIndex === -1) mapsIndex = absolutePath.indexOf("maps\\");

    if (mapsIndex !== -1) {
        return absolutePath.substring(mapsIndex + 5);
    }

    // Fallback: just return filename
    let lastSlash = Math.max(absolutePath.lastIndexOf('/'), absolutePath.lastIndexOf('\\'));
    return absolutePath.substring(lastSlash + 1);
}

// Add menu entries
tiled.extendMenu("Map", [
    { separator: true },
    { action: "FollowWarp" },
    { action: "GoBackMap" },
    { action: "ListWarps" },
    { action: "CreateReturnWarp" }
]);

tiled.log("=== Map Navigator Extension Loaded ===");
tiled.log("Tools:");
tiled.log("  - Warp Navigator: Double-click warps to follow them");
tiled.log("Actions:");
tiled.log("  - F: Follow selected warp");
tiled.log("  - Alt+Left: Go back in map history");
tiled.log("  - Ctrl+W: List all warps in current map");
tiled.log("  - Ctrl+R: Create return warp in target map");
