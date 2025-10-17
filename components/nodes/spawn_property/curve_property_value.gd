class_name CurvePropertyValue
extends SpawnPropertyValue

@export var curve: Curve = null
@export var value_multiplier: float = 1.0
@export var value_offset: float = 0.0

func get_value(x_value: float) -> Variant:
	if not curve:
		push_warning("CurvePropertyValue: No curve assigned")
		return 0.0
	
	var sample := curve.sample(x_value)
	return (sample * value_multiplier) + value_offset
