extends Node2D

var movement: MovementComponent
var health: HealthComponent

func _ready():
	movement = MovementComponent.new(self, 80.0, Vector2.LEFT)
	health = HealthComponent.new()
	health.connect("died", Callable(self, "_on_died"))

func _process(delta):
	movement.update(delta)

func _on_died():
	queue_free()
