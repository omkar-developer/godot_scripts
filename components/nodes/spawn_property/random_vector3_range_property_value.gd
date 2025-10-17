class_name RandomVector3RangePropertyValue
extends SpawnPropertyValue

@export var min_value: Vector3 = Vector3.ZERO
@export var max_value: Vector3 = Vector3.ONE

func get_value(x_value: float) -> Variant:
	return Vector3(
		randf_range(min_value.x, max_value.x),
		randf_range(min_value.y, max_value.y),
		randf_range(min_value.z, max_value.z)
	)
