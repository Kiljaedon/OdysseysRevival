"""
Create a simple battle background with color gradients
No need for finding exact tiles - just make it look good
"""

from PIL import Image, ImageDraw
import random

# Background dimensions
BG_WIDTH = 1280
BG_HEIGHT = 720

def create_simple_background():
    """Create a simple grassy field background with gradients"""
    print("Creating simple battle background...")

    # Create base image
    img = Image.new("RGB", (BG_WIDTH, BG_HEIGHT))
    draw = ImageDraw.Draw(img)

    # Sky gradient (top 60% of screen)
    sky_height = int(BG_HEIGHT * 0.6)
    for y in range(sky_height):
        # Gradient from light blue to darker blue
        progress = y / sky_height
        r = int(100 + (60 - 100) * progress)
        g = int(149 + (120 - 149) * progress)
        b = int(237 + (200 - 237) * progress)
        draw.rectangle([(0, y), (BG_WIDTH, y+1)], fill=(r, g, b))

    # Ground gradient (bottom 40% of screen)
    ground_start = sky_height
    ground_height = BG_HEIGHT - ground_start
    for y in range(ground_height):
        # Gradient from lighter green to darker green
        progress = y / ground_height
        r = int(34 + (25 - 34) * progress)
        g = int(139 + (100 - 139) * progress)
        b = int(34 + (25 - 34) * progress)
        actual_y = ground_start + y
        draw.rectangle([(0, actual_y), (BG_WIDTH, actual_y+1)], fill=(r, g, b))

    # Add some texture/noise to ground
    random.seed(42)
    for _ in range(2000):
        x = random.randint(0, BG_WIDTH-1)
        y = random.randint(ground_start, BG_HEIGHT-1)
        # Random darker/lighter spots
        offset = random.randint(-10, 10)
        base_color = img.getpixel((x, y))
        new_color = tuple(max(0, min(255, c + offset)) for c in base_color)
        draw.point((x, y), fill=new_color)

    # Add horizon line
    horizon_y = sky_height
    draw.rectangle([(0, horizon_y), (BG_WIDTH, horizon_y+2)], fill=(80, 120, 80))

    # Save
    output_path = "assets/battle_backgrounds/grassy_field.png"
    img.save(output_path, "PNG")
    print(f"Background saved: {output_path}")
    print(f"Size: {BG_WIDTH}x{BG_HEIGHT}")

if __name__ == "__main__":
    create_simple_background()
