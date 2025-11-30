/// <reference types="@mapeditor/tiled-api" />

/*
 * No Left-Click Select Tool for Tiled
 *
 * A simpler approach: This tool works like the stamp brush but
 * completely ignores left-click drag selection behavior.
 *
 * Controls:
 * - Left click/drag: Paint with current brush (no selection)
 * - Right click: Pick tile under cursor
 * - Shift + Right click drag: Rectangle select and copy to brush
 *
 * Install: Copy to your Tiled extensions folder
 * (Edit > Preferences > Plugins > Open)
 */

let painting = false;
let selecting = false;
let selectStartX = 0;
let selectStartY = 0;

tiled.registerTool("NoLeftSelectStamp", {
    name: "Paint Only",
    icon: "",
    usesSelectedTiles: true,

    activated() {
        this.statusInfo = "LMB: Paint | RMB: Pick tile | Shift+RMB drag: Select area";
    },

    deactivated() {
        painting = false;
        selecting = false;
    },

    mousePressed(button, x, y, modifiers) {
        const tx = this.tilePosition.x;
        const ty = this.tilePosition.y;

        if (button === Qt.LeftButton) {
            // Left click always paints - never selects
            painting = true;
            this.stamp(tx, ty);
        }
        else if (button === Qt.RightButton) {
            if (modifiers & Qt.ShiftModifier) {
                // Shift + Right = start selection
                selecting = true;
                selectStartX = tx;
                selectStartY = ty;
                this.statusInfo = "Drag to select area...";
            } else {
                // Plain right click = pick tile
                this.pick(tx, ty);
            }
        }
    },

    mouseReleased(button, x, y, modifiers) {
        if (button === Qt.LeftButton) {
            painting = false;
        }
        else if (button === Qt.RightButton && selecting) {
            selecting = false;
            const tx = this.tilePosition.x;
            const ty = this.tilePosition.y;
            this.copyAreaToBrush(selectStartX, selectStartY, tx, ty);
            this.statusInfo = "LMB: Paint | RMB: Pick tile | Shift+RMB drag: Select area";
        }
    },

    tilePositionChanged(tx, ty) {
        if (painting) {
            this.stamp(tx, ty);
        }
        else if (selecting) {
            const w = Math.abs(tx - selectStartX) + 1;
            const h = Math.abs(ty - selectStartY) + 1;
            this.statusInfo = `Selecting ${w}x${h} area...`;
        }
    },

    stamp(tx, ty) {
        const brush = tiled.mapEditor.currentBrush;
        if (!brush || brush.layerCount === 0) return;

        const layer = this.map.currentLayer;
        if (!layer || !layer.isTileLayer) {
            this.statusInfo = "Select a tile layer first";
            return;
        }

        const brushLayer = brush.layerAt(0);
        if (!brushLayer || !brushLayer.isTileLayer) return;

        const edit = layer.edit();

        for (let by = 0; by < brushLayer.height; by++) {
            for (let bx = 0; bx < brushLayer.width; bx++) {
                const tile = brushLayer.tileAt(bx, by);
                if (tile) {
                    edit.setTile(tx + bx, ty + by, tile);
                }
            }
        }

        edit.apply();
    },

    pick(tx, ty) {
        const layer = this.map.currentLayer;
        if (!layer || !layer.isTileLayer) {
            this.statusInfo = "Select a tile layer first";
            return;
        }

        const tile = layer.tileAt(tx, ty);
        if (!tile) {
            this.statusInfo = "No tile here";
            return;
        }

        // Create single-tile brush
        const newBrush = new TileMap();
        newBrush.setTileSize(this.map.tileWidth, this.map.tileHeight);
        newBrush.setSize(1, 1);

        const newLayer = new TileLayer();
        newLayer.width = 1;
        newLayer.height = 1;

        const edit = newLayer.edit();
        edit.setTile(0, 0, tile);
        edit.apply();

        newBrush.addLayer(newLayer);
        tiled.mapEditor.currentBrush = newBrush;

        this.statusInfo = "Picked tile #" + tile.id;
    },

    copyAreaToBrush(x1, y1, x2, y2) {
        const layer = this.map.currentLayer;
        if (!layer || !layer.isTileLayer) {
            this.statusInfo = "Select a tile layer first";
            return;
        }

        const minX = Math.min(x1, x2);
        const maxX = Math.max(x1, x2);
        const minY = Math.min(y1, y2);
        const maxY = Math.max(y1, y2);
        const w = maxX - minX + 1;
        const h = maxY - minY + 1;

        const newBrush = new TileMap();
        newBrush.setTileSize(this.map.tileWidth, this.map.tileHeight);
        newBrush.setSize(w, h);

        const newLayer = new TileLayer();
        newLayer.width = w;
        newLayer.height = h;

        const edit = newLayer.edit();

        let count = 0;
        for (let dy = 0; dy < h; dy++) {
            for (let dx = 0; dx < w; dx++) {
                const tile = layer.tileAt(minX + dx, minY + dy);
                if (tile) {
                    edit.setTile(dx, dy, tile);
                    count++;
                }
            }
        }

        edit.apply();
        newBrush.addLayer(newLayer);
        tiled.mapEditor.currentBrush = newBrush;

        this.statusInfo = `Copied ${w}x${h} area (${count} tiles) to brush`;
    }
});

tiled.log("Paint Only tool loaded - use it to avoid accidental selections!");
