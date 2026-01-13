class_name WaveController
extends Node

## Manages wave progression and enemy difficulty scaling

@export_group("References")
@export var spawner: Spawner2D
@export var player: Node

@export_group("Wave Mode")
@export_enum("Infinite", "Fixed Count", "Time Limited") 
var wave_mode: String = "Infinite"

## For Fixed Count mode
@export var total_waves: int = 10

## For Time Limited mode (seconds, 0 = infinite)
@export var game_duration: float = 1200.0

## Time per wave (for wave milestones)
@export var wave_duration: float = 60.0

@export_group("Difficulty Scaling")
## Properties to scale on spawned enemies
@export var properties_to_scale: Array[String] = ["health", "damage"]

## Scaling formula
@export_enum("Linear", "Exponential", "Logarithmic") 
var scaling_formula: String = "Exponential"

## Per-property multipliers (per wave)
@export var property_multipliers: Dictionary = {
	"health": 1.15,
	"damage": 1.10,
	"speed": 1.05
}

## Linear scaling additive values (per wave)
@export var property_additions: Dictionary = {
	"health": 0.0,
	"damage": 0.0
}

@export_group("Spawn Scaling")
## Spawn rate multiplier per wave
@export var spawn_rate_multiplier: float = 0.95

## Max alive increase per wave
@export var max_alive_per_wave: int = 10

@export_group("Options")
@export var auto_start: bool = false
@export var pause_between_waves: bool = false
@export var pause_duration: float = 3.0

## --- State ---
var game_time: float = 0.0
var current_wave: int = 0
var is_playing: bool = false
var is_paused_between_waves: bool = false
var pause_timer: float = 0.0

## Cache initial spawner values
var initial_spawn_interval: float
var initial_max_alive: int

## --- Signals ---
signal game_started()
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)  # For time-based waves
signal game_over()
signal victory()
signal between_waves_started(next_wave: int)
signal between_waves_ended()


func _ready() -> void:
	if not spawner:
		push_error("WaveController: No spawner assigned!")
		return
	
	if not player:
		push_error("WaveController: No player assigned!")
		return
	
	# Cache initial values
	initial_spawn_interval = spawner.spawn_interval
	initial_max_alive = spawner.max_alive
	
	# Connect to spawner
	spawner.entity_spawned.connect(_on_entity_spawned)
	
	if auto_start:
		call_deferred("start_game")


func start_game() -> void:
	if is_playing:
		return
	
	game_time = 0.0
	current_wave = 0
	is_playing = true
	
	# Start spawning
	if not spawner.is_spawning:
		spawner.start_spawning()
	
	game_started.emit()
	wave_started.emit(0)
	print("[WaveController] Game started")


func stop_game() -> void:
	is_playing = false
	
	if spawner and spawner.is_spawning:
		spawner.stop_spawning()


func _process(delta: float) -> void:
	if not is_playing:
		return
	
	# Handle pause between waves
	if is_paused_between_waves:
		pause_timer -= delta
		if pause_timer <= 0.0:
			_end_wave_pause()
		return
	
	# Update time
	game_time += delta
	
	# Check for wave milestone
	var new_wave = floori(game_time / wave_duration)
	if new_wave > current_wave:
		_advance_to_wave(new_wave)
	
	# Check victory conditions
	match wave_mode:
		"Fixed Count":
			if current_wave >= total_waves:
				_on_victory()
		
		"Time Limited":
			if game_duration > 0 and game_time >= game_duration:
				_on_victory()
	
	# Check game over
	_check_game_over()


func _advance_to_wave(wave_num: int) -> void:
	wave_ended.emit(current_wave)
	current_wave = wave_num
	
	print("[WaveController] Wave %d started" % current_wave)
	
	# Apply difficulty scaling
	_apply_wave_scaling()
	
	# Pause between waves if enabled
	if pause_between_waves:
		_start_wave_pause()
	
	wave_started.emit(current_wave)


func _start_wave_pause() -> void:
	is_paused_between_waves = true
	pause_timer = pause_duration
	get_tree().paused = true
	between_waves_started.emit(current_wave + 1)


func _end_wave_pause() -> void:
	is_paused_between_waves = false
	get_tree().paused = false
	between_waves_ended.emit()


func _apply_wave_scaling() -> void:
	if current_wave == 0:
		return
	
	# Scale spawn rate
	spawner.spawn_interval = initial_spawn_interval * pow(spawn_rate_multiplier, current_wave)
	
	# Scale max alive
	spawner.max_alive = initial_max_alive + (max_alive_per_wave * current_wave)
	
	print("[WaveController] Scaled: interval=%.2f, max_alive=%d" % [
		spawner.spawn_interval,
		spawner.max_alive
	])


func _on_entity_spawned(entity: Node, _scene_index: int) -> void:
	# Scale entity properties based on current wave
	if current_wave == 0:
		return  # No scaling on wave 0
	
	for property_name in properties_to_scale:
		if not property_name in entity:
			continue
		
		var base_value = entity.get(property_name)
		var scaled_value = _calculate_scaled_value(property_name, base_value, current_wave)
		entity.set(property_name, scaled_value)


func _calculate_scaled_value(property_name: String, base_value: float, wave: int) -> float:
	var multiplier = property_multipliers.get(property_name, 1.0)
	var addition = property_additions.get(property_name, 0.0)
	
	var scaled: float
	
	match scaling_formula:
		"Linear":
			# value = base + (addition * wave)
			scaled = base_value + (addition * wave)
		
		"Exponential":
			# value = base * (multiplier ^ wave)
			scaled = base_value * pow(multiplier, wave)
		
		"Logarithmic":
			# value = base * (1 + log(wave + 1) * multiplier)
			scaled = base_value * (1.0 + log(wave + 1) * (multiplier - 1.0))
		
		_:
			scaled = base_value
	
	return scaled


func _check_game_over() -> void:
	if not player:
		return
	
	var is_dead = false
	
	if player.has_method("is_dead"):
		is_dead = player.is_dead()
	elif "health" in player:
		is_dead = player.health <= 0
	
	if is_dead:
		_on_game_over()


func _on_game_over() -> void:
	print("[WaveController] Game Over at wave %d" % current_wave)
	stop_game()
	game_over.emit()


func _on_victory() -> void:
	print("[WaveController] Victory!")
	stop_game()
	victory.emit()


## Get current wave number
func get_current_wave() -> int:
	return current_wave


## Get time elapsed
func get_game_time() -> float:
	return game_time


## Get progress to next wave (0.0 to 1.0)
func get_wave_progress() -> float:
	var wave_start = current_wave * wave_duration
	var time_in_wave = game_time - wave_start
	return clampf(time_in_wave / wave_duration, 0.0, 1.0)


## Manually advance wave (for testing)
func advance_wave() -> void:
	_advance_to_wave(current_wave + 1)


## Get scaling multiplier for a property at current wave
func get_current_multiplier(property_name: String) -> float:
	if current_wave == 0:
		return 1.0
	
	var base_mult = property_multipliers.get(property_name, 1.0)
	
	match scaling_formula:
		"Exponential":
			return pow(base_mult, current_wave)
		"Linear":
			return 1.0 + ((base_mult - 1.0) * current_wave)
		"Logarithmic":
			return 1.0 + log(current_wave + 1) * (base_mult - 1.0)
	
	return 1.0
