class_name LookComponent
extends RefCounted

var owner: Node2D
var movement: MovementComponent
var target: Node2D
var look_mode: int = LookMode.VELOCITY
var rotation_speed: float = 10.0
var smooth: bool = true
var active: bool = true

enum LookMode {
	VELOCITY,
	TARGET
}

func _init(_movement: MovementComponent):
	self.owner = _movement.owner
	self.movement = _movement

func update(delta: float):
	if not active:
		return
		
	var target_rotation: float
	
	match look_mode:
		LookMode.VELOCITY:
			target_rotation = movement.velocity.angle()
		LookMode.TARGET:
			if is_instance_valid(target):
				var direction = target.global_position - owner.global_position
				target_rotation = direction.angle()
			else:
				return
	
	if smooth:
		owner.rotation = target_rotation
	else:
		owner.rotation = lerp_angle(owner.rotation, target_rotation, rotation_speed * delta)

func set_target(new_target: Node2D):
	target = new_target
	look_mode = LookMode.TARGET

func set_velocity_based():
	look_mode = LookMode.VELOCITY

