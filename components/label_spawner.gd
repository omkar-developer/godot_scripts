class_name LabelSpawner
extends RefCounted

## Object pool for Label nodes to reduce allocation overhead.[br]
##[br]
## This class manages a pool of reusable Label nodes to avoid constantly creating[br]
## and destroying labels (which causes GC pressure). Labels are recycled when returned[br]
## to the pool. Significant performance improvement when spawning many floating texts.

## Parent node where labels are spawned
var spawn_parent: Node = null

## Pool of inactive labels ready to be reused
var _inactive_pool: Array[Label] = []

## Set of currently active labels
var _active_labels: Array[Label] = []

## Initial pool size (pre-allocated labels)
var initial_pool_size: int = 20

## Maximum pool size (0 = unlimited)
var max_pool_size: int = 100

## Whether to auto-expand pool when depleted
var auto_expand: bool = true

## Whether to automatically add labels to spawn_parent
var auto_add_to_parent: bool = true

## Default font size for created labels
var default_font_size: int = 16

## Whether to use outline by default
var default_use_outline: bool = true

## Default outline color
var default_outline_color: Color = Color.BLACK

## Default outline size
var default_outline_size: int = 2

## Statistics
var total_spawned: int = 0
var total_recycled: int = 0
var peak_active: int = 0

## Emitted when pool is expanded
signal pool_expanded(new_size: int)

## Emitted when a label is spawned from pool
signal label_spawned(label: Label)

## Emitted when a label is returned to pool
signal label_recycled(label: Label)


func _init(_spawn_parent: Node = null, _initial_pool_size: int = 20) -> void:
	spawn_parent = _spawn_parent
	initial_pool_size = _initial_pool_size
	
	if initial_pool_size > 0:
		_preallocate_pool(initial_pool_size)


## Pre-allocate labels in the pool.[br]
## [param count]: Number of labels to create.
func _preallocate_pool(count: int) -> void:
	for i in range(count):
		var label = _create_new_label()
		label.visible = false
		_inactive_pool.append(label)


## Get a label from the pool (or create new if pool empty).[br>
## [return]: A Label node ready to use.
func get_label() -> Label:
	var label: Label = null
	
	# Try to reuse from pool
	if not _inactive_pool.is_empty():
		label = _inactive_pool.pop_back()
		_reset_label(label)
	# Create new if pool empty and auto_expand enabled
	elif auto_expand:
		label = _create_new_label()
		pool_expanded.emit(_inactive_pool.size() + _active_labels.size() + 1)
	else:
		push_warning("LabelSpawner: Pool depleted and auto_expand is disabled")
		return null
	
	# Add to parent if needed
	if auto_add_to_parent and spawn_parent and not label.is_inside_tree():
		spawn_parent.add_child(label)
	
	label.visible = true
	_active_labels.append(label)
	
	# Update stats
	total_spawned += 1
	peak_active = maxi(peak_active, _active_labels.size())
	
	label_spawned.emit(label)
	return label


## Return a label to the pool for reuse.[br]
## [param label]: The Label to recycle.
func recycle_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	
	# Remove from active list
	var idx = _active_labels.find(label)
	if idx >= 0:
		_active_labels.remove_at(idx)
	
	# Check pool size limit
	if max_pool_size > 0 and _inactive_pool.size() >= max_pool_size:
		# Pool is full, destroy the label
		if label.is_inside_tree():
			label.get_parent().remove_child(label)
		label.queue_free()
		return
	
	# Reset and return to pool
	_reset_label(label)
	label.visible = false
	
	# Remove from tree but keep alive
	if label.is_inside_tree():
		label.get_parent().remove_child(label)
	
	_inactive_pool.append(label)
	total_recycled += 1
	
	label_recycled.emit(label)


## Create a styled label with default settings.[br]
## [param text]: Initial text for the label.[br]
## [param color]: Text color.[br]
## [param font_size]: Font size override (uses default if -1).[br]
## [return]: Configured Label node.
func create_label(text: String, color: Color = Color.WHITE, font_size: int = -1) -> Label:
	var label = get_label()
	if not label:
		return null
	
	label.text = text
	label.modulate = color
	
	var size = font_size if font_size > 0 else default_font_size
	label.add_theme_font_size_override("font_size", size)
	
	if default_use_outline:
		label.add_theme_color_override("font_outline_color", default_outline_color)
		label.add_theme_constant_override("outline_size", default_outline_size)
	
	# Center pivot
	label.pivot_offset = label.size / 2.0
	
	return label


## Internal: Create a new label node
func _create_new_label() -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", default_font_size)
	
	if default_use_outline:
		label.add_theme_color_override("font_outline_color", default_outline_color)
		label.add_theme_constant_override("outline_size", default_outline_size)
	
	return label


## Internal: Reset label to default state
func _reset_label(label: Label) -> void:
	label.text = ""
	label.position = Vector2.ZERO
	label.rotation = 0.0
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	label.pivot_offset = Vector2.ZERO
	label.visible = true


## Get number of labels in inactive pool.[br]
## [return]: Count of available labels.
func get_pool_size() -> int:
	return _inactive_pool.size()


## Get number of currently active labels.[br]
## [return]: Count of active labels.
func get_active_count() -> int:
	return _active_labels.size()


## Get total capacity (active + inactive).[br]
## [return]: Total label count.
func get_total_capacity() -> int:
	return _inactive_pool.size() + _active_labels.size()


## Check if all active labels are valid (cleanup check).[br]
## [return]: Number of invalid labels cleaned up.
func cleanup_invalid() -> int:
	var cleaned = 0
	var i = _active_labels.size() - 1
	
	while i >= 0:
		var label = _active_labels[i]
		if not is_instance_valid(label):
			_active_labels.remove_at(i)
			cleaned += 1
		i -= 1
	
	return cleaned


## Manually expand the pool.[br]
## [param count]: Number of labels to add to pool.
func expand_pool(count: int) -> void:
	var start_size = get_total_capacity()
	_preallocate_pool(count)
	pool_expanded.emit(get_total_capacity())


## Set spawn parent node.[br]
## [param parent]: Node where labels will be added.
func set_spawn_parent(parent: Node) -> void:
	spawn_parent = parent


## Clear and destroy all labels (active and inactive).[br]
## [param destroy_active]: Whether to also destroy active labels.
func clear_all(destroy_active: bool = false) -> void:
	# Clear inactive pool
	for label in _inactive_pool:
		if is_instance_valid(label):
			if label.is_inside_tree():
				label.queue_free()
			else:
				label.free()
	_inactive_pool.clear()
	
	# Clear active if requested
	if destroy_active:
		for label in _active_labels:
			if is_instance_valid(label) and label.is_inside_tree():
				label.queue_free()
		_active_labels.clear()


## Get statistics dictionary.[br]
## [return]: Dictionary with pool stats.
func get_stats() -> Dictionary:
	return {
		"inactive_pool_size": _inactive_pool.size(),
		"active_count": _active_labels.size(),
		"total_capacity": get_total_capacity(),
		"total_spawned": total_spawned,
		"total_recycled": total_recycled,
		"peak_active": peak_active,
		"recycle_rate": (float(total_recycled) / float(total_spawned)) if total_spawned > 0 else 0.0
	}


## Reset statistics counters.
func reset_stats() -> void:
	total_spawned = 0
	total_recycled = 0
	peak_active = 0


## Configure default styling for spawned labels.[br]
## [param font_size]: Default font size.[br]
## [param use_outline]: Whether to use outline.[br]
## [param outline_color]: Outline color.[br]
## [param outline_size]: Outline thickness.
func configure_defaults(
	font_size: int = 16,
	use_outline: bool = true,
	outline_color: Color = Color.BLACK,
	outline_size: int = 2
) -> void:
	default_font_size = font_size
	default_use_outline = use_outline
	default_outline_color = outline_color
	default_outline_size = outline_size
