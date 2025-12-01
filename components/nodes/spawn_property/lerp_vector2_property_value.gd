class_name LerpVector2PropertyValue
extends SpawnPropertyValue

@export var start_value: Vector2 = Vector2.ZERO
@export var end_value: Vector2 = Vector2.ONE

func get_value(x_value: float) -> Variant:
	var t = clamp(x_value, 0.0, 1.0)
	return start_value.lerp(end_value, t)
