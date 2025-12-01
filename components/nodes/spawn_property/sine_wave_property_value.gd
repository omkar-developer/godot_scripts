class_name SineWavePropertyValue
extends SpawnPropertyValue

@export var amplitude: float = 1.0
@export var frequency: float = 1.0
@export var offset: float = 0.0
@export var phase: float = 0.0

func get_value(x_value: float) -> Variant:
	return offset + amplitude * sin(x_value * frequency * TAU + phase)
