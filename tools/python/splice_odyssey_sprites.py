#!/usr/bin/env python3
"""
Odyssey Sprite Sheet Splicer
Automatically extracts individual sprites and tiles from the Odyssey BMP files
based on black background separators.
"""

import os
from PIL import Image
import argparse

def find_sprite_boundaries(image, black_threshold=10):
    """
    Find sprite boundaries by detecting black separator lines.
    Returns list of (x, y, width, height) rectangles.
    """
    width, height = image.size
    sprites = []

    # Convert to RGB if needed
    if image.mode != 'RGB':
        image = image.convert('RGB')

    # Find horizontal separator lines (black rows)
    horizontal_separators = []
    for y in range(height):
        is_separator = True
        for x in range(width):
            r, g, b = image.getpixel((x, y))
            if r > black_threshold or g > black_threshold or b > black_threshold:
                is_separator = False
                break
        if is_separator:
            horizontal_separators.append(y)

    # Find vertical separator lines (black columns)
    vertical_separators = []
    for x in range(width):
        is_separator = True
        for y in range(height):
            r, g, b = image.getpixel((x, y))
            if r > black_threshold or g > black_threshold or b > black_threshold:
                is_separator = False
                break
        if is_separator:
            vertical_separators.append(x)

    print(f"Found {len(horizontal_separators)} horizontal separators")
    print(f"Found {len(vertical_separators)} vertical separators")

    # Group consecutive separators
    h_groups = group_consecutive(horizontal_separators)
    v_groups = group_consecutive(vertical_separators)

    # Create sprite rectangles
    sprite_id = 0
    for i in range(len(h_groups) - 1):
        for j in range(len(v_groups) - 1):
            x1 = v_groups[j][-1] + 1  # After vertical separator
            y1 = h_groups[i][-1] + 1  # After horizontal separator
            x2 = v_groups[j + 1][0] - 1  # Before next vertical separator
            y2 = h_groups[i + 1][0] - 1  # Before next horizontal separator

            if x2 > x1 and y2 > y1:  # Valid rectangle
                sprites.append({
                    'id': sprite_id,
                    'rect': (x1, y1, x2 - x1, y2 - y1),
                    'grid_pos': (j, i)
                })
                sprite_id += 1

    return sprites

def group_consecutive(numbers):
    """Group consecutive numbers together."""
    if not numbers:
        return []

    groups = []
    current_group = [numbers[0]]

    for i in range(1, len(numbers)):
        if numbers[i] == numbers[i-1] + 1:
            current_group.append(numbers[i])
        else:
            groups.append(current_group)
            current_group = [numbers[i]]

    groups.append(current_group)
    return groups

def extract_sprites(input_path, output_dir, prefix="sprite"):
    """Extract all sprites from the input image."""
    print(f"Loading image: {input_path}")
    image = Image.open(input_path)

    print(f"Image size: {image.size}")
    print(f"Image mode: {image.mode}")

    # Find sprite boundaries
    sprites = find_sprite_boundaries(image)

    print(f"Found {len(sprites)} sprites")

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Extract each sprite
    for sprite in sprites:
        sprite_id = sprite['id']
        x, y, w, h = sprite['rect']
        grid_x, grid_y = sprite['grid_pos']

        # Extract sprite region
        sprite_image = image.crop((x, y, x + w, y + h))

        # Save with descriptive filename
        filename = f"{prefix}_{grid_x:02d}_{grid_y:02d}_{sprite_id:03d}.png"
        output_path = os.path.join(output_dir, filename)
        sprite_image.save(output_path)

        print(f"Extracted sprite {sprite_id}: {w}x{h} at grid ({grid_x}, {grid_y}) -> {filename}")

    return len(sprites)

def main():
    parser = argparse.ArgumentParser(description='Extract sprites from Odyssey sprite sheets')
    parser.add_argument('input', help='Input BMP file path')
    parser.add_argument('output', help='Output directory path')
    parser.add_argument('--prefix', default='sprite', help='Output filename prefix')
    parser.add_argument('--threshold', type=int, default=10, help='Black threshold (0-255)')

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found")
        return 1

    try:
        count = extract_sprites(args.input, args.output, args.prefix)
        print(f"\nSuccess! Extracted {count} sprites to '{args.output}'")
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())