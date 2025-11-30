from PIL import Image
import os

def check_image_info(image_path):
    """Check image dimensions and format info"""
    try:
        with Image.open(image_path) as img:
            print(f"{image_path}: {img.size[0]}x{img.size[1]} pixels, mode: {img.mode}")
            return img.size
    except Exception as e:
        print(f"Error reading {image_path}: {e}")
        return None

def main():
    """Check Odyssey asset dimensions"""
    assets_dir = "assets-odyssey"

    files = ["sprites.png", "tiles.png", "interface.png"]

    for file in files:
        path = os.path.join(assets_dir, file)
        if os.path.exists(path):
            check_image_info(path)
        else:
            print(f"File not found: {path}")

if __name__ == "__main__":
    main()