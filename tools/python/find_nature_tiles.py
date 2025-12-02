"""
Scan through the Odyssey tileset to find grass, tree, and nature tiles
Creates a preview image showing different sections
"""

from PIL import Image, ImageDraw, ImageFont

TILE_SIZE = 32
TILES_PATH = "assets-odyssey/tiles_part1.png"

def create_tile_preview():
    """Create a preview showing tiles from different row ranges"""
    print("Loading tileset...")
    tileset = Image.open(TILES_PATH)

    width = tileset.width
    height = tileset.height
    cols = width // TILE_SIZE
    rows = height // TILE_SIZE

    print(f"Tileset: {width}x{height} ({cols} cols x {rows} rows)")
    print(f"Total tiles: {cols * rows}")

    # Create preview showing 10 tiles from various row sections
    preview_width = cols * TILE_SIZE * 2  # 2x scale for visibility
    preview_height = 20 * TILE_SIZE * 2  # Show 20 rows
    preview = Image.new("RGB", (preview_width, preview_height), (50, 50, 50))

    # Sample rows throughout the tileset
    sample_rows = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190]

    for i, row in enumerate(sample_rows):
        if row >= rows:
            break

        for col in range(cols):
            # Extract tile
            x = col * TILE_SIZE
            y = row * TILE_SIZE
            tile = tileset.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))

            # Paste at 2x scale
            tile_scaled = tile.resize((TILE_SIZE * 2, TILE_SIZE * 2), Image.NEAREST)
            paste_x = col * TILE_SIZE * 2
            paste_y = i * TILE_SIZE * 2
            preview.paste(tile_scaled, (paste_x, paste_y))

    # Save preview
    preview.save("assets/tile_preview.png")
    print("Preview saved: assets/tile_preview.png")
    print("Rows shown:", sample_rows[:i+1])

if __name__ == "__main__":
    create_tile_preview()
