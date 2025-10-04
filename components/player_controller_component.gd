class_name PlayerController
extends RefCounted

## Player controller that integrates with your component system
## Requires: MovementComponent
## Optional: PhysicsMovementComponent, LookComponent

enum ControlMode {
	DIRECT,            # Direct velocity control (instant response)
	PHYSICS,           # Physics-based with momentum
	STEERING,          # Only for CLICK_TO_MOVE - smooth arrival with obstacle avoidance
}

enum InputMode {
	WASD,              # Standard keyboard
	MOUSE_FOLLOW,      # Move toward mouse
	CLICK_TO_MOVE,     # Click destination (uses arrive steering)
	TWIN_STICK,        # WASD + mouse aim
}

var owner: Node2D
var movement: MovementComponent
var control_mode: ControlMode = ControlMode.DIRECT
var input_mode: InputMode = InputMode.WASD

# Optional components
var physics_component: PhysicsMovementComponent = null
var look_component: LookComponent = null

# Obstacle avoidance (only for STEERING mode with CLICK_TO_MOVE)
var avoidance_behavior = null  # OptimizedRaycastAvoidance or similar
var avoidance_weight: float = 1.0

# Click-to-move with arrive behavior
var steering_manager: SteeringManagerComponent = null
var behavior_builder: SteeringBehaviorBuilder = null  # Use the builder!
var dummy_target: Node2D = null

# Control settings
var controls_enabled: bool = true
var normalize_diagonal: bool = true

# Input action names
var action_up: String = "ui_up"
var action_down: String = "ui_down"
var action_left: String = "ui_left"
var action_right: String = "ui_right"
var action_move_to: String = "ui_click"

# Physics settings
var move_force: float = 500.0
var max_speed: float = 200.0

# Mouse/Click settings
var mouse_follow_threshold: float = 5.0
var click_destination: Vector2 = Vector2.ZERO
var has_destination: bool = false
var arrival_threshold: float = 10.0
var arrive_slow_radius: float = 100.0
var arrive_stop_radius: float = 10.0

# Aim direction (twin-stick)
var aim_direction: Vector2 = Vector2.RIGHT

func _init(_movement: MovementComponent, _control_mode: ControlMode = ControlMode.DIRECT, _input_mode: InputMode = InputMode.WASD):
	self.owner = _movement.owner
	self.movement = _movement
	self.control_mode = _control_mode
	self.input_mode = _input_mode

func setup_physics(mass: float = 1.0, use_gravity: bool = false, friction: float = 200.0) -> PhysicsMovementComponent:
	"""Setup physics-based movement with momentum"""
	physics_component = PhysicsMovementComponent.new(movement, mass, use_gravity)
	physics_component.friction = friction
	return physics_component

func setup_look(mode: LookComponent.LookMode = LookComponent.LookMode.VELOCITY, rotation_speed: float = 10.0) -> LookComponent:
	"""Setup automatic rotation/look component"""
	look_component = LookComponent.new(movement)
	look_component.look_mode = mode
	look_component.rotation_speed = rotation_speed
	return look_component

func enable_obstacle_avoidance(avoidance_steering, weight: float = 1.0):
	"""
	Enable obstacle avoidance for STEERING mode with CLICK_TO_MOVE
	Only works when: control_mode == STEERING and input_mode == CLICK_TO_MOVE
	Example: controller.enable_obstacle_avoidance(OptimizedRaycastAvoidance.new(...))
	"""
	avoidance_behavior = avoidance_steering
	avoidance_behavior.setup(owner, movement)
	avoidance_weight = weight

func disable_obstacle_avoidance():
	avoidance_behavior = null

func update(delta: float):
	if not controls_enabled:
		return
	
	# Only CLICK_TO_MOVE with STEERING mode uses steering behaviors
	if input_mode == InputMode.CLICK_TO_MOVE and control_mode == ControlMode.STEERING:
		_handle_click_to_move_steering()
		# Update steering manager (this is the key - must happen every frame!)
		if steering_manager:
			steering_manager.update(delta)
	else:
		# All other modes: direct input control
		var input_vector = _get_input_vector()
		
		match control_mode:
			ControlMode.DIRECT:
				_update_direct(input_vector)
			ControlMode.PHYSICS:
				_update_physics(input_vector, delta)
			ControlMode.STEERING:
				# STEERING mode only makes sense with CLICK_TO_MOVE
				# For other input modes, fall back to DIRECT
				_update_direct(input_vector)
	
	# Update look component
	if look_component:
		look_component.update(delta)

func _get_input_vector() -> Vector2:
	"""Get input based on input mode"""
	match input_mode:
		InputMode.WASD:
			return _get_wasd_input()
		InputMode.MOUSE_FOLLOW:
			return _get_mouse_follow_input()
		InputMode.CLICK_TO_MOVE:
			return _get_click_to_move_input()
		InputMode.TWIN_STICK:
			_update_twin_stick_aim()
			return _get_wasd_input()
	return Vector2.ZERO

func _get_wasd_input() -> Vector2:
	var input = Vector2.ZERO
	
	if Input.is_action_pressed(action_right):
		input.x += 1
	if Input.is_action_pressed(action_left):
		input.x -= 1
	if Input.is_action_pressed(action_down):
		input.y += 1
	if Input.is_action_pressed(action_up):
		input.y -= 1
	
	if normalize_diagonal and input.length() > 0:
		input = input.normalized()
	
	return input

func _get_mouse_follow_input() -> Vector2:
	var mouse_pos = owner.get_global_mouse_position()
	var distance = owner.global_position.distance_to(mouse_pos)
	
	if distance > mouse_follow_threshold:
		return (mouse_pos - owner.global_position).normalized()
	return Vector2.ZERO

func _get_click_to_move_input() -> Vector2:
	"""Simple click-to-move without steering (direct movement)"""
	# Check for new click
	if Input.is_action_just_pressed(action_move_to):
		click_destination = owner.get_global_mouse_position()
		has_destination = true
	
	if has_destination:
		var distance = owner.global_position.distance_to(click_destination)
		if distance > arrival_threshold:
			return (click_destination - owner.global_position).normalized()
		else:
			has_destination = false
	
	return Vector2.ZERO

func _handle_click_to_move_steering():
	"""Click-to-move with steering using SteeringBehaviorBuilder (like your test scene)"""
	
	# Setup steering on first use (only once, like your test scene)
	if behavior_builder == null:
		steering_manager = SteeringManagerComponent.new(owner, movement)
		behavior_builder = SteeringBehaviorBuilder.create(owner, movement, steering_manager)
		
		# Create dummy target
		dummy_target = Node2D.new()
		owner.add_child(dummy_target)
		dummy_target.global_position = owner.global_position  # Start at player position
		
		# Use builder to setup basic_ai (arrive behavior) - exactly like your test!
		behavior_builder.basic_ai(dummy_target, arrive_slow_radius, arrive_stop_radius)
		
		# Add obstacle avoidance if enabled
		if avoidance_behavior != null:
			behavior_builder.add_custom_behavior(avoidance_behavior, avoidance_weight)
	
	# Check for new click
	if Input.is_action_just_pressed(action_move_to):
		click_destination = owner.get_global_mouse_position()
		has_destination = true
	
	# Update target position every frame when we have a destination (like your test does with mouse)
	if has_destination and dummy_target:
		dummy_target.global_position = click_destination
		
		# Check if arrived
		var distance = owner.global_position.distance_to(click_destination)
		if distance < arrival_threshold:
			has_destination = false
			# Keep target at destination so arrive behavior can finish smoothly

func _update_twin_stick_aim():
	"""Update aim direction for twin-stick mode"""
	var mouse_pos = owner.get_global_mouse_position()
	aim_direction = (mouse_pos - owner.global_position).normalized()
	
	# Update look component to face mouse
	if look_component:
		look_component.look_mode = LookComponent.LookMode.TARGET
		if dummy_target == null:
			dummy_target = Node2D.new()
			owner.add_child(dummy_target)
		dummy_target.global_position = mouse_pos
		look_component.target = dummy_target

func _update_direct(input: Vector2):
	"""Direct velocity control - instant response"""
	movement.direction = input * movement.speed
	movement.update(get_process_delta_time())

func _update_physics(input: Vector2, delta: float):
	"""Physics-based movement with momentum"""
	if physics_component == null:
		push_warning("PlayerController: Physics mode requires PhysicsMovementComponent")
		_update_direct(input)
		return
	
	if input.length_squared() > 0.01:
		var force = input * move_force
		physics_component.apply_force(force)
	
	# Limit speed
	if movement.velocity.length() > max_speed:
		movement.velocity = movement.velocity.normalized() * max_speed
	
	physics_component.update(delta)

func get_process_delta_time() -> float:
	if owner and owner.get_tree():
		return owner.get_process_delta_time()
	return 0.016  # Fallback ~60fps

func set_control_mode(new_mode: ControlMode):
	control_mode = new_mode

func set_input_mode(new_mode: InputMode):
	input_mode = new_mode
	has_destination = false

func enable_controls():
	controls_enabled = true

func disable_controls():
	controls_enabled = false
	movement.direction = Vector2.ZERO

func get_aim_direction() -> Vector2:
	"""Get aim direction (useful for shooting in twin-stick mode)"""
	return aim_direction

func cleanup():
	"""Clean up created nodes"""
	if dummy_target and is_instance_valid(dummy_target):
		dummy_target.queue_free()
	steering_manager = null
	behavior_builder = null
