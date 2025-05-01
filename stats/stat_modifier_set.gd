extends Resource

## A class that represents a set of stat _modifiers and provides methods to manage and apply them.
class_name StatModifierSet

signal on_effect_apply # Signal emitted when an effect is applied to a stat.
signal on_effect_remove # Signal emitted when an effect is removed from a stat. 

## Array of _modifiers in this set.
@export var _modifiers: Array[StatModifier] = []

## The name of this modifier set.
@export var _modifier_name: String = ""

## The group to which this modifier set belongs.
@export var _group := ""

## Whether to merge modifiers with the same name.
@export var merge_enabled := true

## Whether to process this modifier set every frame.
@export var process := false

## The condition associated with this modifier set.
@export var condition: Condition

@export var apply_on_condition_change := true
@export var remove_on_condition_change := true

@export_storage var _marked_for_deletion := false

## The _parent object associated with this modifier set.
var _parent: Object

## apply as soon as initialized or added to the list
@export var _apply := true
## remove effect when uninit
@export var _remove_all := true
## apply effect when condition is true when initializing 
@export var _condition_apply_on_start := true
## pause process when condition is false and vice versa
@export var _condition_pause_process := false

static var modifier_types = {
	"StatModifierComposite": StatModifierComposite,
	"StatModifier": StatModifier,
}

static var condition_types = {
	"Condition": Condition,
}

## Return the modifer name
func get_modifier_name() -> String:
	return _modifier_name

func _init(modifier_name := "", _process_every_frame := false, group := "") -> void:
	_modifier_name = modifier_name
	_group = group
	process = _process_every_frame

## Called when the condition state changes
func _on_condition_changed(result: bool) -> void:
	if result:
		if apply_on_condition_change: _apply_effect()
		if _condition_pause_process: process = true
	else:
		if remove_on_condition_change: _remove_effect()
		if _condition_pause_process: process = false

## Connects condition signals and handles initial state
func _connect_condition() -> void:
	if condition != null and not condition.condition_changed.is_connected(_on_condition_changed):
		condition.condition_changed.connect(_on_condition_changed)

## Disconnects condition signals
func _disconnect_condition() -> void:
	if condition != null and condition.condition_changed.is_connected(_on_condition_changed):
		condition.condition_changed.disconnect(_on_condition_changed)

## Merges a parallel StatModifierSet into this one.[br]
## [param modifer_set]: The StatModifierSet to merge.
func _merge_parellel(modifer_set: StatModifierSet) -> void:
	if modifiers_count() != modifer_set.modifiers_count(): return
	for i in range(modifer_set.modifiers_count() - 1, -1, -1):
		if modifer_set._modifiers[i].is_equal(_modifiers[i]):
			_modifiers[i].merge(modifer_set._modifiers[i])

## Merges a StatModifierSet into this one.[br]
## [param mod]: The StatModifierSet to merge.
func merge_mod(mod: StatModifierSet) -> void:
	if not merge_enabled: return
	_merge_parellel(mod)

## Sets the value of a modifier at a given index.[br]
## [param mod_idx]: The index of the modifier to set the value of.[br]
## [param value]: The value to set.
## [return]: True if the value was set, False otherwise.
func set_mod_value(mod_idx: int, value: float) -> bool:
	if _modifiers.size() > mod_idx:
		_modifiers[mod_idx].set_value(value)
		return true
	else:
		push_error("Invalid modifier index: " + str(mod_idx))
		return false

## Finds a modifier in this set that matches the given modifier.[br]
## [param mod]: The modifier to find.[br]
## [return]: The modifier that matches the given modifier, or null if no such modifier is found.
func find_mod(mod: StatModifier) -> StatModifier:
	for mod2 in _modifiers:
		if mod.is_equal(mod2):
			return mod2
	return null

## Finds a modifier that targets a given stat and has a given type.[br]
## [param stat_name]: The name of the stat to target.[br]
## [param type]: The type of the modifier to find.[br]
## [return]: The modifier that targets the given stat and has the given type, or null if no such modifier is found.
func find_mod_by_name_and_type(stat_name: String, type: StatModifier.StatModifierType) -> StatModifier:
	for mod in _modifiers:
		if mod.get_stat_name() == stat_name and mod.get_type() == type:
			return mod
	return null

## Finds a modifier that targets a given stat.[br]
## [param stat_name]: The name of the stat to target.[br]
## [return]: The modifier that targets the given stat, or null if no such modifier is found.
func find_mod_for_stat(stat_name: String) -> StatModifier:
	for mod in _modifiers:
		if mod.get_stat_name() == stat_name:
			return mod
	return null

## Applies all _modifiers in this set to the _parent.
func _apply_effect() -> void:
	for mod in _modifiers:
		mod.apply()
	on_effect_apply.emit()

## Removes all _modifiers in this set from the _parent.
func _remove_effect() -> void:
	for mod in _modifiers:
		mod.remove()
	on_effect_remove.emit()

## Initializes all _modifiers in this set with the given _parent.[br]
## [param _parent]: The _parent to initialize the _modifiers with.
func init_modifiers(parent: Object) -> void:
	if _parent != null: 
		push_error("Attempted to set new parent while already initialized without uninitializing first.")
		return
	if parent == null: return
	if not parent.has_method("get_stat"): return
	_parent = parent
	for mod in _modifiers:
		mod.init_stat(parent)
	# Initialize condition first
	if condition != null:
		condition.init_stat(parent)
		_connect_condition()
		if _condition_apply_on_start:
			_apply_effect()
			if _condition_pause_process: process = condition.get_condition()
	# Apply effects
	if _apply and condition == null:
		_apply_effect()

## Uninitializes all _modifiers in this set.
func uninit_modifiers() -> void:
	if condition != null:
		_disconnect_condition()
		condition.uninit_stat()
	_parent = null
	for mod in _modifiers:
		mod.uninit_stat(_remove_all)

## Adds a modifier to this set.[br]
## [param mod]: The modifier to add.
func add_modifier(mod: StatModifier) -> StatModifier:
	if _marked_for_deletion or mod == null: return null
	var mod2 = mod.duplicate(true)
	_modifiers.append(mod2)
	mod2.init_stat(_parent)
	# Only apply if conditions are met
	if _apply and condition == null:
		mod2.apply()
	if condition != null and _condition_apply_on_start:
		mod2.apply()
	return mod2

## Removes a modifier from this set.[br]
## [param mod]: The modifier to remove.
func remove_modifier(mod: StatModifier) -> void:
	var mod2 = find_mod(mod)
	if mod2 == null: return
	mod2.uninit_stat(_remove_all)
	_modifiers.erase(mod2)

## Returns a reference to the modifier at the specified index. If the index is out of range, returns null.
func modifier_at(index: int) -> StatModifier:
	if index < 0 or index >= len(_modifiers): return null   
	return _modifiers[index]

## Returns the number of _modifiers in this set.
func modifiers_count() -> int:    
	return len(_modifiers)

## Clears all _modifiers in this set.
func clear_modifiers() -> void:    
	for mod in _modifiers:
		mod.uninit_stat(_remove_all)
	_modifiers.clear()

## Clears all _modifiers in this set and uninitializes the condition.
func clear_all() -> void:
	clear_modifiers()
	if condition != null:
		condition.uninit_stat()
		_disconnect_condition()

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if condition != null:
		condition._process(delta)
	
## Deletes this modifier set.
func delete() -> void:
	process = false
	if condition != null:
		_disconnect_condition()
		condition.uninit_stat()
	clear_modifiers()
	_marked_for_deletion = true

## Returns true if this modifier set is marked for deletion, false otherwise.
func is_marked_for_deletion() -> bool:
	return _marked_for_deletion

## Make copy of this modifier set
func copy() -> StatModifierSet:
	var mod_set = StatModifierSet.new(_modifier_name, process, _group)
	for mod in _modifiers:
		mod_set._modifiers.append(mod.copy())
	mod_set.condition = condition.duplicate(true) if condition else null    
	mod_set.process = process
	mod_set._marked_for_deletion = _marked_for_deletion
	mod_set._group = _group
	mod_set._remove_all = _remove_all
	mod_set.merge_enabled = merge_enabled
	mod_set._condition_apply_on_start = _condition_apply_on_start
	mod_set._condition_pause_process = _condition_pause_process
	mod_set.apply_on_condition_change = apply_on_condition_change
	mod_set.remove_on_condition_change = remove_on_condition_change
	return mod_set

## Interpolates this modifier set with another modifier set.[br]
## [param other]: The other modifier set to interpolate with.[br]
## [param t]: The interpolation factor.[br]
## Returns the interpolated modifier set.
func interpolate_with(other: StatModifierSet, t: float):
	if other == null: return
	for i in range(min(len(_modifiers), len(other._modifiers))):
		if _modifiers[i].is_equal(other._modifiers[i]):
			_modifiers[i].interpolate(other._modifiers[i], t)

## Returns a dictionary representation of this modifier set.
func to_dict() -> Dictionary:
	return {
		"modifiers": _modifiers.map(func(m: StatModifier):
			return {"class_name": m.get_class_name(),"data": m.to_dict()}),
		"modifier_name": _modifier_name,
		"group": _group,
		"process": process,
		"condition": condition.to_dict() if condition else {},
		"condition_class": condition.get_class_name() if condition else "",
		"marked_for_deletion": _marked_for_deletion,
		"remove_all": _remove_all,
		"merge_enabled": merge_enabled,
		"condition_apply_on_start": _condition_apply_on_start,
		"condition_pause_process": _condition_pause_process,
		"apply_on_condition_change": apply_on_condition_change,
		"remove_on_condition_change": remove_on_condition_change
	}

## Loads this modifier set from a dictionary.
func from_dict(data: Dictionary) -> void:
	if data == null: return
	
	clear_all()
	
	_modifiers.assign(data.get("modifiers", []).map(
		func(m_data: Dictionary): 
			var m = _instantiate_modifier(m_data.get("class_name", ""))
			m.from_dict(m_data["data"])
			m.init_stat(_parent)
			return m
	))
	
	_modifier_name = data.get("modifier_name", "")
	_group = data.get("group", "")
	process = data.get("process", false)

	if data.has("condition_class"):
		condition = _instantiate_condition(data["condition_class"])
		condition.from_dict(data["condition"])
		condition.init_stat(_parent)
		_connect_condition()

	_marked_for_deletion = data.get("marked_for_deletion", false)
	_remove_all = data.get("remove_all", false)
	merge_enabled = data.get("merge_enabled", false)
	_condition_apply_on_start = data.get("condition_apply_on_start", false)
	_condition_pause_process = data.get("condition_pause_process", false)
	apply_on_condition_change = data.get("apply_on_condition_change", false)
	remove_on_condition_change = data.get("remove_on_condition_change", false)

func _instantiate_modifier(modifier_type: String) -> StatModifier:
	if modifier_type in modifier_types:
		return modifier_types[modifier_type].new()
	else:
		push_warning("Unknown modifier type: %s, defaulting to StatModifier." % modifier_type)
		return StatModifier.new()

func _instantiate_condition(condition_type: String) -> Condition:
	if condition_type in condition_types:
		return condition_types[condition_type].new()
	else:
		push_warning("Unknown condition type: %s, defaulting to Condition." % condition_type)
		return Condition.new()

## Returns the class name of this modifier set.
func get_class_name() -> String:
	return "StatModifierSet"
