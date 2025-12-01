class_name SteppedPropertyValue
extends SpawnPropertyValue

@export var steps: Dictionary = {}

func get_value(x_value: float) -> Variant:
	if steps.is_empty():
		return 0
	
	var sorted_thresholds: Array = []
	for threshold in steps.keys():
		sorted_thresholds.append(float(threshold))
	sorted_thresholds.sort()
	
	var current_value = steps[sorted_thresholds[0]]
	for threshold in sorted_thresholds:
		if x_value >= threshold:
			current_value = steps[threshold]
		else:
			break
	
	return current_value
