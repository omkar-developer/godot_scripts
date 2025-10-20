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
@export var collection_range: float = 150.0:
	set(value):
		collection_range = value
		if collection_range_stat:
			collection_range_stat.set_base_value(value)
	get:
		return collection_range_stat.get_value() if collection_range_stat else collection_range

@export var magnetic_collection: bool = true:
	set(value):
		magnetic_collection = value
		if collection_component:
			collection_component.magnetic_enabled = value
	get:
		return collection_component.magnetic_enabled if collection_component else magnetic_collection

@export var magnetic_strength: float = 400.0:
	set(value):
		magnetic_strength = value
		if magnetic_strength_stat:
			magnetic_strength_stat.set_base_value(value)
	get:
		return magnetic_strength_stat.get_value() if magnetic_strength_stat else magnetic_strength

@export_group("Targeting")
@export var targeting_range: float = 300.0:
	set(value):
		targeting_range = value
		if targeting_range_stat:
			targeting_range_stat.set_base_value(value)
	get:
		return targeting_range_stat.get_value() if targeting_range_stat else targeting_range

#endregion

#region Component References - Player-Specific

var controller: PlayerController
var collection_component: CollectionComponent
var targeting_component: TargetingComponent

## Stats for dynamic gameplay values that can be buffed/debuffed
var health_stat: Stat
var collection_range_stat: Stat
var magnetic_strength_stat: Stat
var targeting_range_stat: Stat

## Detection areas (created in scene or code)
var collection_detection_area: Area2D = null
var collection_area: Area2D = null
var targeting_area: Area2D = null

## Collision shapes for dynamic resizing
var collection_shape: CollisionShape2D = null
var targeting_shape: CollisionShape2D = null

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
	
	# Collection range stat - can be buffed/debuffed during gameplay
	collection_range_stat = Stat.new(collection_range, true, 0.0, 1000.0)
	
	# Magnetic strength stat - can be buffed/debuffed
	magnetic_strength_stat = Stat.new(magnetic_strength, true, 0.0, 2000.0)
	
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
	# Setup player-specific systems
	if collection_enabled:
		_setup_collection()
	
	# Setup targeting (used later by weapon node)
	_setup_targeting()
	
	_setup_ui_bindings()	

func _ready() -> void:
	super._ready()

func _setup_collection() -> void:
	# Try to find collection area in children
	collection_detection_area = get_node_or_null("CollectionDetectionArea")
	collection_area = get_node_or_null("CollectionArea")
	
	if not collection_detection_area:
		# Create collection area programmatically
		collection_detection_area = Area2D.new()
		collection_detection_area.name = "CollectionDetectionArea"
		add_child(collection_detection_area)
		
		collection_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = collection_range_stat.get_value()
		collection_shape.shape = circle
		collection_detection_area.add_child(collection_shape)
	else:
		# Find existing shape
		collection_shape = collection_detection_area.get_node_or_null("CollisionShape2D")
		if not collection_shape:
			for child in collection_detection_area.get_children():
				if child is CollisionShape2D:
					collection_shape = child
					break
	
	if not is_instance_valid(collection_area):
		collection_area = self
	
	# Create collection component with temp variable to avoid getter loopback
	var _collection_component = CollectionComponent.new(self, collection_detection_area, collection_area)
	_collection_component.set_collection_mode(CollectionComponent.CollectionMode.AUTOMATIC)
	_collection_component.magnetic_enabled = magnetic_collection
	_collection_component.magnetic_strength = magnetic_strength_stat.get_value()
	_collection_component.detection_range = collection_range_stat.get_value()
	collection_component = _collection_component
	
	# Bind stats to component properties and collision shape
	_bind_collection_stats()
	
	# Connect collection signals
	collection_component.item_collected.connect(_on_item_collected)
	collection_component.item_detected.connect(_on_item_detected)


func _bind_collection_stats() -> void:
	# Bind collection range stat to component's detection_range
	collection_range_stat.bind_to_property(collection_component, "detection_range")
	
	# Bind collection range stat to the Area2D collision shape radius
	if collection_shape and collection_shape.shape is CircleShape2D:
		collection_range_stat.bind_to_property(collection_shape.shape, "radius")
	
	# Bind magnetic strength stat to component
	magnetic_strength_stat.bind_to_property(collection_component, "magnetic_strength")


# New: targeting setup and bindings
func _setup_targeting() -> void:
	# Try to find targeting area in children
	targeting_area = get_node_or_null("TargetingArea")
	
	if not targeting_area:
		# Create targeting area programmatically
		targeting_area = Area2D.new()
		targeting_area.name = "TargetingArea"
		add_child(targeting_area)
		
		targeting_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = targeting_range_stat.get_value()
		targeting_shape.shape = circle
		targeting_area.add_child(targeting_shape)
	else:
		# Find existing shape
		targeting_shape = targeting_area.get_node_or_null("CollisionShape2D")
		if not targeting_shape:
			for child in targeting_area.get_children():
				if child is CollisionShape2D:
					targeting_shape = child
					break
	
	# Create targeting component with temp variable to avoid getter loopback
	var _targeting_component = TargetingComponent.new(self, targeting_area)
	_targeting_component.detection_range = targeting_range_stat.get_value()
	targeting_component = _targeting_component
	
	# Bind targeting range stat to component and collision shape
	_bind_targeting_stats()


func _bind_targeting_stats() -> void:
	# Bind targeting range stat to component's detection_range
	targeting_range_stat.bind_to_property(targeting_component, "detection_range")
	
	# Bind targeting range stat to the Area2D collision shape radius
	if targeting_shape and targeting_shape.shape is CircleShape2D:
		targeting_range_stat.bind_to_property(targeting_shape.shape, "radius")


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
	
	if collection_component:
		collection_component.update(delta)
	
	if targeting_component:
		targeting_component.update(delta)
	
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


## Toggle magnetic collection
func toggle_magnetic_collection() -> void:
	if collection_component:
		magnetic_collection = not magnetic_collection # Use setter


## Set collection mode
func set_collection_mode(mode: CollectionComponent.CollectionMode) -> void:
	if collection_component:
		collection_component.set_collection_mode(mode)


## Collect all items in range
func collect_all_items() -> int:
	if collection_component:
		return collection_component.collect_all()
	return 0

#endregion

#region Public API - Player Queries

## Get nearest collectible
func get_nearest_collectible() -> Node:
	if collection_component:
		var items = collection_component.get_detected_items()
		if not items.is_empty():
			return items[0]
	return null


## Get nearest enemy
func get_nearest_enemy() -> Node:
	if targeting_component:
		return targeting_component.get_best_target()
	return null


## Get number of items detected
func get_detected_item_count() -> int:
	return collection_component.get_detected_count() if collection_component else 0


## Get number of enemies in range
func get_enemy_count() -> int:
	return targeting_component.get_target_count() if targeting_component else 0

#endregion

#region Public API - Stat System

## Get stat by name for buff/debuff system
## Valid stat names: "health", "range", "magnet"
func get_stat(stat_name: String) -> Stat:
	match stat_name:
		"health":
			return health_stat
		"range":
			return collection_range_stat
		"magnet":
			return magnetic_strength_stat
		_:
			push_error("BasePlayer: Unknown stat name '%s'" % stat_name)
			return null

#endregion
