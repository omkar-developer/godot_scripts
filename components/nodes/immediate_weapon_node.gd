@tool
@icon("res://scripts/icons/immediate.svg")
class_name ImmediateWeaponNode
extends WeaponNode

## Immediate weapon specific settings
@export var damage_all_in_range: bool = false:
	set(value):
		damage_all_in_range = value
		if immediate_weapon:
			immediate_weapon.damage_all_targets = value
	get:
		return immediate_weapon.damage_all_targets if immediate_weapon else damage_all_in_range

@export var visual_effect_scene: PackedScene = null

@export var spawn_visual_on_damage: bool = true

## Reference to the ImmediateWeapon component
var immediate_weapon: ImmediateWeapon = null

signal damage_dealt(target: Node, result: DamageResult)
signal damage_failed(target: Node)
signal visual_effect_spawned(effect: Node)

func _setup_weapon_component() -> void:
	# Create ImmediateWeapon component with temp pattern
	var temp_immediate = ImmediateWeapon.new(
		self,
		damage_component,
		get_targeting(),
		final_fire_rate.get_value()
	)
	
	# Set initial properties
	temp_immediate.auto_fire = auto_fire
	temp_immediate.damage_all_targets = damage_all_in_range
	
	immediate_weapon = temp_immediate
	# Set as weapon_component for base class
	weapon_component = immediate_weapon

func _bind_stats_to_components() -> void:
	super._bind_stats_to_components()
	
	# No additional stat binding needed for immediate weapons
	# Fire rate is already bound in base class

func _connect_signals() -> void:
	super._connect_signals()
	
	# Connect immediate-specific signals
	if immediate_weapon:
		immediate_weapon.damage_dealt.connect(_on_damage_dealt)
		immediate_weapon.damage_failed.connect(_on_damage_failed)

func _on_damage_dealt(target: Node, result: DamageResult) -> void:
	# Spawn visual effect if configured
	if spawn_visual_on_damage and visual_effect_scene:
		_spawn_visual_effect(target)
	
	damage_dealt.emit(target, result)

func _on_damage_failed(target: Node) -> void:
	damage_failed.emit(target)

func _spawn_visual_effect(target: Node) -> void:
	if not visual_effect_scene:
		return
	
	var effect = visual_effect_scene.instantiate()
	if not effect:
		push_warning("ImmediateWeaponNode: Failed to instantiate visual effect")
		return
	
	# Position effect
	if effect is Node2D and target is Node2D:
		effect.global_position = target.global_position
	
	# Setup effect properties for different effect types
	if "start_position" in effect:
		effect.start_position = global_position
	
	if "end_position" in effect and target is Node2D:
		effect.end_position = target.global_position
	
	if "target" in effect:
		effect.target = target
	
	if "source" in effect:
		effect.source = self
	
	# Add to scene
	var parent = get_parent()
	if parent:
		parent.add_child(effect)
	else:
		get_tree().root.add_child(effect)
	
	visual_effect_spawned.emit(effect)

## Setters for runtime configuration
func set_damage_all_in_range(all: bool) -> void:
	damage_all_in_range = all

func set_visual_effect_scene(scene: PackedScene) -> void:
	visual_effect_scene = scene

func set_spawn_visual_on_damage(enabled: bool) -> void:
	spawn_visual_on_damage = enabled
