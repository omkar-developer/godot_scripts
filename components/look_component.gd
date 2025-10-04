class_name LookComponent
extends RefCounted

enum LookMode {
    VELOCITY,
    TARGET
}

var look_mode: LookMode = LookMode.VELOCITY
var rotation_speed: float = 10.0
var smooth: bool = true
var active: bool = true

var owner: Node2D
var movement: MovementComponent
var target: Node2D = null

func _init(_movement: MovementComponent):
    movement = _movement
    owner = _movement.owner

func update(delta: float):
    if not active or owner == null:
        return

    var target_rotation: float

    match look_mode:
        LookMode.VELOCITY:
            if movement.velocity.length_squared() > 0.001:
                target_rotation = movement.velocity.angle()
            else:
                return  # Avoid jitter when stopped
        LookMode.TARGET:
            if is_instance_valid(target):
                var direction = target.global_position - owner.global_position
                if direction.length_squared() > 0.001:
                    target_rotation = direction.angle()
                else:
                    return
            else:
                return

    if smooth:
        owner.rotation = lerp_angle(owner.rotation, target_rotation, rotation_speed * delta)
    else:
        owner.rotation = target_rotation

func set_target(new_target: Node2D):
    target = new_target
    look_mode = LookMode.TARGET

func set_velocity_based():
    look_mode = LookMode.VELOCITY
