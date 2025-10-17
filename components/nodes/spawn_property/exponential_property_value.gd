class_name ExponentialPropertyValue
extends SpawnPropertyValue

@export var base_value: float = 1.0
@export var exponent: float = 2.0
@export var multiplier: float = 1.0

func get_value(x_value: float) -> Variant:
	return multiplier * pow(base_value, x_value * exponent)
