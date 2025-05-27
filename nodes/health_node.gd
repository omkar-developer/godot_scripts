extends Node

@export var max_health := 100

var component: HealthComponent

func _ready():
	component = HealthComponent.new()
	component.max_health = max_health
	component.current_health = max_health
	component.connect("died", Callable(self, "_on_died"))

func _on_died():
	queue_free()
