class_name LerpVector3PropertyValue
extends SpawnPropertyValue

@export var start_value: Vector3 = Vector3.ZERO
@export var end_value: Vector3 = Vector3.ONE

func get_value(x_value: float) -> Variant:
	var t = clamp(x_value, 0.0, 1.0)
	return start_value.lerp(end_value, t)
