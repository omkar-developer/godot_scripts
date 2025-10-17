class_name GradientPropertyValue
extends SpawnPropertyValue

@export var gradient: Gradient = null

func get_value(x_value: float) -> Variant:
	if not gradient:
		push_warning("GradientPropertyValue: No gradient assigned")
		return Color.WHITE
	
	return gradient.sample(clamp(x_value, 0.0, 1.0))
