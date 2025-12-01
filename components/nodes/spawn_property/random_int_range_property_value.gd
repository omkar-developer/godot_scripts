class_name RandomIntRangePropertyValue
extends SpawnPropertyValue

@export var min_value: int = 0
@export var max_value: int = 10

func get_value(_x_value: float) -> Variant:
	return randi_range(min_value, max_value)
