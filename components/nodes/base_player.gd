@icon("res://scripts/icons/player.svg")
class_name BasePlayer
extends BaseEntity

## Base player class with controller, collection, and weapon support.[br]
##[br]
## Extends BaseEntity with player-specific features: input control, item collection,[br>
## weapon systems, stat system for buffs, and UI binding. Use this as base for all player types.

#region Exports - Player-Specific Settings

@export_group("Player Settings")
@export var control_mode: PlayerController.ControlMode = PlayerController.ControlMode.PHYSICS:
	set(value):
		control_mode = value
		if controller:
			controller.set_control_mode(value)
	get:
		return controller.control_mode if controller else control_mode

@export var input_mode: PlayerController.InputMode = PlayerController.InputMode.WASD:
	set(value):
		input_mode = value
		if controller:
			controller.set_input_mode(value)
	get:
		return controller.input_mode if controller else input_mode

@export_group("Collection")
@export var collection_enabled: bool = true

@export_group("Targeting")
@export var targeting_range: float = 300.0:
	set(value):
		targeting_range = value
		if targeting_range_stat:
			targeting_range_stat.set_base_value(value)
	get:
		return targeting_range_stat.get_value() if targeting_range_stat else targeting_range

@export_flags_2d_physics var target_collision_layer: int = 1 << 3: ## does not work on child/global targeting area
	set(v):
		target_collision_layer = v
		if targeting_area:
			targeting_area.collision_layer = v
			
@export_flags_2d_physics var target_collision_mask: int = 2: ## does not work on child/global targeting area
	set(v):
		target_collision_mask = v
		if targeting_area:
			targeting_area.collision_mask = v

@export_group("Stats")
## TODO: Mores stats
## Stats for dynamic gameplay values that can be buffed/debuffed
@export var health_stat: Stat
@export var targeting_range_stat: Stat

#endregion

#region Component References - Player-Specific

var controller: PlayerController
var targeting_area: TargetingArea

## UI References (optional - can be bound externally)
var health_bar: Range = null
var energy_bar: Range = null

#endregion

#region Initialization

func _init() -> void:
	super._init()
	_create_player_stats()
	_create_player_components()


func _create_player_stats() -> void:
	# Health stat for buffs/UI (player needs this, enemies don't)
	health_stat = Stat.new(max_health, true, 0.0, max_health)
	
	# Targeting range stat - used by targeting component
	targeting_range_stat = Stat.new(targeting_range, true, 0.0, 1000.0)


func _create_player_components() -> void:
	# Bind health component to stat
	if health_component:
		health_component.bind_health_stat(health_stat)
	
	# Player controller - use temp variable to avoid getter loopback
	var _controller = PlayerController.new(movement_component)
	_controller.set_look_component(look_component)
	_controller.setup_physics(1.0, false, 300.0)
	_controller.move_force = 1000.0
	_controller.set_control_mode(control_mode)
	_controller.set_input_mode(input_mode)
	controller = _controller

func _enter_tree() -> void:
	# Setup targeting (used later by weapon node)
	_setup_targeting()
	
	_setup_ui_bindings()	

func _ready() -> void:
	super._ready()


func _bind_collection_stats() -> void:
	# Bind collection range stat to the Area2D collision shape radius
	#if collection_shape and collection_shape.shape is CircleShape2D:
		#collection_range_stat.bind_to_property(collection_shape.shape, "radius")
	pass


func _setup_targeting() -> void:
	# Try to find TargetingArea in children
	targeting_area = get_node_or_null("TargetingArea") as TargetingArea
	
	if not targeting_area:
		# Create TargetingArea programmatically
		targeting_area = TargetingArea.new()
		targeting_area.name = "TargetingArea"
		targeting_area.collision_layer = target_collision_layer
		targeting_area.collision_mask = target_collision_mask
		add_child(targeting_area)
		
		# Create collision shape for it
		var targeting_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = targeting_range_stat.get_value()
		targeting_shape.shape = circle
		targeting_area.add_child(targeting_shape)
	
	# Configure targeting component
	targeting_area.detection_range = targeting_range_stat.get_value()
	
	# Bind targeting range stat to component
	_bind_targeting_stats()


func _bind_targeting_stats() -> void:
	# Bind targeting range stat to component's detection_range
	if targeting_area:
		targeting_range_stat.bind_to_property(targeting_area, "detection_range")


func _setup_ui_bindings() -> void:
	# Try to find health bar in children
	health_bar = %HealthBar
	energy_bar = %EnergyBar
	
	# Bind health stat to health bar
	if health_bar and health_stat:
		health_stat.bind_max_to_property(health_bar, "max_value")
		health_stat.bind_to_property(health_bar, "value")

#endregion

#region Update Loop

func _process(delta: float) -> void:	
	# Update player-specific components
	if controller:
		controller.update(delta)
	
	super._process(delta)

#endregion

#region Signal Handlers - Collection

func _on_item_collected(item: Node, item_type: String) -> void:
	var value = item.get_meta("value", 0)
	
	# Show floating text at item position
	if value > 0 and show_damage_numbers and floating_text_component:
		if is_instance_valid(item) and item is Node2D:
			var item_pos = (item as Node2D).global_position
			
			var styles = [
				FloatingTextComponent.AnimationStyle.FLOAT_UP_FADE,
				FloatingTextComponent.AnimationStyle.ARC_LEFT,
				FloatingTextComponent.AnimationStyle.ARC_RIGHT,
				FloatingTextComponent.AnimationStyle.SCALE_POP
			]
			
			var color = Color.YELLOW if item_type == "coin" else Color.CYAN
			floating_text_component.spawn_text_at_position(
				"+" + str(value),
				item_pos,
				color,
				styles.pick_random()
			)
	
	# Override this for custom collection behavior
	_on_collect_item(item, item_type, value)
	item.queue_free()


func _on_item_detected(_item: Node) -> void:
	pass

#endregion

#region Virtual Methods - Player Events

## Override for custom item collection behavior
func _on_collect_item(_item: Node, _item_type: String, _value: int) -> void:
	pass

#endregion

#region Public API - Player Control

## Fire weapon manually
func fire_weapon() -> void:
	return

#endregion

#region Public API - Player Queries


## Get nearest enemy
func get_nearest_enemy() -> Node:
	if targeting_area:
		return targeting_area.get_best_target()
	return null

## Get number of enemies in range
func get_enemy_count() -> int:
	return targeting_area.get_target_count() if targeting_area else 0

#endregion

#region Public API - Stat System

## Get stat by name for buff/debuff system
## Valid stat names: "health", "range", "magnet"
func get_stat(stat_name: String) -> Stat:
	match stat_name:
		"health":
			return health_stat
		_:
			push_error("BasePlayer: Unknown stat name '%s'" % stat_name)
			return null

#endregion
