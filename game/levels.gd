class_name Levels
extends RefCounted

## Where level specs come from. Hand-built for now; the charter's generator
## will emit the same dictionary shape, which is why this is a separate file
## from the thing that simulates it.

const CENTRE_X := 400.0
const FLOOR_Y := 540.0

## The height line sits about a block-and-a-half above the ground. Low enough
## that a standing pillar always breaks it, high enough that rubble lying flat
## usually does not — so the level asks you to bring the building down, not to
## pulverise every piece.
const LINE_ABOVE_GROUND := 100.0

const PILLAR := Vector2(22.0, 76.0)
const SLAB_H := 22.0


## A four-storey frame: pillars carrying slabs, all the way up.
##
## Tuned so a single charge cannot clear it — the first playable's tower could
## be flattened with one explosive, which made the move budget decorative.
## Whether that still holds is checked by playtest.gd, not by eye.
static func tower(storeys: int = 4, pillars: int = 5, spacing: float = 86.0) -> Dictionary:
	var blocks: Array = []
	var first_x := CENTRE_X - (pillars - 1) * spacing * 0.5
	var slab_w := (pillars - 1) * spacing + PILLAR.x * 2.0
	var y := FLOOR_Y

	for storey in storeys:
		for i in pillars:
			blocks.append({
				"x": first_x + i * spacing,
				"y": y - PILLAR.y * 0.5,
				"w": PILLAR.x, "h": PILLAR.y,
				"role": "pillar",
			})
		y -= PILLAR.y
		blocks.append({
			"x": CENTRE_X,
			"y": y - SLAB_H * 0.5,
			"w": slab_w, "h": SLAB_H,
			"role": "slab",
		})
		y -= SLAB_H

	return {
		"centre_x": CENTRE_X,
		"floor_y": FLOOR_Y,
		"height_line": FLOOR_Y - LINE_ABOVE_GROUND,
		"blocks": blocks,
		"moves": 5,
	}
