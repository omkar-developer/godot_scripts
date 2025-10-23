class_name CameraShakeComponent
extends RefCounted

## Professional camera shake system with trauma-based intensity and multiple shake patterns.[br]
##[br]
## Implements GDC talk "Math for Game Programmers: Juicing Your Cameras With Math"[br]
## Uses trauma system where trauma decays over time and shake intensity is trauma squared.[br]
## Supports directional shakes, rotation, and customizable noise patterns.

## Shake pattern types
enum ShakePattern {
	RANDOM,         ## Pure random offset each frame
	PERLIN,         ## Smooth Perlin-like noise
	SINE_WAVE,      ## Sine wave oscillation
	BOUNCE,         ## Bouncy decay pattern
	CUSTOM          ## Custom shake function
}

## Reference to Camera2D being shaken
var camera: Camera2D = null

## Current trauma level (0.0 to 1.0)
var trauma: float = 0.0

## How fast trauma decays per second (1.0 = full decay in 1 second)
var trauma_decay: float = 1.5

## Maximum shake offset in pixels
var max_offset: float = 100.0

## Maximum shake rotation in radians
var max_rotation: float = 0.1

## Trauma exponent (higher = less shake at low trauma)
var trauma_power: float = 2.0

## Shake frequency (higher = faster shaking)
var shake_frequency: float = 15.0

## Current shake pattern
var shake_pattern: ShakePattern = ShakePattern.PERLIN

## Custom shake function: func(time: float, trauma_amount: float) -> Vector3 (x, y, rotation)
var custom_shake_func: Callable = Callable()

## Whether rotation shake is enabled
var rotation_enabled: bool = true

## Whether component is enabled
var enabled: bool = true

## Directional shake bias (0,0 = all directions, (1,0) = horizontal only)
var directional_bias: Vector2 = Vector2.ZERO

## Internal time accumulator for noise
var _time: float = 0.0

## Random seed for consistent shake patterns
var _noise_seed: int = 0

## Original camera offset (to restore after shake)
var _original_offset: Vector2 = Vector2.ZERO

## Original camera rotation
var _original_rotation: float = 0.0

## Whether we've stored original values
var _has_original: bool = false

## Emitted when shake starts
signal shake_started(trauma_amount: float)

## Emitted when shake ends
signal shake_ended()

## Emitted when trauma changes significantly
signal trauma_changed(new_trauma: float)


func _init(_camera: Camera2D = null) -> void:
	if _camera:
		set_camera(_camera)
	_noise_seed = randi()


## Set the camera to shake.[br]
## [param cam]: Camera2D node.
func set_camera(cam: Camera2D) -> void:
	camera = cam
	if camera:
		_store_original_state()


## Add trauma to the camera (0.0 to 1.0).[br]
## [param amount]: Trauma amount to add.[br]
## [param override_existing]: If true, replaces current trauma instead of adding.
func add_trauma(amount: float, override_existing: bool = false) -> void:
	var old_trauma = trauma
	
	if override_existing:
		trauma = clampf(amount, 0.0, 1.0)
	else:
		trauma = clampf(trauma + amount, 0.0, 1.0)
	
	if old_trauma == 0.0 and trauma > 0.0:
		shake_started.emit(trauma)
	
	if abs(trauma - old_trauma) > 0.1:
		trauma_changed.emit(trauma)


## Convenient shake presets for common game events.[br]
## [param intensity]: "light", "medium", "heavy", or "extreme".
func shake_preset(intensity: String) -> void:
	match intensity.to_lower():
		"light":
			add_trauma(0.2)
		"medium":
			add_trauma(0.4)
		"heavy":
			add_trauma(0.7)
		"extreme":
			add_trauma(1.0)
		_:
			add_trauma(0.3)


## Quick shake with automatic trauma amount.[br]
## [param strength]: Shake strength (0.0 to 1.0).
func shake(strength: float = 0.5) -> void:
	add_trauma(strength)


## Update shake (call in _process).[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	if not enabled or not camera or not is_instance_valid(camera):
		return
	
	# Store original state if not done yet
	if not _has_original:
		_store_original_state()
	
	# Decay trauma
	if trauma > 0.0:
		trauma = maxf(trauma - trauma_decay * delta, 0.0)
		
		if trauma == 0.0:
			_reset_camera()
			shake_ended.emit()
			return
	else:
		_reset_camera()
		return
	
	# Update time
	_time += delta
	
	# Calculate shake amount (trauma^power for better feel)
	var shake_amount = pow(trauma, trauma_power)
	
	# Get shake offset based on pattern
	var shake_vec = _calculate_shake(shake_amount)
	
	# Apply directional bias
	if directional_bias != Vector2.ZERO:
		var bias_length = directional_bias.length()
		if bias_length > 0.0:
			var bias_normalized = directional_bias.normalized()
			shake_vec.x *= lerp(1.0, abs(bias_normalized.x), bias_length)
			shake_vec.y *= lerp(1.0, abs(bias_normalized.y), bias_length)
	
	# Apply shake to camera in WORLD SPACE (not local)
	# If camera has a parent, we need to convert world shake to local space
	var shake_offset = Vector2(shake_vec.x, shake_vec.y)
	
	if camera.get_parent() != null:
		# Get parent's global rotation to convert world shake to local
		var parent_rotation = camera.get_parent().global_rotation
		shake_offset = shake_offset.rotated(-parent_rotation)
	
	camera.offset = _original_offset + shake_offset
	
	if rotation_enabled:
		camera.rotation = _original_rotation + shake_vec.z


## Internal: Calculate shake based on pattern
func _calculate_shake(amount: float) -> Vector3:
	match shake_pattern:
		ShakePattern.RANDOM:
			return _random_shake(amount)
		
		ShakePattern.PERLIN:
			return _perlin_shake(amount)
		
		ShakePattern.SINE_WAVE:
			return _sine_shake(amount)
		
		ShakePattern.BOUNCE:
			return _bounce_shake(amount)
		
		ShakePattern.CUSTOM:
			if custom_shake_func.is_valid():
				return custom_shake_func.call(_time, amount)
			return Vector3.ZERO
	
	return Vector3.ZERO


## Internal: Pure random shake
func _random_shake(amount: float) -> Vector3:
	return Vector3(
		randf_range(-max_offset, max_offset) * amount,
		randf_range(-max_offset, max_offset) * amount,
		randf_range(-max_rotation, max_rotation) * amount
	)


## Internal: Smooth Perlin-like noise shake
func _perlin_shake(amount: float) -> Vector3:
	# Use sine waves with different frequencies for smooth noise
	var t = _time * shake_frequency
	
	var x = sin(t * 1.1 + _noise_seed) * cos(t * 0.8)
	var y = sin(t * 0.9 + _noise_seed + 100) * cos(t * 1.2)
	var rot = sin(t * 1.3 + _noise_seed + 200) * cos(t * 0.7)
	
	return Vector3(
		x * max_offset * amount,
		y * max_offset * amount,
		rot * max_rotation * amount
	)


## Internal: Sine wave oscillation shake
func _sine_shake(amount: float) -> Vector3:
	var t = _time * shake_frequency
	
	return Vector3(
		sin(t) * max_offset * amount,
		cos(t * 1.1) * max_offset * amount,
		sin(t * 0.8) * max_rotation * amount
	)


## Internal: Bouncy decay shake
func _bounce_shake(amount: float) -> Vector3:
	var t = _time * shake_frequency
	var bounce = abs(sin(t)) * amount
	
	return Vector3(
		sin(t * 2.0) * max_offset * bounce,
		cos(t * 2.2) * max_offset * bounce,
		sin(t * 1.8) * max_rotation * bounce
	)


## Internal: Store original camera state
func _store_original_state() -> void:
	if camera:
		_original_offset = camera.offset
		_original_rotation = camera.rotation
		_has_original = true


## Internal: Reset camera to original state
func _reset_camera() -> void:
	if camera and _has_original:
		camera.offset = _original_offset
		camera.rotation = _original_rotation


## Stop shake immediately and reset camera.
func stop_shake() -> void:
	trauma = 0.0
	_reset_camera()
	shake_ended.emit()


## Set shake pattern.[br]
## [param pattern]: New ShakePattern.
func set_shake_pattern(pattern: ShakePattern) -> void:
	shake_pattern = pattern


## Enable/disable rotation shake.[br]
## [param enable]: Whether rotation is enabled.
func set_rotation_enabled(enable: bool) -> void:
	rotation_enabled = enable


## Set directional bias for shake (e.g. horizontal only).[br]
## [param bias]: Direction vector (1,0) = horizontal, (0,1) = vertical.
func set_directional_bias(bias: Vector2) -> void:
	directional_bias = bias


## Get current trauma level.[br]
## [return]: Trauma value (0.0 to 1.0).
func get_trauma() -> float:
	return trauma


## Check if currently shaking.[br]
## [return]: true if trauma > 0.
func is_shaking() -> bool:
	return trauma > 0.0


## Enable/disable component.[br]
## [param is_enabled]: Whether component is active.
func set_enabled(is_enabled: bool) -> void:
	if not is_enabled and enabled:
		stop_shake()
	enabled = is_enabled


## Reset time accumulator (for pattern restart).
func reset_time() -> void:
	_time = 0.0


## Get component statistics.[br]
## [return]: Dictionary with shake info.
func get_stats() -> Dictionary:
	return {
		"trauma": trauma,
		"shake_amount": pow(trauma, trauma_power),
		"is_shaking": is_shaking(),
		"pattern": ShakePattern.keys()[shake_pattern],
		"rotation_enabled": rotation_enabled,
		"enabled": enabled,
		"time": _time
	}


## Preset: Explosion shake (heavy with quick decay)
func shake_explosion(distance: float = 100.0, intensity: float = 1.0) -> void:
	# Closer explosions = more trauma
	var trauma_amount = clampf(intensity * (1.0 - distance / 500.0), 0.0, 1.0)
	add_trauma(trauma_amount)
	trauma_decay = 2.5  # Quick decay


## Preset: Impact shake (quick sharp shake)
func shake_impact(strength: float = 0.6) -> void:
	set_shake_pattern(ShakePattern.RANDOM)
	add_trauma(strength)
	trauma_decay = 3.0  # Very quick decay


## Preset: Rumble shake (continuous low shake)
func shake_rumble(intensity: float = 0.3) -> void:
	set_shake_pattern(ShakePattern.PERLIN)
	add_trauma(intensity, true)  # Override existing
	trauma_decay = 0.5  # Slow decay for sustained effect


## Preset: Camera bump (directional shake)
func shake_bump(direction: Vector2, strength: float = 0.5) -> void:
	set_directional_bias(direction.normalized())
	set_shake_pattern(ShakePattern.BOUNCE)
	add_trauma(strength)
	trauma_decay = 2.0
