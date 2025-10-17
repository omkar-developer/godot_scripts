class_name RandomChoicePropertyValue
extends SpawnPropertyValue

@export var choices: Array = []

func get_value(x_value: float) -> Variant:
	if choices.is_empty():
		return null
	return choices[randi() % choices.size()]
