class_name Generator
extends RefCounted

## Builds structures from a seed. Emits the same dictionary shape as
## levels.gd, so everything downstream is unaware of where a level came from.
##
## Nothing here decides whether a level is any good — that is the solver's job.
## The generator's only responsibility is to produce varied structures that
## stand up and have somewhere worth hitting.

const CENTRE_X := 400.0
const FLOOR_Y := 540.0
const LINE_ABOVE_GROUND := 100.0
const SLAB_H := 22.0


static func generate(level_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed

	var storeys := rng.randi_range(3, 5)
	var bays := rng.randi_range(3, 5)
	var pillars := bays + 1
	var spacing := rng.randf_range(74.0, 96.0)
	var pillar_w := rng.randf_range(18.0, 26.0)
	var pillar_h := rng.randf_range(64.0, 84.0)

	var blocks: Array = []
	var first_x := CENTRE_X - (pillars - 1) * spacing * 0.5
	var slab_w := (pillars - 1) * spacing + pillar_w * 2.0
	var y := FLOOR_Y

	for storey in storeys:
		# Upper storeys may drop an interior pillar. That is where the level
		# gets its shape: a gap makes the slab above it depend on fewer
		# supports, so there is a wrong side to hit and a right one.
		var missing := -1
		if storey > 0 and pillars > 3 and rng.randf() < 0.45:
			missing = rng.randi_range(1, pillars - 2)

		for i in pillars:
			if i == missing:
				continue
			# A wider pillar is a stronger support: worth spending a move on,
			# and worth noticing before you spend it elsewhere.
			var width := pillar_w
			if rng.randf() < 0.15:
				width = pillar_w * 1.6
			blocks.append({
				"x": first_x + i * spacing,
				"y": y - pillar_h * 0.5,
				"w": width, "h": pillar_h,
				"role": "pillar",
			})
		y -= pillar_h
		blocks.append({
			"x": CENTRE_X + rng.randf_range(-6.0, 6.0),
			"y": y - SLAB_H * 0.5,
			"w": slab_w, "h": SLAB_H,
			"role": "slab",
		})
		y -= SLAB_H

	return {
		"seed": level_seed,
		"centre_x": CENTRE_X,
		"floor_y": FLOOR_Y,
		"height_line": FLOOR_Y - LINE_ABOVE_GROUND,
		"blocks": blocks,
		# Filled in by the solver once the level has been verified: the budget
		# is the length of a solution that actually exists, plus slack.
		"moves": 0,
	}
