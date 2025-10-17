class_name BouncePropertyValue
extends SpawnPropertyValue

@export var start_value: float = 0.0
@export var end_value: float = 1.0
@export var bounces: int = 3

func get_value(x_value: float) -> Variant:
	var t = clamp(x_value, 0.0, 1.0)
	var bounce_value = abs(sin(t * PI * float(bounces)))
	return lerp(start_value, end_value, bounce_value)
