class_name WeightedRandomPropertyValue
extends SpawnPropertyValue

@export var weighted_choices: Dictionary = {}

func get_value(x_value: float) -> Variant:
	if weighted_choices.is_empty():
		return null
	
	var total_weight := 0.0
	for weight in weighted_choices.values():
		total_weight += float(weight)
	
	var random_value := randf() * total_weight
	var cumulative := 0.0
	
	for choice in weighted_choices.keys():
		cumulative += float(weighted_choices[choice])
		if random_value <= cumulative:
			return choice
	
	return weighted_choices.keys()[0]
