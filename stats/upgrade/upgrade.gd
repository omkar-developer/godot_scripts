# UpgradeTrack.gd
extends Resource
class_name UpgradeTrack

signal upgrade_applied(new_level: int, applied_config: UpgradeLevelConfig)
signal upgrade_removed(removed_level: int, removed_config: UpgradeLevelConfig)
signal max_level_reached()
signal step_reached(step_level: int)

@export var upgrade_name: String = ""
@export var description: String = ""
@export var auto_upgrade: bool = true
@export var level_configs: Array[UpgradeLevelConfig] = []
@export var step_levels: Array[int] = []

@export var current_level: int = 0
@export var current_xp: int = 0

var _current_modifier: StatModifierSet = null
var _stat_owner: Object = null
var _inventory: Inventory = null

func init(stat_owner: Object, inventory: Inventory) -> void:
	_stat_owner = stat_owner
	_inventory = inventory

func add_xp(amount: int) -> void:
	current_xp += amount
	if auto_upgrade:
		while _can_upgrade():
			_do_upgrade()

func get_current_xp_required() -> int:
	return 0 if current_level >= level_configs.size() else level_configs[current_level].xp_required

func get_progress_ratio() -> float:
	var required = get_current_xp_required()
	return clamp(float(current_xp) / required, 0.0, 1.0) if required > 0 else 1.0

func _can_upgrade() -> bool:
	if _is_max_level():
		return false

	var config := level_configs[current_level]
	for mat in config.required_materials.keys():
		if _inventory.get_material_quantity(mat) < config.required_materials[mat]:
			return false
	return current_xp >= config.xp_required

func _do_upgrade() -> void:
	var config: UpgradeLevelConfig = level_configs[current_level]

	remove_current_upgrade()

	# Deduct materials
	for mat in config.required_materials.keys():
		_inventory.remove_material(mat, config.required_materials[mat])

	# Apply modifiers
	if config.modifiers:
		config.modifiers.init_modifiers(_stat_owner)
		config.modifiers._apply_effect()  # Explicit apply
		_current_modifier = config.modifiers

	current_xp -= config.xp_required
	current_level += 1

	emit_signal("upgrade_applied", current_level, config)

	if step_levels.has(current_level):
		emit_signal("step_reached", current_level)

	if _is_max_level():
		emit_signal("max_level_reached")

func remove_current_upgrade() -> void:
	if _current_modifier:
		_current_modifier._remove_effect()
		_current_modifier.uninit_modifiers()
		if current_level > 0:
			emit_signal("upgrade_removed", current_level, level_configs[current_level - 1])
		_current_modifier = null

func _is_max_level() -> bool:
	return current_level >= level_configs.size()

# --- PREVIEW SYSTEM ---

func has_preview() -> bool:
	return not _is_max_level() and level_configs[current_level].modifiers != null

func get_preview_modifier_set() -> StatModifierSet:
	return level_configs[current_level].modifiers

func simulate_next_effect() -> Dictionary:
	if not has_preview():
		return {}
	return get_preview_modifier_set().simulate_effect()

func get_temp_applied_stats() -> Array:
	if not has_preview():
		return []
	return get_preview_modifier_set().get_temp_applied_stat()
