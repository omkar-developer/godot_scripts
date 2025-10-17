class_name LerpPropertyValue
extends SpawnPropertyValue

@export var start_value: float = 0.0
@export var end_value: float = 1.0

func get_value(x_value: float) -> Variant:
	return lerp(start_value, end_value, clamp(x_value, 0.0, 1.0))
