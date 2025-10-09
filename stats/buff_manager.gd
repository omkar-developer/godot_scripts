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
	if _modifier == null or _modifier.is_marked_for_deletion():
		push_warning("Cannot apply null or deleted modifier")
		return false
	
	var modifier = _modifier.copy() if copy else _modifier
	
	# Let modules handle pre-application
	for module in _modules:
		if not module.on_before_apply(modifier):
			return false
	
	var modifier_name = modifier.get_modifier_name()
	
	# Handle different stack modes
	match modifier.stack_mode:
		StatModifierSet.StackMode.INDEPENDENT:
			if not _active_modifiers.has(modifier_name):
				_active_modifiers[modifier_name] = []
			
			var instances: Array = _active_modifiers[modifier_name]
			
			# Per-source limit
			if modifier.stack_source_id != "" and modifier.max_stacks > 0:
				var source_count = 0
				for inst in instances:
					if inst.stack_source_id == modifier.stack_source_id:
						source_count += 1
				if source_count >= modifier.max_stacks:
					return false
			
			modifier.init_modifiers(_parent)
			instances.append(modifier)
		
		_:  # All other modes
			if has_modifier(modifier_name):
				if not _active_modifiers[modifier_name].merge_mod(modifier):
					return false
			else:
				modifier.init_modifiers(_parent)
				_active_modifiers[modifier_name] = modifier
	
	for module in _modules:
		module.on_after_apply(modifier)
	
	modifier_applied.emit(modifier_name, modifier)
	return true

## Remove a specific modifier
func remove_modifier(modifier_name: String, source_id: String = "") -> void:
	if not has_modifier(modifier_name):
		return
	
	var value = _active_modifiers[modifier_name]
	
	if value is Array:
		var instances: Array = value
		var to_remove_indices = []
		
		for i in range(instances.size()):
			var inst = instances[i]
			if source_id == "" or inst.stack_source_id == source_id:
				for module in _modules:
					module.on_before_remove(inst)
				
				to_remove_indices.append(i)
		
		# Remove in reverse order
		to_remove_indices.reverse()
		for i in to_remove_indices:
			var inst = instances[i]
			inst.uninit_modifiers()
			instances.remove_at(i)
			
			for module in _modules:
				module.on_after_remove(inst)
			
			modifier_removed.emit(modifier_name, inst)
		
		if instances.is_empty():
			_active_modifiers.erase(modifier_name)
	else:
		var modifier = value
		for module in _modules:
			module.on_before_remove(modifier)
		
		modifier.uninit_modifiers()
		_active_modifiers.erase(modifier_name)
		
		for module in _modules:
			module.on_after_remove(modifier)
		
		modifier_removed.emit(modifier_name, modifier)

## Remove all modifiers in a specific group
func remove_group_modifiers(group: String) -> void:
	var to_remove = []
	for modifier_name in _active_modifiers:
		var value = _active_modifiers[modifier_name]
		if value is Array:
			for inst in value:
				if inst._group == group:
					to_remove.append(modifier_name)
					break
		elif value._group == group:
			to_remove.append(modifier_name)
	
	for modifier_name in to_remove:
		remove_modifier(modifier_name)

## Get all active modifiers in a specific group
func get_group_modifiers(group: String) -> Array[StatModifierSet]:
	var modifiers: Array[StatModifierSet] = []
	for value in _active_modifiers.values():
		if value is Array:
			for inst in value:
				if inst._group == group:
					modifiers.append(inst)
		elif value._group == group:
			modifiers.append(value)
	return modifiers

## Check if a group has any active modifiers
func has_group_modifiers(group: String) -> bool:
	for value in _active_modifiers.values():
		if value is Array:
			for inst in value:
				if inst._group == group:
					return true
		elif value._group == group:
			return true
	return false

## Clear all modifiers
func clear_all_modifiers() -> void:
	var names = _active_modifiers.keys()
	for modifier_name in names:
		remove_modifier(modifier_name)

## Get active modifier by name
func get_modifier(modifier_name: String) -> StatModifierSet:
	var value = _active_modifiers.get(modifier_name)
	if value is Array:
		return value[0] if value.size() > 0 else null
	return value

## Check if a modifier is currently active
func has_modifier(modifier_name: String) -> bool:
	return _active_modifiers.has(modifier_name)

## Get the effective stack count for a modifier
func get_effective_stack_count(modifier_name: String) -> int:
	var value = _active_modifiers.get(modifier_name)
	if value is Array:
		return value.size()
	elif value != null and value.has("stack_count"):
		return value.stack_count
	return 1

## Get the current stack count for a modifier (for COUNT_STACKS mode)
func get_stack_count(modifier_name: String) -> int:
	if not has_modifier(modifier_name):
		return 0
	
	var value = _active_modifiers.get(modifier_name)
	
	# If it's COUNT_STACKS mode
	if value is StatModifierSet and value.stack_mode == StatModifierSet.StackMode.COUNT_STACKS:
		return value.stack_count
	
	# INDEPENDENT mode uses instances instead of a numeric stack count
	if value is Array:
		return value.size()
	
	# Default (MERGE_VALUES, etc.)
	return 1

## Get the current instance count for a modifier
func get_instances_count(modifier_name: String) -> int:
	if not has_modifier(modifier_name):
		return 0
	
	var value = _active_modifiers.get(modifier_name)
	if value is Array:
		return value.size()

	return 1

## Get all instances of a modifier (useful for INDEPENDENT mode)
func get_modifier_instances(modifier_name: String) -> Array[StatModifierSet]:
	var result: Array[StatModifierSet] = []
	var value = _active_modifiers.get(modifier_name)
	
	if value is Array:
		for inst in value:
			result.append(inst)
	elif value != null:
		result.append(value)
	
	return result

## Check if we can apply more stacks of a modifier
func can_apply_more_stacks(modifier_name: String, source_id: String = "") -> bool:
	if not has_modifier(modifier_name):
		return true
	
	var value = _active_modifiers.get(modifier_name)
	
	if value is Array:
		# INDEPENDENT mode - check source limits
		var first_inst = value[0] if value.size() > 0 else null
		if first_inst == null:
			return true
		
		if source_id != "" and first_inst.max_stacks > 0:
			var source_count = 0
			for inst in value:
				if inst.stack_source_id == source_id:
					source_count += 1
			return source_count < first_inst.max_stacks
		return true
	else:
		# COUNT_STACKS or other modes
		if value.max_stacks > 0:
			return value.stack_count < value.max_stacks
		return true

## Remove a single stack from COUNT_STACKS modifier
func remove_stack(modifier_name: String, count: int = 1) -> bool:
	if not has_modifier(modifier_name):
		return false
	
	var value = _active_modifiers.get(modifier_name)
	if value is Array or value.stack_mode != StatModifierSet.StackMode.COUNT_STACKS:
		push_warning("remove_stack only works with COUNT_STACKS mode")
		return false
	
	value.stack_count = max(0, value.stack_count - count)
	if value.stack_count <= 0:
		remove_modifier(modifier_name)
		return true
	
	value._apply_effect()  # Reapply with reduced stacks
	return true

## Get total number of active modifier instances (across all names)
func get_total_modifier_count() -> int:
	var count = 0
	for value in _active_modifiers.values():
		if value is Array:
			count += value.size()
		else:
			count += 1
	return count

## Process method for updating modifiers
func _process(delta: float) -> void:
	# WARNING: Race condition possible if modules modify _active_modifiers during processing.
	# If a module's process() or callbacks call apply_modifier() or remove_modifier(),
	# this can modify the dictionary while we're iterating over it.
	# Symptoms: Skipped modifiers, unexpected behavior, or crashes in rare cases.
	# 
	# Safe patterns:
	# - Modules should queue changes and apply them after _process()
	# - Or snapshot the keys before iteration (see fix below if needed)
	#
	# To fix: Use var modifier_names = _active_modifiers.keys() and iterate that instead
	
	var modifier_names = _active_modifiers.keys()
	var to_remove: Array = []
	
	for modifier_name in modifier_names:
		if not _active_modifiers.has(modifier_name):
			continue
		
		var value = _active_modifiers[modifier_name]
		
		if value is Array:
			var instances: Array = value
			for i in range(instances.size() - 1, -1, -1):
				var inst = instances[i]
				if inst.is_marked_for_deletion():
					to_remove.append({"name": modifier_name, "index": i})
				elif inst.process:
					inst._process(delta)
					if inst.is_marked_for_deletion():
						to_remove.append({"name": modifier_name, "index": i})
		else:
			var modifier = value
			if modifier.is_marked_for_deletion():
				to_remove.append({"name": modifier_name})
			elif modifier.process:
				modifier._process(delta)
				if modifier.is_marked_for_deletion():
					to_remove.append({"name": modifier_name})
	
	for module in _modules:
		module.process(delta)
	
	for item in to_remove:
		var mod_name = item.get("name")
		if item.has("index"):
			var instances = _active_modifiers[mod_name]
			var inst = instances[item["index"]]
			inst.uninit_modifiers()
			instances.remove_at(item["index"])
			modifier_removed.emit(mod_name, inst)
			if instances.is_empty():
				_active_modifiers.erase(mod_name)
		else:
			remove_modifier(mod_name)

## Returns a dictionary representation of the buff manager's state
func to_dict(modules: bool = false) -> Dictionary:
	var modifiers_data = []
	
	for key in _active_modifiers.keys():
		var value = _active_modifiers[key]
		
		if value is Array:
			# Handle array of modifiers (INDEPENDENT stack mode)
			for inst in value:
				modifiers_data.append({
					"key": key,
					"class_type": inst.get_script().get_global_name(),
					"data": inst.to_dict()
				})
		else:
			# Handle single modifier
			modifiers_data.append({
				"key": key,
				"class_type": value.get_script().get_global_name(),
				"data": value.to_dict()
			})
	
	return {
		"active_modifiers": modifiers_data,
		"modules": _modules.map(
		func(module): 
		return {
			"class_type": module.get_script().get_global_name(),
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
	
	# Load modules FIRST so they can intercept modifier loading
	if modules and not data.get("modules", []).is_empty():
		for module_data in data.get("modules", []):
			var module = _instantiate_class(module_data.get("class_type", ""))
			if module:
				module.from_dict(module_data["data"])
				add_module(module)
	
	for mod_data in data.get("active_modifiers", []):
		var modifier = _instantiate_class(mod_data.get("class_type", ""))
		if modifier:
			modifier.from_dict(mod_data["data"])
			apply_modifier(modifier, false)

func _instantiate_class(class_type: String) -> Object:
	var global_classes = ProjectSettings.get_global_class_list()
	
	# Find the class in the global class list
	for gc in global_classes:
		if gc["class"] == class_type:
			# Load the script and instantiate it
			var script = load(gc["path"])
			if script:
				return script.new()
	
	# Fallback for built-in classes or if not found in global class list
	if class_type == "StatModifier":
		return StatModifier.new()
	elif class_type == "Condition":
		return Condition.new()
	elif class_type == "StatModifierSet":
		return StatModifierSet.new()
	else:
		push_warning("Unknown class type: %s, defaulting to null." % class_type)
		return null
