/// <reference types="@mapeditor/tiled-api" />

/*
 * Stamp Only Tool for Tiled
 *
 * This tool makes left-click ONLY place/paint tiles.
 * - Left click: Place tiles (stamp brush behavior)
 * - Left click + drag: Paint tiles continuously
 * - Right click: Pick tile under cursor
 * - Ctrl + Right click + drag: Rectangle select
 *
 * Prevents accidental selection mode activation from left-click dragging.
 */

let startX = -1;
let startY = -1;
let isPainting = false;
let isSelecting = false;
let previewMap = null;

const stampOnlyTool = tiled.registerTool("StampOnlyTool", {
    name: "Stamp Only (Left=Paint)",
    icon: "", // Uses default icon
    usesSelectedTiles: true,

    activated: function() {
        this.statusInfo = "Left-click to paint tiles | Right-click to pick | Ctrl+Right-drag to select";
    },

    deactivated: function() {
        isPainting = false;
        isSelecting = false;
        if (previewMap) {
            previewMap = null;
        }
    },

    mousePressed: function(button, x, y, modifiers) {
        const tileX = Math.floor(x / this.map.tileWidth);
        const tileY = Math.floor(y / this.map.tileHeight);

        // Left button - always paint/stamp
        if (button === Qt.LeftButton) {
            isPainting = true;
            startX = tileX;
            startY = tileY;
            this.paintTile(tileX, tileY);
        }
        // Right button - pick tile or start selection if Ctrl held
        else if (button === Qt.RightButton) {
            if (modifiers & Qt.ControlModifier) {
                // Ctrl+Right click starts rectangle selection
                isSelecting = true;
                startX = tileX;
                startY = tileY;
                this.statusInfo = "Selecting... release to confirm";
            } else {
                // Plain right click picks tile under cursor
                this.pickTileAt(tileX, tileY);
            }
        }
    },

    mouseReleased: function(button, x, y, modifiers) {
        const tileX = Math.floor(x / this.map.tileWidth);
        const tileY = Math.floor(y / this.map.tileHeight);

        if (button === Qt.LeftButton && isPainting) {
            isPainting = false;
            this.statusInfo = "Left-click to paint tiles | Right-click to pick | Ctrl+Right-drag to select";
        }
        else if (button === Qt.RightButton && isSelecting) {
            isSelecting = false;
            // Perform rectangle selection
            this.selectRectangle(startX, startY, tileX, tileY);
            this.statusInfo = "Left-click to paint tiles | Right-click to pick | Ctrl+Right-drag to select";
        }
    },

    tilePositionChanged: function(tileX, tileY) {
        if (isPainting) {
            this.paintTile(tileX, tileY);
        }
        if (isSelecting) {
            this.statusInfo = `Selecting from (${startX}, ${startY}) to (${tileX}, ${tileY})`;
        }
    },

    paintTile: function(tileX, tileY) {
        const brush = tiled.mapEditor.currentBrush;
        if (!brush || brush.layerCount === 0) {
            return;
        }

        const currentLayer = this.map.currentLayer;
        if (!currentLayer || !currentLayer.isTileLayer) {
            this.statusInfo = "Select a tile layer to paint on";
            return;
        }

        // Get the brush layer
        const brushLayer = brush.layerAt(0);
        if (!brushLayer || !brushLayer.isTileLayer) {
            return;
        }

        // Create an edit for the tile layer
        const edit = currentLayer.edit();

        // Paint each tile from the brush
        const brushWidth = brushLayer.width;
        const brushHeight = brushLayer.height;

        for (let by = 0; by < brushHeight; by++) {
            for (let bx = 0; bx < brushWidth; bx++) {
                const tile = brushLayer.tileAt(bx, by);
                if (tile) {
                    edit.setTile(tileX + bx, tileY + by, tile);
                }
            }
        }

        edit.apply();
    },

    pickTileAt: function(tileX, tileY) {
        const currentLayer = this.map.currentLayer;
        if (!currentLayer || !currentLayer.isTileLayer) {
            this.statusInfo = "Select a tile layer to pick from";
            return;
        }

        const tile = currentLayer.tileAt(tileX, tileY);
        if (tile) {
            // Create a new brush with just this tile
            const newBrush = new TileMap();
            newBrush.setTileSize(this.map.tileWidth, this.map.tileHeight);
            newBrush.setSize(1, 1);

            const layer = new TileLayer();
            layer.width = 1;
            layer.height = 1;

            const edit = layer.edit();
            edit.setTile(0, 0, tile);
            edit.apply();

            newBrush.addLayer(layer);
            tiled.mapEditor.currentBrush = newBrush;

            this.statusInfo = "Picked tile: " + tile.id;
        } else {
            this.statusInfo = "No tile at this position";
        }
    },

    selectRectangle: function(x1, y1, x2, y2) {
        const currentLayer = this.map.currentLayer;
        if (!currentLayer || !currentLayer.isTileLayer) {
            this.statusInfo = "Select a tile layer to copy from";
            return;
        }

        // Normalize coordinates
        const minX = Math.min(x1, x2);
        const maxX = Math.max(x1, x2);
        const minY = Math.min(y1, y2);
        const maxY = Math.max(y1, y2);

        const width = maxX - minX + 1;
        const height = maxY - minY + 1;

        // Create a brush from the selected area
        const newBrush = new TileMap();
        newBrush.setTileSize(this.map.tileWidth, this.map.tileHeight);
        newBrush.setSize(width, height);

        const layer = new TileLayer();
        layer.width = width;
        layer.height = height;

        const edit = layer.edit();

        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const tile = currentLayer.tileAt(minX + x, minY + y);
                if (tile) {
                    edit.setTile(x, y, tile);
                }
            }
        }

        edit.apply();
        newBrush.addLayer(layer);
        tiled.mapEditor.currentBrush = newBrush;

        this.statusInfo = `Selected ${width}x${height} area as brush`;
    }
});
