class_name RandomVector2RangePropertyValue
extends SpawnPropertyValue

@export var min_value: Vector2 = Vector2.ZERO
@export var max_value: Vector2 = Vector2.ONE

func get_value(_x_value: float) -> Variant:
	return Vector2(
		randf_range(min_value.x, max_value.x),
		randf_range(min_value.y, max_value.y)
	)
