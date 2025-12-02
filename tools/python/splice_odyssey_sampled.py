#!/usr/bin/env python3
"""
Efficient Odyssey Sprite Sheet Splicer using sampling
Reduces CPU load by sampling every nth pixel instead of checking all pixels.
"""

import os
from PIL import Image
import argparse

def find_sprite_boundaries_sampled(image, black_threshold=10, sample_rate=4):
    """
    Find sprite boundaries by detecting black separator lines using sampling.
    Only checks every nth pixel to reduce CPU load.
    """
    width, height = image.size
    print(f"Analyzing image {width}x{height} with sample rate {sample_rate}")

    # Convert to RGB if needed
    if image.mode != 'RGB':
        image = image.convert('RGB')

    # Find horizontal separator lines (sample every nth row)
    horizontal_separators = []
    for y in range(0, height, sample_rate):
        is_separator = True
        # Sample every nth pixel in this row
        for x in range(0, width, sample_rate):
            r, g, b = image.getpixel((x, y))
            if r > black_threshold or g > black_threshold or b > black_threshold:
                is_separator = False
                break
        if is_separator:
            horizontal_separators.append(y)

    # Find vertical separator lines (sample every nth column)
    vertical_separators = []
    for x in range(0, width, sample_rate):
        is_separator = True
        # Sample every nth pixel in this column
        for y in range(0, height, sample_rate):
            r, g, b = image.getpixel((x, y))
            if r > black_threshold or g > black_threshold or b > black_threshold:
                is_separator = False
                break
        if is_separator:
            vertical_separators.append(x)

    print(f"Found {len(horizontal_separators)} horizontal separators")
    print(f"Found {len(vertical_separators)} vertical separators")

    # Group consecutive separators
    h_groups = group_consecutive(horizontal_separators, sample_rate)
    v_groups = group_consecutive(vertical_separators, sample_rate)

    # Create sprite rectangles
    sprites = []
    sprite_id = 0
    for i in range(len(h_groups) - 1):
        for j in range(len(v_groups) - 1):
            x1 = v_groups[j][-1] + 1
            y1 = h_groups[i][-1] + 1
            x2 = v_groups[j + 1][0] - 1
            y2 = h_groups[i + 1][0] - 1

            if x2 > x1 and y2 > y1:  # Valid rectangle
                sprites.append({
                    'id': sprite_id,
                    'rect': (x1, y1, x2 - x1, y2 - y1),
                    'grid_pos': (j, i)
                })
                sprite_id += 1

    return sprites

def group_consecutive(numbers, tolerance=1):
    """Group consecutive numbers together with tolerance for sampling gaps."""
    if not numbers:
        return []

    groups = []
    current_group = [numbers[0]]

    for i in range(1, len(numbers)):
        # Allow gaps up to tolerance (accounts for sampling)
        if numbers[i] <= numbers[i-1] + tolerance + 1:
            current_group.append(numbers[i])
        else:
            groups.append(current_group)
            current_group = [numbers[i]]

    groups.append(current_group)
    return groups

def extract_sprites_sampled(input_path, output_dir, prefix="sprite", sample_rate=4):
    """Extract sprites using sampling method."""
    print(f"Loading image: {input_path}")
    image = Image.open(input_path)

    print(f"Image size: {image.size}")
    print(f"Image mode: {image.mode}")

    # Find sprite boundaries with sampling
    sprites = find_sprite_boundaries_sampled(image, sample_rate=sample_rate)

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

        if sprite_id < 10:  # Show first few
            print(f"Extracted sprite {sprite_id}: {w}x{h} at grid ({grid_x}, {grid_y}) -> {filename}")

    return len(sprites)

def main():
    parser = argparse.ArgumentParser(description='Extract sprites using efficient sampling method')
    parser.add_argument('input', help='Input BMP file path')
    parser.add_argument('output', help='Output directory path')
    parser.add_argument('--prefix', default='sprite', help='Output filename prefix')
    parser.add_argument('--sample-rate', type=int, default=4, help='Sample every nth pixel (default: 4)')
    parser.add_argument('--threshold', type=int, default=10, help='Black threshold (0-255)')

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found")
        return 1

    try:
        count = extract_sprites_sampled(args.input, args.output, args.prefix, args.sample_rate)
        print(f"\nSuccess! Extracted {count} sprites to '{args.output}'")
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())