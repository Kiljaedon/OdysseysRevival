#!/usr/bin/env python3
"""
Odyssey Tile Categorization System
Generates comprehensive tile categories for the Tiled tileset
Based on standard Odyssey map editor layer classifications
"""

def generate_tile_categories():
    """Generate XML entries for all 3584 Odyssey tiles with proper categorization"""

    # Define tile ranges based on Odyssey tileset structure
    tile_categories = {
        # BOTTOM LAYER - Base terrain tiles (typically first few rows)
        'bottom': {
            'grass': list(range(0, 49)),  # First 7 rows - grass variants
            'dirt': list(range(49, 98)),  # Next 7 rows - dirt variants
            'water': list(range(98, 147)), # Next 7 rows - water variants
            'stone': list(range(147, 196)), # Next 7 rows - stone variants
            'sand': list(range(196, 245)), # Sand terrain
            'snow': list(range(245, 294)), # Snow terrain
            'lava': list(range(294, 343)), # Lava terrain
        },

        # MIDDLE LAYER - Objects and structures
        'middle': {
            'buildings': list(range(343, 700)),    # Buildings, castles, houses
            'vegetation': list(range(700, 1050)),  # Trees, bushes, plants
            'obstacles': list(range(1050, 1400)), # Rocks, boulders, barriers
            'furniture': list(range(1400, 1750)), # Indoor objects, furniture
            'decorations': list(range(1750, 2100)), # Decorative objects
            'paths': list(range(2100, 2450)),     # Roads, bridges, pathways
        },

        # FOREGROUND LAYER - Effects and overlays
        'foreground': {
            'effects': list(range(2450, 2800)),    # Visual effects, magic
            'overlays': list(range(2800, 3150)),   # Shadows, lighting
            'details': list(range(3150, 3500)),    # Small details, particles
            'ui_elements': list(range(3500, 3584)), # UI related tiles
        }
    }

    xml_entries = []

    for layer_type, categories in tile_categories.items():
        xml_entries.append(f'\n <!-- {layer_type.upper()} LAYER TILES -->')

        for category, tile_ids in categories.items():
            xml_entries.append(f'\n <!-- {category.title()} tiles -->')

            for tile_id in tile_ids:
                description = f"{category.replace('_', ' ').title()} tile"
                if layer_type == 'bottom':
                    description = f"{category.title()} terrain base"
                elif layer_type == 'middle':
                    description = f"{category.replace('_', ' ').title()} object"
                elif layer_type == 'foreground':
                    description = f"{category.replace('_', ' ').title()} overlay"

                xml_entry = f'''
 <tile id="{tile_id}" type="{layer_type}">
  <properties>
   <property name="layer_type" value="{layer_type}"/>
   <property name="category" value="{category}"/>
   <property name="description" value="{description}"/>
  </properties>
 </tile>'''
                xml_entries.append(xml_entry)

    return '\n'.join(xml_entries)

def create_enhanced_tileset():
    """Create enhanced tileset XML with all tile categorizations"""

    header = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.0" name="Odyssey Tileset (Enhanced)" tilewidth="32" tileheight="32" tilecount="3584" columns="7">
 <image source="C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/assets-odyssey/tiles.png" width="224" height="16384"/>

 <!-- Terrain Types for Auto-tiling -->
 <terraintypes>
  <terrain name="Grass" tile="0"/>
  <terrain name="Dirt" tile="49"/>
  <terrain name="Water" tile="98"/>
  <terrain name="Stone" tile="147"/>
  <terrain name="Sand" tile="196"/>
  <terrain name="Snow" tile="245"/>
  <terrain name="Lava" tile="294"/>
 </terraintypes>'''

    tile_definitions = generate_tile_categories()

    footer = '''

 <!-- Wang Sets for Terrain Transitions -->
 <wangsets>
  <wangset name="Terrain Transitions" type="corner" tile="-1">
   <wangcolor name="Grass" color="#4c7c2f" tile="0" probability="1"/>
   <wangcolor name="Dirt" color="#8b4513" tile="49" probability="1"/>
   <wangcolor name="Water" color="#0066cc" tile="98" probability="1"/>
   <wangcolor name="Stone" color="#666666" tile="147" probability="1"/>
   <wangcolor name="Sand" color="#f4a460" tile="196" probability="1"/>
   <wangcolor name="Snow" color="#ffffff" tile="245" probability="1"/>
   <wangcolor name="Lava" color="#ff4500" tile="294" probability="1"/>
  </wangset>
 </wangsets>

 <!-- Object Types for Enhanced Tiled Integration -->
 <objecttypes>
  <objecttype name="Spawn Point" color="#00ff00">
   <property name="type" type="string" default="player"/>
  </objecttype>
  <objecttype name="Exit Point" color="#ff0000">
   <property name="destination" type="string" default=""/>
   <property name="direction" type="string" default="up"/>
  </objecttype>
  <objecttype name="NPC Spawn" color="#ffff00">
   <property name="npc_id" type="int" default="0"/>
  </objecttype>
  <objecttype name="Monster Spawn" color="#ff00ff">
   <property name="monster_id" type="int" default="0"/>
   <property name="spawn_rate" type="int" default="100"/>
  </objecttype>
 </objecttypes>

</tileset>'''

    return header + tile_definitions + footer

# Generate the enhanced tileset
if __name__ == "__main__":
    enhanced_tileset = create_enhanced_tileset()

    # Write to file
    output_path = "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/tiled_projects/odyssey_tileset_enhanced.tsx"
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(enhanced_tileset)

    print(f"Enhanced tileset created: {output_path}")
    print("Features:")
    print("- 3584 tiles categorized by layer type (bottom/middle/foreground)")
    print("- Categories: grass, dirt, water, stone, sand, snow, lava terrains")
    print("- Objects: buildings, vegetation, obstacles, furniture, decorations, paths")
    print("- Effects: visual effects, overlays, details, UI elements")
    print("- Wang sets for auto-tiling terrain transitions")
    print("- Object types for spawn points, exits, NPCs, monsters")