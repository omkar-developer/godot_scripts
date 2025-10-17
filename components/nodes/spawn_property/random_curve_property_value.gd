class_name RandomCurvePropertyValue
extends SpawnPropertyValue

@export var curve: Curve = null
@export var value_multiplier: float = 1.0
@export var value_offset: float = 0.0

func get_value(x_value: float) -> Variant:
	if not curve:
		push_warning("RandomCurvePropertyValue: No curve assigned")
		return 0.0
	
	var random_x := randf()
	var sample := curve.sample(random_x)
	return (sample * value_multiplier) + value_offset
