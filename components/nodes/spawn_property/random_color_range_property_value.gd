class_name RandomColorRangePropertyValue
extends SpawnPropertyValue

@export var min_color: Color = Color.WHITE
@export var max_color: Color = Color.WHITE

func get_value(x_value: float) -> Variant:
	return Color(
		randf_range(min_color.r, max_color.r),
		randf_range(min_color.g, max_color.g),
		randf_range(min_color.b, max_color.b),
		randf_range(min_color.a, max_color.a)
	)
