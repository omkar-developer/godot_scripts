class_name FloatingTextComponent
extends RefCounted

## Spawns and manages floating text effects (damage numbers, heal amounts, status text).[br]
##[br]
## This component creates Label nodes that animate upward with customizable motion,[br>
## color, and duration. Useful for visual feedback like damage numbers, healing,[br]
## critical hits, and status messages. Can optionally use LabelSpawner for pooling.

## Animation style for floating text
enum AnimationStyle {
	FLOAT_UP,        ## Simple upward float
	FLOAT_UP_FADE,   ## Float up with fade out
	ARC_LEFT,        ## Arc to the left
	ARC_RIGHT,       ## Arc to the right
	BOUNCE,          ## Bounce upward
	SHAKE,           ## Shake in place then fade
	SCALE_POP        ## Pop/scale effect then fade
}

## Text alignment within the label
enum TextAlign {
	LEFT,
	CENTER,
	RIGHT
}

## Reference to the owner node (usually the entity taking damage/healing)
var owner: Node = null

## Parent node where floating labels are spawned (usually root or UI layer)
var spawn_parent: Node = null

## Optional label spawner for object pooling (if null, creates labels directly)
var label_spawner: LabelSpawner = null

## Default animation style
var animation_style: AnimationStyle = AnimationStyle.FLOAT_UP_FADE

## Base movement speed (pixels per second)
var float_speed: float = 50.0

## Duration of animation (seconds)
var duration: float = 1.0

## Default text color
var default_color: Color = Color.WHITE

## Font size for spawned labels (used if no spawner)
var font_size: int = 16

## Whether to use outline for text (used if no spawner)
var use_outline: bool = true

## Outline color (used if no spawner)
var outline_color: Color = Color.BLACK

## Outline size (used if no spawner)
var outline_size: int = 2

## Random horizontal spread (pixels)
var horizontal_spread: float = 20.0

## Random vertical offset (pixels)
var vertical_offset_range: float = 10.0

## Scale animation multiplier
var scale_multiplier: float = 1.5

## Whether to automatically cleanup finished labels
var auto_cleanup: bool = true

## Whether to recycle labels to spawner (only if spawner provided)
var recycle_to_pool: bool = true

## Gravity effect for ARC animations
var arc_gravity: float = 100.0

## List of active floating labels being animated
var _active_labels: Array[Dictionary] = []

## Emitted when a floating text finishes animating
signal text_finished(label: Label)

## Emitted when a floating text is spawned
signal text_spawned(label: Label, text: String)


func _init(_owner: Node, _spawn_parent: Node = null, _label_spawner: LabelSpawner = null) -> void:
	owner = _owner
	spawn_parent = _spawn_parent if _spawn_parent else _owner
	label_spawner = _label_spawner


## Spawn floating text at a specific position.[br]
## [param text]: The text to display.[br]
## [param position]: World position to spawn at.[br]
## [param color]: Text color.[br]
## [param style]: Animation style.[br]
## [return]: The created Label node.
func spawn_text_at_position(text: String, position: Vector2, color: Color = Color.WHITE, style: AnimationStyle = -1) -> Label:
	if not is_instance_valid(spawn_parent):
		push_warning("FloatingTextComponent: spawn_parent is invalid")
		return null
	
	var label = _create_label(text, color)
	if not label:
		return null
	
	label.global_position = position
	
	# Apply random offset
	label.position.x += randf_range(-horizontal_spread, horizontal_spread)
	label.position.y += randf_range(-vertical_offset_range, vertical_offset_range)
	
	# Only add to parent if not using spawner (spawner handles it)
	if not label_spawner and not label.is_inside_tree():
		spawn_parent.add_child(label)
	
	var anim_style = style if style >= 0 else animation_style
	_start_animation(label, anim_style)
	
	text_spawned.emit(label, text)
	return label


## Spawn floating text at owner's position.[br]
## [param text]: The text to display.[br]
## [param color]: Text color (uses default_color if not specified).[br]
## [param style]: Animation style override (uses default if null).[br]
## [return]: The created Label node.
func spawn_text(text: String, color: Color = Color.WHITE, style: AnimationStyle = -1) -> Label:
	if not is_instance_valid(spawn_parent):
		push_warning("FloatingTextComponent: spawn_parent is invalid")
		return null
	
	var label = _create_label(text, color)
	if not label:
		return null
	
	if owner is Node2D:
		label.global_position = (owner as Node2D).global_position
	else:
		label.position = Vector2.ZERO
	
	# Apply random offset
	label.position.x += randf_range(-horizontal_spread, horizontal_spread)
	label.position.y += randf_range(-vertical_offset_range, vertical_offset_range)
	
	# Only add to parent if not using spawner (spawner handles it)
	if not label_spawner and not label.is_inside_tree():
		spawn_parent.add_child(label)
	
	var anim_style = style if style >= 0 else animation_style
	_start_animation(label, anim_style)
	
	text_spawned.emit(label, text)
	return label


## Spawn damage number (red text).[br]
## [param damage]: Damage amount to display.[br]
## [param is_critical]: Whether this is a critical hit (larger, different color).[br]
## [return]: The created Label node.
func spawn_damage(damage: float, is_critical: bool = false) -> Label:
	var text = str(int(damage))
	var color = Color.RED if not is_critical else Color.ORANGE
	var label = spawn_text(text, color)
	
	if is_critical and label:
		label.scale = Vector2.ONE * scale_multiplier
		label.modulate = Color.YELLOW
	
	return label


## Spawn heal number (green text).[br]
## [param heal_amount]: Healing amount to display.[br]
## [return]: The created Label node.
func spawn_heal(heal_amount: float) -> Label:
	var text = "+" + str(int(heal_amount))
	return spawn_text(text, Color.GREEN)


## Spawn status text (custom message).[br]
## [param message]: Message to display (e.g. "BLOCKED", "IMMUNE", "MISS").[br]
## [param color]: Text color.[br]
## [return]: The created Label node.
func spawn_status(message: String, color: Color = Color.YELLOW) -> Label:
	return spawn_text(message, color, AnimationStyle.SCALE_POP)


## Update all active floating labels (call in _process).[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	var i = _active_labels.size() - 1
	while i >= 0:
		var data = _active_labels[i]
		var label = data.label as Label
		
		if not is_instance_valid(label):
			_active_labels.remove_at(i)
			i -= 1
			continue
		
		data.elapsed += delta
		var progress = data.elapsed / duration
		
		if progress >= 1.0:
			_finish_label(label, i)
			i -= 1
			continue
		
		_update_animation(label, data, progress, delta)
		i -= 1


## Set label spawner for object pooling.[br]
## [param spawner]: LabelSpawner instance (or null to disable pooling).
func set_label_spawner(spawner: LabelSpawner) -> void:
	label_spawner = spawner


## Get the label spawner being used.[br]
## [return]: LabelSpawner instance or null.
func get_label_spawner() -> LabelSpawner:
	return label_spawner


## Internal: Create label node with styling
func _create_label(text: String, color: Color) -> Label:
	var label: Label = null
	
	# Use spawner if available
	if label_spawner:
		label = label_spawner.create_label(text, color, font_size)
	else:
		# Create manually
		label = Label.new()
		label.text = text
		label.modulate = color
		
		# Set font size
		label.add_theme_font_size_override("font_size", font_size)
		
		# Add outline
		if use_outline:
			label.add_theme_color_override("font_outline_color", outline_color)
			label.add_theme_constant_override("outline_size", outline_size)
		
		# Center pivot
		label.pivot_offset = label.size / 2.0
	
	return label


## Internal: Start animation for label
func _start_animation(label: Label, style: AnimationStyle) -> void:
	var data = {
		"label": label,
		"style": style,
		"elapsed": 0.0,
		"start_pos": label.position,
		"velocity": Vector2(0, -float_speed),
		"start_scale": label.scale
	}
	
	# Set initial velocity based on style
	match style:
		AnimationStyle.ARC_LEFT:
			data.velocity = Vector2(-float_speed * 0.7, -float_speed)
		AnimationStyle.ARC_RIGHT:
			data.velocity = Vector2(float_speed * 0.7, -float_speed)
		AnimationStyle.BOUNCE:
			data.velocity = Vector2(0, -float_speed * 1.5)
	
	_active_labels.append(data)


## Internal: Update animation frame
func _update_animation(label: Label, data: Dictionary, progress: float, delta: float) -> void:
	var style = data.style as AnimationStyle
	
	match style:
		AnimationStyle.FLOAT_UP:
			label.position.y -= float_speed * delta
		
		AnimationStyle.FLOAT_UP_FADE:
			label.position.y -= float_speed * delta
			label.modulate.a = 1.0 - progress
		
		AnimationStyle.ARC_LEFT, AnimationStyle.ARC_RIGHT:
			data.velocity.y += arc_gravity * delta
			label.position += data.velocity * delta
			label.modulate.a = 1.0 - progress
		
		AnimationStyle.BOUNCE:
			data.velocity.y += arc_gravity * delta
			label.position += data.velocity * delta
			label.modulate.a = 1.0 - progress
			
			# Bounce when hitting "ground"
			if label.position.y > data.start_pos.y:
				label.position.y = data.start_pos.y
				data.velocity.y *= -0.5
		
		AnimationStyle.SHAKE:
			var shake_amount = 5.0 * (1.0 - progress)
			label.position = data.start_pos + Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
			label.modulate.a = 1.0 - progress
		
		AnimationStyle.SCALE_POP:
			var scale_curve = sin(progress * PI)  # 0 -> 1 -> 0
			var scale_factor = 1.0 + (scale_multiplier - 1.0) * scale_curve
			label.scale = data.start_scale * scale_factor
			label.position.y -= float_speed * 0.5 * delta
			label.modulate.a = 1.0 - progress


## Internal: Finish and cleanup label
func _finish_label(label: Label, index: int) -> void:
	text_finished.emit(label)
	_active_labels.remove_at(index)
	
	if not is_instance_valid(label):
		return
	
	# Recycle to pool if available
	if label_spawner and recycle_to_pool:
		label_spawner.recycle_label(label)
	# Otherwise cleanup normally
	elif auto_cleanup:
		label.queue_free()


## Set default animation style.[br]
## [param style]: New default AnimationStyle.
func set_animation_style(style: AnimationStyle) -> void:
	animation_style = style


## Set spawn parent node.[br]
## [param parent]: Node where labels will be spawned.
func set_spawn_parent(parent: Node) -> void:
	spawn_parent = parent


## Clear all active floating labels immediately.[br]
## [param cleanup]: Whether to free the label nodes.
func clear_all(cleanup: bool = true) -> void:
	for data in _active_labels:
		var label = data.label as Label
		if not is_instance_valid(label):
			continue
		
		# Recycle or cleanup
		if label_spawner and recycle_to_pool:
			label_spawner.recycle_label(label)
		elif cleanup:
			label.queue_free()
	
	_active_labels.clear()


## Get count of active floating labels.[br]
## [return]: Number of currently animating labels.
func get_active_count() -> int:
	return _active_labels.size()


## Configure label styling (used when not using spawner).[br]
## [param _font_size]: Font size for labels.[br]
## [param _use_outline]: Whether to add outline.[br]
## [param _outline_color]: Outline color.[br]
## [param _outline_size]: Outline thickness.
func configure_style(
	_font_size: int = 16,
	_use_outline: bool = true,
	_outline_color: Color = Color.BLACK,
	_outline_size: int = 2
) -> void:
	font_size = _font_size
	use_outline = _use_outline
	outline_color = _outline_color
	outline_size = _outline_size
