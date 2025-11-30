#!/usr/bin/env python3
"""
Split large sprite sheet into Godot-compatible chunks (max 16384 height)
"""

import os
from PIL import Image

def split_sprites():
    input_path = "assets-odyssey/sprites.png"

    print(f"Loading: {input_path}")
    img = Image.open(input_path)
    width, height = img.size

    print(f"Original size: {width}x{height}")

    # Godot max texture height
    MAX_HEIGHT = 16384
    TILE_SIZE = 32

    # Calculate how many rows fit in max height
    max_rows = MAX_HEIGHT // TILE_SIZE  # 512 rows

    # Calculate number of chunks needed
    total_rows = height // TILE_SIZE
    chunks_needed = (total_rows + max_rows - 1) // max_rows

    print(f"Total sprite rows: {total_rows}")
    print(f"Max rows per chunk: {max_rows}")
    print(f"Chunks needed: {chunks_needed}")

    for chunk_idx in range(chunks_needed):
        start_row = chunk_idx * max_rows
        end_row = min((chunk_idx + 1) * max_rows, total_rows)

        start_y = start_row * TILE_SIZE
        end_y = end_row * TILE_SIZE

        chunk_height = end_y - start_y

        print(f"\nChunk {chunk_idx + 1}:")
        print(f"  Rows: {start_row} to {end_row}")
        print(f"  Height: {chunk_height}px")

        # Crop the chunk
        chunk_img = img.crop((0, start_y, width, end_y))

        # Save chunk
        output_path = f"assets-odyssey/sprites_part{chunk_idx + 1}.png"
        chunk_img.save(output_path, "PNG")
        print(f"  Saved: {output_path}")

    print("\n=== SPLIT COMPLETE ===")
    print(f"Created {chunks_needed} sprite files")

if __name__ == "__main__":
    split_sprites()