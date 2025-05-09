extends Node
class_name BuffManager
#TODO: merge with add extra

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

# Add these at the top of the file with other class variables
## Dictionary mapping class names to modifier set types
static var modifier_set_types: Dictionary = {
	"StatModifierSet": StatModifierSet,
	"StatModifierSetTimed": StatModifierSetTimed
}

## Dictionary mapping class names to module types
static var module_types: Dictionary = {
	"BMModule": BMModule,
	"BMMCategory": BMMCategory,
	"BMMResistance": BMMResistance,
	"BMM_Stacking": BMM_Stacking,
	# Add any other module types you have here
}

## Returns a dictionary representation of the buff manager's state
func to_dict(modules: bool = false) -> Dictionary:
	return {
		"active_modifiers": _active_modifiers.keys().map(
		func(key): 
		var modifier = _active_modifiers[key]
		return {
			"key": key,
			"class_name": modifier.get_class_name(),
			"data": modifier.to_dict()
		}
		),
		"modules": _modules.map(
		func(module): 
		return {
			"class_name": module.get_class_name(),
			"data": module.to_dict()
		} if modules else {}
		)
	}

## Loads the buff manager state from a dictionary
func from_dict(data: Dictionary, modules: bool = false) -> void:
	if data == null: return
	
	# Clear existing state
	clear_all_modifiers()
	_modules.clear()
	
	# Load modifiers
	for mod_data in data.get("active_modifiers", []):
		var modifier = _instantiate_modifier_set(mod_data.get("class_name", ""))
		modifier.from_dict(mod_data["data"])
		apply_modifier(modifier, false)  # false to not copy since we just created it
	
	# Load modules
	if not modules or data.get("modules", []).is_empty(): return
	for module_data in data.get("modules", []):
		var module = _instantiate_module(module_data.get("class_name", ""))
		if module:
			module.from_dict(module_data["data"])
			add_module(module)

## Instantiates a modifier set of the given type
func _instantiate_modifier_set(modifier_type: String) -> StatModifierSet:
	if modifier_type in modifier_set_types:
		return modifier_set_types[modifier_type].new()
	else:
		push_warning("Unknown modifier set type: %s, defaulting to StatModifierSet." % modifier_type)
		return StatModifierSet.new()

## Instantiates a module of the given type
func _instantiate_module(module_type: String) -> BMModule:
	if module_type in module_types:
		return module_types[module_type].new()
	else:
		push_warning("Unknown module type: %s, skipping." % module_type)
		return null

## Returns the class name of the buff manager
func get_class_name() -> String:
	return "BuffManager"
