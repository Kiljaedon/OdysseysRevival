#!/usr/bin/env python3
"""
Improved Odyssey Sprite Sheet Splicer
Handles the specific format of Odyssey sprite sheets with different detection logic.
"""

import os
from PIL import Image
import argparse

def is_black_pixel(pixel, threshold=30):
    """Check if a pixel is considered black."""
    if isinstance(pixel, (list, tuple)):
        return all(c <= threshold for c in pixel[:3])
    return pixel <= threshold

def find_sprite_grid(image, min_sprite_size=8):
    """
    Find sprites by detecting non-black rectangular regions.
    """
    width, height = image.size
    print(f"Analyzing image {width}x{height}")

    # Convert to RGB if needed
    if image.mode != 'RGB':
        image = image.convert('RGB')

    sprites = []
    visited = [[False for _ in range(width)] for _ in range(height)]

    def flood_fill_bounds(start_x, start_y):
        """Find the bounding box of a connected non-black region."""
        stack = [(start_x, start_y)]
        min_x = max_x = start_x
        min_y = max_y = start_y

        while stack:
            x, y = stack.pop()
            if x < 0 or x >= width or y < 0 or y >= height or visited[y][x]:
                continue

            pixel = image.getpixel((x, y))
            if is_black_pixel(pixel):
                continue

            visited[y][x] = True
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)

            # Add neighbors
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                stack.append((x + dx, y + dy))

        return min_x, min_y, max_x - min_x + 1, max_y - min_y + 1

    # Scan for sprites
    sprite_id = 0
    for y in range(0, height, 2):  # Skip every other row for performance
        for x in range(0, width, 2):  # Skip every other column for performance
            if not visited[y][x]:
                pixel = image.getpixel((x, y))
                if not is_black_pixel(pixel):
                    # Found a non-black pixel, find the sprite bounds
                    sprite_x, sprite_y, sprite_w, sprite_h = flood_fill_bounds(x, y)

                    if sprite_w >= min_sprite_size and sprite_h >= min_sprite_size:
                        sprites.append({
                            'id': sprite_id,
                            'rect': (sprite_x, sprite_y, sprite_w, sprite_h),
                            'grid_pos': (len(sprites) % 16, len(sprites) // 16)  # Estimated grid
                        })
                        sprite_id += 1
                        print(f"Found sprite {sprite_id}: {sprite_w}x{sprite_h} at ({sprite_x}, {sprite_y})")

    return sprites

def extract_simple_grid(image, tile_width=16, tile_height=16):
    """
    Extract sprites assuming a simple grid layout.
    """
    width, height = image.size
    sprites = []
    sprite_id = 0

    cols = width // tile_width
    rows = height // tile_height

    print(f"Extracting {cols}x{rows} grid of {tile_width}x{tile_height} tiles")

    for row in range(rows):
        for col in range(cols):
            x = col * tile_width
            y = row * tile_height

            # Check if this tile has non-black content
            tile_region = image.crop((x, y, x + tile_width, y + tile_height))
            has_content = False

            # Sample a few pixels to check for content
            for check_y in range(0, tile_height, 4):
                for check_x in range(0, tile_width, 4):
                    if check_x < tile_width and check_y < tile_height:
                        pixel = tile_region.getpixel((check_x, check_y))
                        if not is_black_pixel(pixel):
                            has_content = True
                            break
                if has_content:
                    break

            if has_content:
                sprites.append({
                    'id': sprite_id,
                    'rect': (x, y, tile_width, tile_height),
                    'grid_pos': (col, row),
                    'tile_image': tile_region
                })
                sprite_id += 1

    print(f"Found {len(sprites)} non-empty tiles")
    return sprites

def extract_sprites(input_path, output_dir, prefix="sprite", method="grid", tile_size=16):
    """Extract all sprites from the input image."""
    print(f"Loading image: {input_path}")
    image = Image.open(input_path)

    print(f"Image size: {image.size}")
    print(f"Image mode: {image.mode}")

    # Choose extraction method
    if method == "flood":
        sprites = find_sprite_grid(image)
    else:  # grid method
        sprites = extract_simple_grid(image, tile_size, tile_size)

    print(f"Found {len(sprites)} sprites")

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Extract each sprite
    for sprite in sprites:
        sprite_id = sprite['id']
        grid_x, grid_y = sprite['grid_pos']

        if 'tile_image' in sprite:
            # Already cropped
            sprite_image = sprite['tile_image']
        else:
            # Need to crop
            x, y, w, h = sprite['rect']
            sprite_image = image.crop((x, y, x + w, y + h))

        # Save with descriptive filename
        filename = f"{prefix}_{grid_x:02d}_{grid_y:02d}_{sprite_id:04d}.png"
        output_path = os.path.join(output_dir, filename)
        sprite_image.save(output_path)

        if sprite_id < 10:  # Show first few
            w, h = sprite_image.size
            print(f"Extracted sprite {sprite_id}: {w}x{h} at grid ({grid_x}, {grid_y}) -> {filename}")

    return len(sprites)

def main():
    parser = argparse.ArgumentParser(description='Extract sprites from Odyssey sprite sheets')
    parser.add_argument('input', help='Input BMP file path')
    parser.add_argument('output', help='Output directory path')
    parser.add_argument('--prefix', default='sprite', help='Output filename prefix')
    parser.add_argument('--method', choices=['grid', 'flood'], default='grid', help='Extraction method')
    parser.add_argument('--tile-size', type=int, default=16, help='Tile size for grid method')

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found")
        return 1

    try:
        count = extract_sprites(args.input, args.output, args.prefix, args.method, args.tile_size)
        print(f"\nSuccess! Extracted {count} sprites to '{args.output}'")
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())