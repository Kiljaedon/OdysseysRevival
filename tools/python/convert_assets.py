from PIL import Image
import os

def convert_bmp_to_png(bmp_path, png_path):
    """Convert BMP file to PNG"""
    try:
        with Image.open(bmp_path) as img:
            # Convert to RGB if necessary (removes any alpha issues)
            if img.mode != 'RGB':
                img = img.convert('RGB')
            img.save(png_path, 'PNG', optimize=True)
        print(f"Converted {bmp_path} -> {png_path}")
        return True
    except Exception as e:
        print(f"Error converting {bmp_path}: {e}")
        return False

def main():
    """Convert Odyssey BMP assets to PNG"""
    assets_dir = "assets-odyssey"

    # Files to convert
    files = [
        ("sprites.bmp", "sprites.png"),
        ("tiles.bmp", "tiles.png"),
        ("interface.bmp", "interface.png")
    ]

    for bmp_file, png_file in files:
        bmp_path = os.path.join(assets_dir, bmp_file)
        png_path = os.path.join(assets_dir, png_file)

        if os.path.exists(bmp_path):
            convert_bmp_to_png(bmp_path, png_path)
        else:
            print(f"File not found: {bmp_path}")

if __name__ == "__main__":
    main()