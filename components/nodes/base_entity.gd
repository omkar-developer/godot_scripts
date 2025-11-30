@icon("res://scripts/icons/entity.svg")
class_name BaseEntity
extends Area2D

## Base class for all game entities (player, enemies, NPCs).[br]
##[br]
## Provides core components that all entities share: movement, health, damage,[br]
## visual feedback. Extend this for specific entity types (BasePlayer, BaseEnemy).[br]
## Export variables automatically sync with components via setters/getters.

#region Exports - Auto-synced to Components

@export_group("Entity Stats")
@export var max_health: float = 100.0:
	set(value):
		max_health = value
		if health_component:
			health_component.set_max_health(value)
			health_component.current_health = minf(health_component.current_health, value)
	get:
		return health_component.max_health if health_component else max_health

@export var current_health: float = 100.0:
	set(value):
		current_health = value
		if health_component:
			health_component.set_health(value)
	get:
		return health_component.current_health if health_component else current_health

@export var move_speed: float = 200.0:
	set(value):
		move_speed = value
		if movement_component:
			movement_component.speed = value
	get:
		return movement_component.speed if movement_component else move_speed

@export var invulnerable: bool = false:
	set(value):
		invulnerable = value
		if health_component:
			health_component.invulnerable = value
	get:
		return health_component.invulnerable if health_component else invulnerable

@export_group("Damage Settings")
@export var damage_reduction: float = 0.0:
	set(value):
		damage_reduction = value
		if health_component:
			health_component.damage_reduction = value
	get:
		return health_component.damage_reduction if health_component else damage_reduction

@export var damage_multiplier: float = 1.0:
	set(value):
		damage_multiplier = value
		if health_component:
			health_component.damage_multiplier = value
	get:
		return health_component.damage_multiplier if health_component else damage_multiplier

@export_group("Defense Settings")
@export var iframe_duration: float = 0.0:
	set(value):
		iframe_duration = value
		if health_component:
			health_component.iframe_duration = value
	get:
		return health_component.iframe_duration if health_component else iframe_duration

@export var iframe_enabled: bool = true:
	set(value):
		iframe_enabled = value
		if health_component:
			health_component.iframe_enabled = value
	get:
		return health_component.iframe_enabled if health_component else iframe_enabled

@export_group("Movement Settings")
@export var movement_enabled: bool = true:
	set(value):
		movement_enabled = value
		if movement_component:
			movement_component.enabled = value
	get:
		return movement_component.enabled if movement_component else movement_enabled

@export var look_enabled: bool = true:
	set(value):
		look_enabled = value
		if look_component:
			look_component.active = value
	get:
		return look_component.active if look_component else look_enabled

@export var look_mode: LookComponent.LookMode = LookComponent.LookMode.VELOCITY:
	set(value):
		look_mode = value
		if look_component:
			look_component.look_mode = value
	get:
		return look_component.look_mode if look_component else look_mode

@export var look_speed: float = 6.0:
	set(value):
		look_speed = value
		if look_component:
			look_component.rotation_speed = value
	get:
		return look_component.rotation_speed if look_component else look_speed

@export_group("Visual Feedback")
@export var show_damage_numbers: bool = true
@export var damage_number_offset: Vector2 = Vector2(0, -20)

#endregion

#region Component References

var movement_component: MovementComponent
var health_component: HealthComponent
var look_component: LookComponent
var damage_component: DamageComponent
var floating_text_component: FloatingTextComponent
var label_spawner: LabelSpawner

var using_local_text_spawner: bool = false

#endregion

#region Static & Internal

static var shared_label_spawner: LabelSpawner = null
var _initialized: bool = false

#endregion

#region Initialization

func _init() -> void:
	_create_core_components()


func _create_core_components() -> void:
	# Movement component
	var _movement_component = MovementComponent.new(self, move_speed)
	_movement_component.enabled = movement_enabled
	movement_component = _movement_component
	
	# Health component
	var _health_component = HealthComponent.new(
		self,
		max_health,
		iframe_duration,
		false,  # shield_enabled
		0.0,    # max_shield
		0.0,    # max_damage_per_hit
		false   # prevent_death_once
	)
	_health_component.damage_reduction = damage_reduction
	_health_component.damage_multiplier = damage_multiplier
	_health_component.iframe_enabled = iframe_enabled
	health_component = _health_component
	
	# Look component
	var _look_component = LookComponent.new(movement_component)
	_look_component.look_mode = look_mode
	_look_component.active = look_enabled
	_look_component.rotation_speed = look_speed
	look_component = _look_component
	
	# Damage component (for dealing damage to others)
	var _damage_component = DamageComponent.new(self)
	damage_component = _damage_component
	
	_initialized = true


func _ready() -> void:
	_setup_visual_feedback()
	_connect_signals()


func _setup_visual_feedback() -> void:
	if not show_damage_numbers:
		return
	
	# Use shared spawner if available, otherwise create local one
	if shared_label_spawner == null and label_spawner == null:
		label_spawner = LabelSpawner.new(get_parent(), 20)
		label_spawner.configure_defaults(16, true, Color.BLACK, 2)
	else:
		label_spawner = shared_label_spawner
	
	if floating_text_component == null:
		floating_text_component = FloatingTextComponent.new(self, get_parent(), label_spawner)
		floating_text_component.float_speed = 60.0
		floating_text_component.duration = 1.2
		using_local_text_spawner = true


func _connect_signals() -> void:
	if health_component:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
		health_component.healed.connect(_on_healed)

#endregion

#region Update Loop

func _process(delta: float) -> void:
	if not _initialized:
		return
	
	_update_components(delta)


func _update_components(delta: float) -> void:
	if movement_component:
		movement_component.update(delta)
	
	if health_component:
		health_component.update(delta)
	
	if look_component and look_enabled:
		look_component.update(delta)
	
	if floating_text_component and using_local_text_spawner:
		floating_text_component.update(delta)

#endregion

#region Signal Handlers

func _on_damage_taken(result: DamageResult) -> void:
	if show_damage_numbers and floating_text_component:
		var damage = result.actual_damage
		var is_crit = result.was_critical
		
		# Spawn damage number with offset
		var damage_pos = global_position + damage_number_offset
		var color = Color.ORANGE_RED if is_crit else Color.RED
		var text = str(int(damage))
		
		if is_crit:
			text = "CRIT! " + text
		
		floating_text_component.spawn_text_at_position(
			text,
			damage_pos,
			color,
			FloatingTextComponent.AnimationStyle.SCALE_POP if is_crit else FloatingTextComponent.AnimationStyle.FLOAT_UP_FADE
		)
	
	# Override this for custom damage reactions
	_on_damage_received(result)


func _on_died() -> void:
	if show_damage_numbers and floating_text_component:
		floating_text_component.spawn_text_at_position(
			"DEFEATED",
			global_position,
			Color.DARK_RED,
			FloatingTextComponent.AnimationStyle.SCALE_POP
		)
	
	_on_death()


func _on_healed(amount: float) -> void:
	if show_damage_numbers and floating_text_component:
		var heal_pos = global_position + damage_number_offset
		floating_text_component.spawn_text_at_position(
			"+" + str(int(amount)),
			heal_pos,
			Color.GREEN,
			FloatingTextComponent.AnimationStyle.FLOAT_UP_FADE
		)
	
	_on_heal_received(amount)

#endregion

#region Virtual Methods - Override in Child Classes

## Called when entity takes damage (after visual feedback)
func _on_damage_received(_result: DamageResult) -> void:
	pass

## Called when entity dies (before destruction)
func _on_death() -> void:
	queue_free()

## Called when entity heals
func _on_heal_received(_amount: float) -> void:
	pass

#endregion

#region Public API - Combat

## Deal damage to another entity
func attack(target_health: HealthComponent) -> DamageResult:
	if not damage_component:
		return null
	# TODO: Add attack logic
	return null


## Take damage from a source
func take_damage(damage_request: DamageRequest) -> DamageResult:
	if not health_component:
		return null
	
	return health_component.process_damage(damage_request)


## Heal this entity
func heal(amount: float) -> float:
	if not health_component:
		return 0.0
	
	return health_component.heal(amount)


## Kill this entity instantly
func kill() -> void:
	if health_component:
		health_component.force_kill()


## Add resistance to damage type
func add_resistance(damage_type: int, resistance: float) -> void:
	if health_component:
		health_component.set_resistance(damage_type, resistance)


## Add damage immunity
func add_damage_immunity(damage_type: int) -> void:
	if health_component:
		health_component.add_damage_immunity(damage_type)


## Remove damage immunity
func remove_damage_immunity(damage_type: int) -> void:
	if health_component:
		health_component.remove_damage_immunity(damage_type)

#endregion

#region Public API - Status Queries

## Check if entity is dead
func is_dead() -> bool:
	return health_component.is_dead if health_component else false


## Check if entity is at full health
func is_full_health() -> bool:
	return health_component.is_full_health() if health_component else false


## Check if invulnerable (dead or iframes)
func is_invulnerable() -> bool:
	return health_component.is_invulnerable() if health_component else false


## Get current health value
func get_health() -> float:
	return health_component.get_health() if health_component else 0.0


## Get max health value
func get_max_health() -> float:
	return health_component.get_max_health() if health_component else 0.0


## Get health percentage (0.0 to 1.0)
func get_health_percent() -> float:
	if not health_component:
		return 0.0
	return health_component.get_health() / health_component.get_max_health()


## Get iframe remaining time
func get_iframe_remaining() -> float:
	return health_component.get_iframe_remaining() if health_component else 0.0

#endregion

#region Public API - Movement

## Set movement direction
func set_direction(direction: Vector2) -> void:
	if movement_component:
		movement_component.direction = direction


## Get current movement direction
func get_direction() -> Vector2:
	return movement_component.direction if movement_component else Vector2.ZERO


## Get current velocity
func get_velocity() -> Vector2:
	return movement_component.velocity if movement_component else Vector2.ZERO


## Get current speed
func get_speed() -> float:
	return movement_component.speed if movement_component else 0.0

#endregion

#region Public API - Utilities

## Static method to set shared label spawner for all entities
static func set_shared_label_spawner(spawner: LabelSpawner) -> void:
	shared_label_spawner = spawner


## Get component statistics (for debugging)
func get_stats() -> Dictionary:
	return {
		"health": get_health(),
		"max_health": get_max_health(),
		"health_percent": get_health_percent(),
		"speed": get_speed(),
		"is_dead": is_dead(),
		"is_invulnerable": is_invulnerable(),
		"position": global_position,
		"velocity": get_velocity(),
		"iframe_remaining": get_iframe_remaining(),
		"movement_enabled": movement_enabled,
		"look_enabled": look_enabled
	}

#endregion
