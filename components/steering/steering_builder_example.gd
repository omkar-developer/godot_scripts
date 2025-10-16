extends Node2D  
var movement_component: MovementComponent
var steering_manager_component: SteeringManagerComponent 
var look_component: LookComponent
var behavior_builder: SteeringBehaviorBuilder

# AI behavior type
enum AIType {
	BASIC,
	FLOCKING,
	PATROL,
	PREDATOR,
	PREY,
	GUARD,
	EXPLORER
}

@export var ai_type: AIType = AIType.BASIC
@export var patrol_points: Array[Vector2] = []
@export var guard_position: Vector2
@export var exploration_bounds: Rect2 = Rect2(0, 0, 800, 600)

func _ready():
	# Initialize components
	movement_component = MovementComponent.new($Sprite2D, 200.0)
	steering_manager_component = SteeringManagerComponent.new($Sprite2D, movement_component)
	look_component = LookComponent.new(movement_component)
	
	# Create behavior builder
	behavior_builder = SteeringBehaviorBuilder.create(
		$Sprite2D, 
		movement_component, 
		steering_manager_component
	)
	
	# Configure builder settings
	behavior_builder.set_obstacle_mask(1).set_agent_mask(2).set_ray_length(120.0)
	
	# Setup AI behavior based on type
	setup_ai_behavior()

func setup_ai_behavior():
	match ai_type:
		AIType.BASIC:
			behavior_builder.basic_ai($Target, 100.0, 15.0)
			
		AIType.FLOCKING:
			behavior_builder.flocking($Target, 120.0)
			
		AIType.PATROL:
			if patrol_points.is_empty():
				patrol_points = [Vector2(100, 100), Vector2(300, 100), Vector2(300, 300), Vector2(100, 300)]
			behavior_builder.patrol(patrol_points, 25.0)
			
		AIType.PREDATOR:
			behavior_builder.predator($Target, 250.0)
			
		AIType.PREY:
			behavior_builder.prey($Target, 180.0, 0.8)
			
		AIType.GUARD:
			if guard_position == Vector2.ZERO:
				guard_position = global_position
			behavior_builder.guard(guard_position, 100.0, 200.0, $Target)
			
		AIType.EXPLORER:
			behavior_builder.explorer(exploration_bounds)

func _process(delta):
	$Target.position = get_global_mouse_position()
	steering_manager_component.update(delta)
	movement_component.update(delta)
	look_component.update(delta)

# Dynamic behavior switching
func switch_to_basic_ai():
	behavior_builder.clear_behaviors().basic_ai($Target)

func switch_to_flocking():
	behavior_builder.clear_behaviors().flocking($Target)

func switch_to_predator_mode():
	behavior_builder.clear_behaviors().predator($Target, 200.0)

func switch_to_prey_mode():
	behavior_builder.clear_behaviors().prey($Target, 150.0, 0.6)

# Add custom behaviors on top of presets
func add_wandering(strength: float = 0.3):
	behavior_builder.add_custom_behavior(
		WanderSteering.new(40.0, 70.0, 25.0, $Sprite2D, movement_component),
		strength
	)

func make_more_aggressive():
	behavior_builder.adjust_behavior_weight("SeekSteering", 2.0)
	behavior_builder.adjust_behavior_weight("OptimizedRaycastAvoidance", 1.5)

# Example of hybrid behaviors
func create_hybrid_behavior():
	behavior_builder.clear_behaviors()
	
	# Custom combination: Patrol with flocking tendencies
	behavior_builder.patrol(patrol_points, 30.0)  # Base patrol
	
	# Add flocking elements
	behavior_builder.add_custom_behavior(
		PhysicsQuerySeparation.new(50.0, 2, 120.0, $Sprite2D, movement_component),
		1.0
	)
	behavior_builder.add_custom_behavior(
		AlignmentSteering.new(80.0, 2, $Sprite2D, movement_component),
		0.5
	)

# Input handling for testing different behaviors
func _input(event):
	if event.is_action_pressed("ui_accept"):
		switch_to_basic_ai()
	elif event.is_action_pressed("ui_select"):
		switch_to_flocking()
	elif event.is_action_pressed("ui_cancel"):
		switch_to_predator_mode()
	elif event.is_action_pressed("ui_home"):
		switch_to_prey_mode()

func _draw():
	# Visual debug for current behavior
	var color = Color.WHITE
	match ai_type:
		AIType.BASIC: color = Color.BLUE
		AIType.FLOCKING: color = Color.GREEN
		AIType.PATROL: color = Color.YELLOW
		AIType.PREDATOR: color = Color.RED
		AIType.PREY: color = Color.PINK
		AIType.GUARD: color = Color.ORANGE
		AIType.EXPLORER: color = Color.PURPLE
	
	draw_circle(Vector2.ZERO, 5, color)