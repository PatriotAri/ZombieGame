extends SceneTree
## Makes the blood splatter images (splat_1.png, splat_2.png, splat_3.png) in
## this folder: dark red blots with droplets around them, transparent
## elsewhere. Replace them with your own art any time (same names, square,
## transparent background); effects/blood.gd uses whatever's here.
##   godot --headless --path . -s res://effects/blood/make_blood.gd

const DIR := "res://effects/blood/"
const SIZE := 128


func _initialize() -> void:
	for n in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + n
		var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var center := Vector2(SIZE, SIZE) / 2.0
		# The main blot: overlapping soft circles near the middle.
		for i in 14:
			var at := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, SIZE * 0.16)
			_blob(image, at, rng.randf_range(SIZE * 0.08, SIZE * 0.2), rng)
		# Droplets and streaks flung outward.
		for i in 26:
			var dir := Vector2.from_angle(rng.randf() * TAU)
			var dist := rng.randf_range(SIZE * 0.22, SIZE * 0.46)
			var radius := rng.randf_range(1.5, 4.5)
			for step in rng.randi_range(1, 4): # a short streak of shrinking drops
				_blob(image, center + dir * (dist + step * radius * 1.6), radius * pow(0.75, step), rng)
		image.save_png(ProjectSettings.globalize_path(DIR + "splat_%d.png" % (n + 1)))
	print("blood: 3 splats saved")
	quit()


## A soft-edged dark red disc, darker toward the middle.
func _blob(image: Image, at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var shade := rng.randf_range(0.75, 1.0)
	for y in range(maxi(int(at.y - radius - 1), 0), mini(int(at.y + radius + 2), SIZE)):
		for x in range(maxi(int(at.x - radius - 1), 0), mini(int(at.x + radius + 2), SIZE)):
			var d := Vector2(x, y).distance_to(at) / radius
			if d > 1.0:
				continue
			var alpha := clampf((1.0 - d) * 3.0, 0.0, 1.0)
			var old := image.get_pixel(x, y)
			var color := Color(0.42 * shade, 0.03, 0.02, maxf(old.a, alpha * 0.92))
			if old.a > 0.0: # overlapping: darker
				color.r = minf(old.r, color.r) * 0.92
			image.set_pixel(x, y, color)
