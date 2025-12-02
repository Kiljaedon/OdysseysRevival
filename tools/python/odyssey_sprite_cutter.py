#!/usr/bin/env python3
"""
Perfect Odyssey Sprite Cutter
Cuts sprites using the exact dimensions found: 384x20608 = 12 columns x 32px sprites
"""

import os
from PIL import Image

def cut_odyssey_sprites():
    # Use split sprite files
    sprite_files = [
        "assets-odyssey/sprites_part1.png",
        "assets-odyssey/sprites_part2.png"
    ]
    output_dir = "cut_sprites"

    # Create output directory
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print(f"=== ODYSSEY SPRITE CUTTER ===")
    print(f"Processing {len(sprite_files)} sprite sheet parts")

    # Process each sprite sheet part
    total_count = 0
    character_sprites = 0

    for part_idx, sprite_path in enumerate(sprite_files):
        if not os.path.exists(sprite_path):
            print(f"WARNING: Sprite file not found: {sprite_path}")
            continue

        # Load the image
        img = Image.open(sprite_path)
        width, height = img.size

        print(f"\nPart {part_idx + 1}: {width} x {height}")

        # PERFECT FIT: 12 columns of 32px sprites
        sprite_width = 32
        sprite_height = 32
        cols = 12

        # Verify this matches our image
        expected_width = cols * sprite_width
        if width != expected_width:
            print(f"WARNING: Width mismatch. Expected {expected_width}, got {width}")
            print(f"Adjusting sprite width to {width/cols:.1f}px")
            sprite_width = width // cols

        rows = height // sprite_height
        # Calculate global row offset based on part index
        row_offset = part_idx * 512  # Each part has max 512 rows

        print(f"Grid: {cols} columns x {rows} rows (starting at global row {row_offset})")
        print(f"Sprite size: {sprite_width} x {sprite_height}")

        # Cut each sprite
        for row in range(rows):
            global_row = row_offset + row  # Global row number across all parts

            for col in range(cols):
                x = col * sprite_width
                y = row * sprite_height

                # Extract sprite
                sprite_box = (x, y, x + sprite_width, y + sprite_height)
                sprite = img.crop(sprite_box)

                # Save sprite with global row number
                filename = f"{output_dir}/sprite_{total_count:04d}_r{global_row:03d}_c{col:02d}.png"
                sprite.save(filename)

                total_count += 1

                # First 200 rows are characters
                if global_row < 200:
                    character_sprites += 1

                # Progress update
                if total_count % 500 == 0:
                    print(f"  Cut {total_count} sprites...")

    print(f"\n=== CUTTING COMPLETE ===")
    print(f"Total sprites cut: {total_count}")
    print(f"Character sprites (first 200 rows): {character_sprites}")
    print(f"Map tiles/other: {total_count - character_sprites}")
    print(f"Output directory: {output_dir}/")

    # Create character-only subset (first 200 rows only)
    char_dir = "character_sprites"
    if not os.path.exists(char_dir):
        os.makedirs(char_dir)

    char_count = 0
    CHARACTER_ROWS = 200  # Only first 200 rows are characters
    cols = 12  # Define cols for character subset loop

    for row in range(CHARACTER_ROWS):  # Only character rows
        for col in range(cols):
            source = f"{output_dir}/sprite_{row * cols + col:04d}_r{row:03d}_c{col:02d}.png"
            dest = f"{char_dir}/char_{char_count:04d}_r{row:03d}_c{col:02d}.png"

            if os.path.exists(source):
                sprite = Image.open(source)
                sprite.save(dest)
                char_count += 1

    print(f"Character subset: {char_count} sprites in {char_dir}/")

if __name__ == "__main__":
    cut_odyssey_sprites()