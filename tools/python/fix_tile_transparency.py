#!/usr/bin/env python3
"""
Fix Odyssey tiles transparency - convert black background to transparent
"""

import os
from PIL import Image

def make_black_transparent(input_path, output_path):
    """Convert black pixels to transparent in PNG"""
    print(f"Loading: {input_path}")
    img = Image.open(input_path)

    # Convert to RGBA if not already
    img = img.convert("RGBA")

    # Get pixel data
    pixels = img.load()
    width, height = img.size

    print(f"Processing {width}x{height} pixels...")

    # Convert black (or near-black) to transparent
    black_threshold = 10  # Tolerance for "black" (0-255)
    transparent_count = 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            # If pixel is black or near-black, make it transparent
            if r < black_threshold and g < black_threshold and b < black_threshold:
                pixels[x, y] = (0, 0, 0, 0)  # Fully transparent
                transparent_count += 1

        # Progress update
        if y % 1000 == 0:
            print(f"  Processed {y}/{height} rows...")

    print(f"Converted {transparent_count} black pixels to transparent")
    print(f"Saving: {output_path}")
    img.save(output_path, "PNG")
    print("Done!")

if __name__ == "__main__":
    # Process tiles
    print("=== Processing TILES ===")
    tiles_input = "assets-odyssey/tiles_original.png"
    tiles_output = "assets-odyssey/tiles.png"

    # Backup original if exists
    if os.path.exists(tiles_output) and not os.path.exists(tiles_input):
        print("Backing up original tiles.png...")
        os.rename(tiles_output, tiles_input)

    if os.path.exists(tiles_input):
        make_black_transparent(tiles_input, tiles_output)
    else:
        print(f"ERROR: {tiles_input} not found!")

    # Process sprites
    print("\n=== Processing SPRITES ===")
    sprites_input = "assets-odyssey/sprites_original.png"
    sprites_output = "assets-odyssey/sprites.png"

    # Backup original if exists
    if os.path.exists(sprites_output) and not os.path.exists(sprites_input):
        print("Backing up original sprites.png...")
        os.rename(sprites_output, sprites_input)

    if os.path.exists(sprites_input):
        make_black_transparent(sprites_input, sprites_output)
    else:
        print(f"ERROR: {sprites_input} not found!")
        print("Sprites already processed or not found")