@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets-odyssey/tiles_part1.png")
	if not img:
		return
		
	var counts = {}
	var grey_color = Color("787878") # Approx grey?
	
	print("Scanning first 5000 pixels...")
	for y in range(100):
		for x in range(50):
			var c = img.get_pixel(x, y)
			var hex = c.to_html()
			if not counts.has(hex):
				counts[hex] = 0
			counts[hex] += 1
			
	print("Top colors:")
	for hex in counts:
		if counts[hex] > 10:
			print("%s: %d" % [hex, counts[hex]])
			
	quit()