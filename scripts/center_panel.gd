extends Control

@onready var heading_label = $"../CenterPanel/VBoxContainer/HeadingLabel"
@onready var coords_label = $"../CenterPanel/VBoxContainer/CoordsLabel"
@onready var ship = get_node("/root/water-scene/boat")

var displayed_heading := 0.0

func _process(delta):
	if not ship:
		return

	var raw_heading = ship.rotation_degrees.y

	# normalize
	if raw_heading < 0:
		raw_heading += 360

	displayed_heading = lerp(displayed_heading, raw_heading, 5 * delta)

	var compass = get_compass(displayed_heading)

	heading_label.text = "Heading: " + str(round(displayed_heading)) + "° (" + compass + ")"

	var pos = ship.global_position
	coords_label.text = "Pos: " + str(round(pos.x)) + ", " + str(round(pos.z))


func get_compass(heading: float) -> String:
	heading = fmod(heading, 360.0)
	if heading < 0:
		heading += 360.0

	if heading < 22.5: return "N"
	elif heading < 67.5: return "NE"
	elif heading < 112.5: return "E"
	elif heading < 157.5: return "SE"
	elif heading < 202.5: return "S"
	elif heading < 247.5: return "SW"
	elif heading < 292.5: return "W"
	elif heading < 337.5: return "NW"
	return "N"
