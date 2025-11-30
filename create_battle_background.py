"""
Create a battle background by compositing Odyssey tiles
Generates a grassy field with decorative elements
"""

from PIL import Image
import random

# Tile configuration
TILE_SIZE = 32
TILES_PATH = "assets-odyssey/tiles_part1.png"
OUTPUT_PATH = "assets/battle_backgrounds/grassy_field.png"

# Background dimensions (matching battle window)
BG_WIDTH = 1280
BG_HEIGHT = 720
TILES_WIDE = BG_WIDTH // TILE_SIZE  # 40 tiles
TILES_HIGH = BG_HEIGHT // TILE_SIZE  # 22 tiles

# Tile coordinates (row, col) from the tileset
# Found via color analysis: Row 81 = green grass tiles
# Tileset is 7 columns wide (cols 0-6)
GRASS_TILES = [
    (81, 0),   # Green grass from row 81 - only these are solid green
    (81, 1),
    (81, 2),
    (81, 3),
]

DECORATION_TILES = [
    (55, 3),   # Small plants/decorations
    (55, 4),
    (55, 5),
    (61, 1),
]

def get_tile(tileset_img, row, col):
    """Extract a single tile from the tileset"""
    x = col * TILE_SIZE
    y = row * TILE_SIZE
    return tileset_img.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))

def create_battle_background():
    """Create a grassy field battle background"""
    print("Loading tileset...")
    tileset = Image.open(TILES_PATH)

    print(f"Creating {BG_WIDTH}x{BG_HEIGHT} background...")
    background = Image.new("RGBA", (BG_WIDTH, BG_HEIGHT), (0, 0, 0, 0))

    # Layer 1: Fill with grass tiles
    print("Laying grass tiles...")
    for y in range(TILES_HIGH):
        for x in range(TILES_WIDE):
            # Pick a random grass tile
            grass_coord = random.choice(GRASS_TILES)
            tile = get_tile(tileset, grass_coord[0], grass_coord[1])
            background.paste(tile, (x * TILE_SIZE, y * TILE_SIZE))

    # Layer 2: Add random decorations (plants, flowers, rocks)
    print("Adding decorations...")
    num_decorations = 0  # DISABLED - decoration tiles had transparency issues
    for _ in range(num_decorations):
        x = random.randint(0, TILES_WIDE - 1)
        y = random.randint(0, TILES_HIGH - 1)

        # Pick a random decoration
        deco_coord = random.choice(DECORATION_TILES)
        tile = get_tile(tileset, deco_coord[0], deco_coord[1])

        # Paste decoration
        background.paste(tile, (x * TILE_SIZE, y * TILE_SIZE), tile)

    # Save background
    print(f"Saving to {OUTPUT_PATH}...")
    import os
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    background.save(OUTPUT_PATH, "PNG")

    print(f"✓ Battle background created: {OUTPUT_PATH}")
    print(f"  Size: {BG_WIDTH}x{BG_HEIGHT} ({TILES_WIDE}x{TILES_HIGH} tiles)")

if __name__ == "__main__":
    random.seed(42)  # Consistent output
    create_battle_background()
