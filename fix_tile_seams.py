#!/usr/bin/env python3
"""
Fix tile seams by ensuring fully opaque or fully transparent pixels (no semi-transparency)
"""

from PIL import Image

def fix_seams(input_path, output_path):
    """Remove semi-transparent pixels that cause seams"""
    print(f"Loading: {input_path}")
    img = Image.open(input_path).convert("RGBA")
    pixels = img.load()
    width, height = img.size

    print(f"Processing {width}x{height}...")

    alpha_threshold = 128  # Below this = fully transparent, above = fully opaque
    fixed_count = 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            # Fix semi-transparent pixels
            if a < alpha_threshold:
                # Make fully transparent
                pixels[x, y] = (0, 0, 0, 0)
                fixed_count += 1
            elif a < 255:
                # Make fully opaque
                pixels[x, y] = (r, g, b, 255)
                fixed_count += 1

        if y % 1000 == 0:
            print(f"  {y}/{height} rows...")

    print(f"Fixed {fixed_count} semi-transparent pixels")
    print(f"Saving: {output_path}")
    img.save(output_path, "PNG")
    print("Done!")

if __name__ == "__main__":
    fix_seams("assets-odyssey/tiles_part1.png", "assets-odyssey/tiles_part1.png")
    fix_seams("assets-odyssey/tiles_part2.png", "assets-odyssey/tiles_part2.png")