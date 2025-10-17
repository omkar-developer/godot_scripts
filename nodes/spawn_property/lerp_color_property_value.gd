class_name LerpColorPropertyValue
extends SpawnPropertyValue

@export var start_color: Color = Color.WHITE
@export var end_color: Color = Color.BLACK

func get_value(x_value: float) -> Variant:
	var t = clamp(x_value, 0.0, 1.0)
	return start_color.lerp(end_color, t)
