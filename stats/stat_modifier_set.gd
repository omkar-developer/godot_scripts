extends Resource

## A class that represents a set of stat _modifiers and provides methods to manage and apply them.
class_name StatModifierSet

## Array of _modifiers in this set.
@export var _modifiers: Array[StatModifier] = []

## The name of this modifier set.
@export var _modifier_name: String = ""

## The group to which this modifier set belongs.
@export var _group := ""

## Whether to process this modifier set every frame.
@export var process := false

## The condition associated with this modifier set.
@export var condition: Condition

var _marked_for_deletion := false

## The _parent object associated with this modifier set.
var _parent: RefCounted

var _apply := true
var _remove_all := true

func _init(modifier_name := "", _process_every_frame := false, group := "") -> void:
    _modifier_name = modifier_name
    _group = group
    process = _process_every_frame

## Merges a parallel StatModifierSet into this one.[br]
## [param modifer_set]: The StatModifierSet to merge.
func _merge_parellel(modifer_set: StatModifierSet) -> void:
    if _modifiers.size() != modifer_set._modifiers.size(): return
    for i in range(modifer_set._modifiers.size() - 1, -1, -1):
        if modifer_set._modifiers[i].is_equal(_modifiers[i]):
            _modifiers[i].merge(modifer_set._modifiers[i])

## Merges a StatModifierSet into this one.[br]
## [param mod]: The StatModifierSet to merge.
func merge_mod(mod: StatModifierSet) -> void:
    _merge_parellel(mod)

## Sets the value of a modifier at a given index.[br]
## [param mod_idx]: The index of the modifier to set the value of.[br]
## [param value]: The value to set.
func set_mod_value(mod_idx: int, value: float) -> void:
    if _modifiers.size() > mod_idx:
        _modifiers[mod_idx].set_value(value)


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
        if mod.stat_name == stat_name and mod.type == type:
            return mod
    return null

## Finds a modifier that targets a given stat.[br]
## [param stat_name]: The name of the stat to target.[br]
## [return]: The modifier that targets the given stat, or null if no such modifier is found.
func find_mod_for_stat(stat_name: String) -> StatModifier:
    for mod in _modifiers:
        if mod.stat_name == stat_name:
            return mod
    return null

## Applies all _modifiers in this set to the _parent.
func _apply_effect() -> void:
    for mod in _modifiers:
        mod.apply()

## Removes all _modifiers in this set from the _parent.
func _remove_effect() -> void:
    for mod in _modifiers:
        mod.remove_all()

## Initializes all _modifiers in this set with the given _parent.[br]
## [param _parent]: The _parent to initialize the _modifiers with.
func init_modifiers(parent: RefCounted) -> void:
    if parent == null: return
    if not parent.has_method("get_stat"): return
    _parent = parent
    for mod in _modifiers:
        mod.init_stat(parent)
    if _apply: _apply_effect()

## Uninitializes all _modifiers in this set.
func uninit_modifiers() -> void:
    _parent = null
    for mod in _modifiers:
        mod.uninit_stat(_remove_all)

## Adds a modifier to this set.[br]
## [param mod]: The modifier to add.
func add_modifier(mod: StatModifier) -> void:
    _modifiers.append(mod.duplicate(true))
    mod.init_stat(_parent)
    if _apply: mod.apply()

## Removes a modifier from this set.[br]
## [param mod]: The modifier to remove.
func remove_modifier(mod: StatModifier) -> void:
    var mod2 = find_mod(mod)
    if mod2 == null: return
    mod2.uninit_stat(_remove_all)
    _modifiers.erase(mod2)

## Clears all _modifiers in this set.
func clear_modifiers() -> void:
    for mod in _modifiers:
        mod.uninit_stat(_remove_all)
    _modifiers.clear()

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
    pass
    
## Deletes this modifier set.
func delete() -> void:
    clear_modifiers()
    _marked_for_deletion = true

## Returns true if this modifier set is marked for deletion, false otherwise.
func is_marked_for_deletion() -> bool:
    return _marked_for_deletion