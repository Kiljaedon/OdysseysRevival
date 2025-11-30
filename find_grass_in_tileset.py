"""
Find the green grass tiles by color matching
"""

from PIL import Image
import colorsys

TILE_SIZE = 32
TILES_PATH = "assets-odyssey/tiles_part1.png"

def is_grass_tile(tile_img):
    """Check if a tile is green grass by analyzing colors"""
    pixels = tile_img.getdata()

    green_count = 0
    total_pixels = 0

    for pixel in pixels:
        if len(pixel) >= 3:  # RGB or RGBA
            r, g, b = pixel[0], pixel[1], pixel[2]

            # Check if pixel is green-ish (g > r and g > b)
            if g > r and g > b and g > 50:
                green_count += 1
            total_pixels += 1

    # If more than 50% of pixels are green, it's likely grass
    if total_pixels > 0:
        green_ratio = green_count / total_pixels
        return green_ratio > 0.5
    return False

def find_grass_tiles():
    """Scan tileset for grass tiles"""
    print("Loading tileset...")
    tileset = Image.open(TILES_PATH)

    width = tileset.width
    height = tileset.height
    cols = width // TILE_SIZE
    rows = height // TILE_SIZE

    print(f"Scanning {cols}x{rows} tiles...")

    grass_tiles = []

    for row in range(min(rows, 200)):  # Check first 200 rows
        for col in range(cols):
            x = col * TILE_SIZE
            y = row * TILE_SIZE
            tile = tileset.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))

            if is_grass_tile(tile):
                grass_tiles.append((row, col))

    print(f"\nFound {len(grass_tiles)} grass tiles:")
    for row, col in grass_tiles[:20]:  # Show first 20
        print(f"  Row {row}, Col {col}")

    return grass_tiles

if __name__ == "__main__":
    find_grass_tiles()
