class_name RandomRangePropertyValue
extends SpawnPropertyValue

@export var min_value: float = 0.0
@export var max_value: float = 1.0

func get_value(_x_value: float) -> Variant:
	return randf_range(min_value, max_value)
