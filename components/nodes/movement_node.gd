extends Node

@export var speed := 100.0
@export var direction := Vector2.RIGHT

var component: MovementComponent

func _ready():
	component = MovementComponent.new(get_parent(), speed, direction)

func _process(delta):
	component.update(delta)
