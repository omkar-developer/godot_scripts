extends Node
class_name BuffManager

## Signal emitted when a modifier is applied
signal modifier_applied(modifier_name: String, modifier: StatModifierSet)
## Signal emitted when a modifier is removed
signal modifier_removed(modifier_name: String, modifier: StatModifierSet)

## Dictionary of active modifiers
@export_storage var _active_modifiers: Dictionary = {}
## Parent entity reference
var _parent: Object
## Array of attached modules
@export_storage var _modules: Array[BMModule] = []

func _enter_tree() -> void:
	if _parent == null:
		_parent = get_parent()

## Add a module to the manager
func add_module(module: BMModule) -> void:
	if not _modules.has(module):
		_modules.append(module)
		module.init(self)

## Remove a module from the manager
func remove_module(module: BMModule) -> void:
	if _modules.has(module):
		module.uninit()
		_modules.erase(module)

## Apply a modifier
## Returns true if successfully applied
func apply_modifier(_modifier: StatModifierSet, copy: bool = true) -> bool:
	var modifier = _modifier.copy() if copy else _modifier
	# Let modules handle pre-application
	for module in _modules:
		if not module.on_before_apply(modifier):
			return false
	
	var modifier_name = modifier.get_modifier_name()
	
	# Initialize and store modifier    
	if has_modifier(modifier_name):
		_active_modifiers[modifier_name].merge_mod(modifier)
	else:
		modifier.init_modifiers(_parent)
		_active_modifiers[modifier_name] = modifier
	
	# Let modules handle post-application
	for module in _modules:
		module.on_after_apply(modifier)
	
	modifier_applied.emit(modifier_name, modifier)
	return true

## Remove a specific modifier
func remove_modifier(modifier_name: String) -> void:
	if not has_modifier(modifier_name):
		return
	
	var modifier = _active_modifiers[modifier_name]
	
	# Let modules handle pre-removal
	for module in _modules:
		module.on_before_remove(modifier)
	
	modifier.delete()
	_active_modifiers.erase(modifier_name)
	
	# Let modules handle post-removal
	for module in _modules:
		module.on_after_remove(modifier)
	
	modifier_removed.emit(modifier_name, modifier)

## Remove all modifiers in a specific group
func remove_group_modifiers(group: String) -> void:
	var to_remove = []
	for modifier_name in _active_modifiers:
		if _active_modifiers[modifier_name]._group == group:
			to_remove.append(modifier_name)
	
	for modifier_name in to_remove:
		remove_modifier(modifier_name)

## Get all active modifiers in a specific group
func get_group_modifiers(group: String) -> Array[StatModifierSet]:
	var modifiers: Array[StatModifierSet] = []
	for modifier in _active_modifiers.values():
		if modifier._group == group:
			modifiers.append(modifier)
	return modifiers

## Check if a group has any active modifiers
func has_group_modifiers(group: String) -> bool:
	for modifier in _active_modifiers.values():
		if modifier._group == group:
			return true
	return false

## Clear all modifiers
func clear_all_modifiers() -> void:
	var names = _active_modifiers.keys()
	for modifier_name in names:
		remove_modifier(modifier_name)

## Get active modifier by name
func get_modifier(modifier_name: String) -> StatModifierSet:
	return _active_modifiers.get(modifier_name)

## Check if a modifier is currently active
func has_modifier(modifier_name: String) -> bool:
	return _active_modifiers.has(modifier_name)

## Process method for updating modifiers
func _process(delta: float) -> void:
	var to_remove: Array = []
	
	# Update modifiers
	for modifier_name in _active_modifiers:
		var modifier = _active_modifiers[modifier_name]
		if modifier.is_marked_for_deletion():
			to_remove.append(modifier_name)
			continue
		elif modifier.process:
			modifier._process(delta)
			if modifier.is_marked_for_deletion():
				to_remove.append(modifier_name)
	
	# Update modules
	for module in _modules:
		module.process(delta)
	
	# Remove finished modifiers
	for modifier_name in to_remove:
		remove_modifier(modifier_name)
