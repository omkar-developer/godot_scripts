class_name NoisePropertyValue
extends SpawnPropertyValue

@export var noise: FastNoiseLite = null
@export var value_multiplier: float = 1.0
@export var value_offset: float = 0.0

func get_value(x_value: float) -> Variant:
	if not noise:
		push_warning("NoisePropertyValue: No noise assigned")
		return 0.0
	
	var sample := noise.get_noise_1d(x_value)
	return (sample * value_multiplier) + value_offset
