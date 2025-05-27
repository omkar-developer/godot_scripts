class_name HomingComponent
extends RefCounted

var owner: Node2D
var target: Node2D
var movement: MovementComponent
var update_interval: float = 0.1
var time_since_update: float = 0.0
var homing_enabled: bool = true
var update_direction_every_frame: bool = true
var no_target_behavior_stop: bool = false

func _init(_movement: MovementComponent, _target: Node2D = null):
	self.owner = _movement.owner
	self.movement = _movement
	self.target = _target

func update(delta: float):
	if not homing_enabled or not is_instance_valid(target):
		target = null
		return
		
	if update_direction_every_frame:
		update_direction()
	else:
		time_since_update += delta
		if time_since_update >= update_interval:
			update_direction()
			time_since_update = 0.0
	
	movement.update(delta)

func update_direction():
	if is_instance_valid(target):
		movement.direction = target.position - owner.position
	else:
		if not no_target_behavior_stop:
			movement.direction = Vector2.ZERO

func set_target(new_target: Node2D):
	target = new_target
	update_direction()
