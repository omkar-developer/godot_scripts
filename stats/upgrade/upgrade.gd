@tool
## Manages the progression of a single upgrade track, handling XP, levels,
## requirements, and applying modifiers.[br]
## Tracks experience points ([member current_xp]) and [member current_level] for a specific upgrade ([member upgrade_name]).[br]
## Can automatically apply upgrades ([member auto_upgrade]) when requirements (XP, materials) are met,
## or allow manual triggering. Applies [StatModifierSet] resources defined in [UpgradeLevelConfig]
## resources ([member level_configs]) for each level. Emits signals for various events like leveling up ([signal upgrade_applied]),
## reaching max level ([signal max_level_reached]), or hitting defined step levels ([signal step_reached]).[br]
## Also provides a preview system for the effects of the next available upgrade ([method has_preview], [method simulate_next_effect]).
extends Resource
class_name Upgrade

## Emitted when an upgrade is successfully applied.[br]
## Passes the [param new_level] that was just reached and the [param applied_config] ([UpgradeLevelConfig]) for that level.
signal upgrade_applied(new_level: int, applied_config: UpgradeLevelConfig)

## Emitted when the modifiers of the previous level are removed (typically just before applying the next level's).[br]
## Passes the [param removed_level] index (the level whose effects were removed) and the corresponding [param removed_config] ([UpgradeLevelConfig]).
signal upgrade_removed(removed_level: int, removed_config: UpgradeLevelConfig)

## Emitted when the maximum level defined in [member level_configs] is reached.
signal max_level_reached()

## Emitted when a level defined in the [member step_levels] array is reached.[br]
## Passes the specific [param step_level] number that was reached.
signal step_reached(step_level: int)

## Emitted when the [method do_refund] method is called.[br]
## Passes the total amount of XP and materials refunded.
signal refund_applied(xp: int, materials: Dictionary)

## If [code]true[/code], automatically attempts to upgrade whenever XP is added and requirements are met via [method add_xp].[br]
## If [code]false[/code], an upgrade must be triggered manually (e.g., via a UI button calling [method try_upgrade]).
@export var auto_upgrade: bool = true
## An array of [UpgradeLevelConfig] resources defining the requirements and effects for each level.[br]
## The order in this array determines the level progression (index 0 is level 1's config, index 1 is level 2's, etc.).
@export var level_configs: Array[UpgradeLevelConfig] = []
## An array of specific level numbers that trigger the [signal step_reached] signal when achieved.
@export var step_levels: Array[int] = []

## The current level of this upgrade track. Starts at 0 (meaning no levels completed). Level 1 is the first upgrade.
@export var current_level: int = 0
## The current accumulated experience points towards the next level.
@export var current_xp: int = 0

@export_group("Auto Generate")
## Curve defining how XP requirements scale between first and last upgrade
@export var xp_curve: Curve = null
## Curve defining how modifier value scale between first and last upgrade
@export var modifier_curve : Curve = null	
## Curve defining how material requirements scale between first and last upgrade
@export var materials_curve: Curve = null
## The first upgrade configuration to interpolate from
@export var first_upgrade: UpgradeLevelConfig = null
## The last upgrade configuration to interpolate to
@export var last_upgrade: UpgradeLevelConfig = null
## Number of levels to generate (including first and last)
@export var level_count: int = 2

@export_tool_button("Generate Level Configs")
var generate =_generate_level_configs

## The [StatModifierSet] currently applied by this upgrade track. Internal use.
var _current_modifier: StatModifierSet = null
## The owner object whose stats will be modified. Must be set via [method init].
var _stat_owner: Object = null

## must have: func has_materials(required_materials: Dictionary) -> bool [br]
## func consume_materials(required_materials: Dictionary) -> bool [br]
## The inventory system used to check and consume required materials. Must be set via [method init].
var _inventory: Object = null # Assuming an Inventory class/script exists

## Initializes the UpgradeTrack with necessary dependencies.[br]
## [b]Must[/b] be called before adding XP or attempting upgrades.[br]
## [param stat_owner]: The object whose stats this track will modify (passed to [method StatModifierSet.init_modifiers]).[br]
## [param inventory]: The [Inventory] node used for material checks and consumption.[br]
func init_upgrade(stat_owner: Object, inventory: Object) -> void:    
	assert(is_instance_valid(stat_owner), "UpgradeTrack.init: stat_owner must be a valid object.")
	if _inventory != null:
		assert(is_instance_valid(inventory), "UpgradeTrack.init: inventory must be a valid object.")
		assert(inventory.has_method("has_materials"), "Inventory must have a has_materials method.")
		assert(inventory.has_method("consume_materials"), "Inventory must have a consume_materials method.")
	assert(stat_owner.has_method("get_stat"), "parent must have get_stat method")
	_stat_owner = stat_owner
	_inventory = inventory

## Generates level configurations based on the auto-generate settings
func _generate_level_configs() -> void:
	if not first_upgrade or not last_upgrade or level_count < 2:
		push_warning("Cannot generate levels: missing required configuration")
		return
		
	if not xp_curve:
		xp_curve = Curve.new()
		xp_curve.add_point(Vector2(0, 0))
		xp_curve.add_point(Vector2(1, 1))
		
	if not materials_curve:
		materials_curve = Curve.new()
		materials_curve.add_point(Vector2(0, 0))
		materials_curve.add_point(Vector2(1, 1))
	
	level_configs.clear()
	level_configs.push_back(first_upgrade)
	
	# Generate intermediate levels
	for i in range(1, level_count - 1):
		var t = float(i) / (level_count - 1)
		var new_config = UpgradeLevelConfig.new()
		
		# Interpolate XP requirements
		var xp_factor = xp_curve.sample(t)
		new_config.xp_required = lerp(
			first_upgrade.xp_required,
			last_upgrade.xp_required,
			xp_factor
		)
		
		# Interpolate material requirements
		if not first_upgrade.required_materials.is_empty() and not last_upgrade.required_materials.is_empty():
			var materials_factor = materials_curve.sample(t)
			new_config.required_materials = {}
			
			# Interpolate each material type
			for material in first_upgrade.required_materials:
				if material in last_upgrade.required_materials:
					new_config.required_materials[material] = lerp(
						first_upgrade.required_materials[material],
						last_upgrade.required_materials[material],
						materials_factor
					)
		
		# Interpolate modifiers if both configs have them
		if first_upgrade.modifiers and last_upgrade.modifiers:
			var modifier_factor = modifier_curve.sample(t)
			var new_modifiers: StatModifierSet = first_upgrade.modifiers.duplicate()
			for f in range(min(len(new_modifiers._modifiers), len(last_upgrade.modifiers._modifiers))):
				var current = new_modifiers._modifiers[f]
				var target = last_upgrade.modifiers._modifiers[f]

				if current._stat_name == target._stat_name and current._type == target._type:  # or skip this if unnecessary
					current._value = lerp(current._value, target._value, modifier_factor)

			new_config.modifiers = new_modifiers
		
		level_configs.push_back(new_config)
	
	level_configs.push_back(last_upgrade)

## Validates and updates auto-generated configs when properties change
func _validate_auto_generate() -> void:
	if first_upgrade and last_upgrade and level_count >= 2:
		_generate_level_configs()

## Adds experience points to the track.[br]
## If [member auto_upgrade] is [code]true[/code], it will attempt to level up if requirements are met by calling [method do_upgrade].[br]
## [param amount]: The amount of XP to add. Should be non-negative.[br]
func add_xp(amount: int) -> bool:
	if amount <= 0:
		printerr("UpgradeTrack: Cannot add negative or zero XP.")
		return false
	if _is_max_level(): # Don't add XP if already max level
		return false

	current_xp += amount
	var did_upgrade: bool = false
	if auto_upgrade:
		while can_upgrade():
			if not do_upgrade():
				break
			did_upgrade = true
	return did_upgrade

## Gets the XP required to reach the next level (complete the current level).[br]
## Returns 0 if the track is already at the maximum level.[br]
## [return]: The required XP defined in the [UpgradeLevelConfig] for the current target level, or 0 if max level reached.[br]
func get_current_xp_required() -> int:
	if _is_max_level():
		return 0
	# Check bounds before accessing
	if current_level >= level_configs.size():
		printerr("UpgradeTrack: current_level is out of bounds for level_configs in get_current_xp_required.")
		return 9223372036854775807 # INT64_MAX in GDScript
	return max(0, level_configs[current_level].xp_required - current_xp)

## Gets the current level of the upgrade track.
func get_current_level() -> int:
	return current_level

## Calculates the progress towards the next level as a ratio between 0.0 and 1.0.[br]
## Returns 1.0 if the required XP is 0 (e.g., at max level or if config has 0 XP).[br]
## [return]: The progress ratio ([code]current_xp / required_xp[/code]), clamped between 0.0 and 1.0.[br]
func get_progress_ratio() -> float:
	var required = get_current_xp_required()
	return clamp(float(current_xp) / required, 0.0, 1.0) if required > 0 else 1.0

## Checks if the upgrade track can currently level up based on XP and material requirements.[br]
## Internal use.[br]
## [return]: [code]true[/code] if the track can level up, [code]false[/code] otherwise.[br]
func can_upgrade(added_xp: int=0) -> bool:
	if _is_max_level():
		return false

	# Ensure level_configs has an entry for the current level
	if current_level >= level_configs.size():
		printerr("UpgradeTrack: Current level %d is out of bounds for level_configs (size %d)." % [current_level, level_configs.size()])
		return false

	var config: UpgradeLevelConfig = level_configs[current_level]

	# Check materials
	if config.required_materials and not config.required_materials.is_empty(): # Check if dictionary exists and is not empty
		if not is_instance_valid(_inventory):
			printerr("UpgradeTrack: Inventory not initialized or invalid!")
			return false
		if not _inventory.has_materials(config.required_materials):
			return false

	# Check XP
	return current_xp + added_xp >= config.xp_required


## Levels up the upgrade track by adding the required XP and emitting the [signal upgrade_applied] signal.[br]
## Returns [code]true[/code] if the level up was successful, [code]false[/code] otherwise.[br]
func level_up() -> bool:
	if get_current_xp_required() == 0:
		if _is_max_level(): # Don't add XP if already max level
			return false
		if can_upgrade():
			return do_upgrade()
		return false
	return add_xp(get_current_xp_required())

## Sets the level of the upgrade track.[br]
## Removes any previous modifiers and emits the [signal upgrade_removed] signal. Internal use.[br]
## [param level]: The level to set the upgrade track to. Must be a positive integer.
func set_level(level: int=1) -> bool:
	if level <= 0:
		printerr("UpgradeTrack: Cannot set level to a negative number or zero.")
		return false
	
	if level > level_configs.size():
		printerr("UpgradeTrack: Level %d is out of bounds for level_configs (size %d)." % [level, level_configs.size()])
		return false

	var config: UpgradeLevelConfig = level_configs[level - 1]

	remove_current_upgrade()

	if config.modifiers:
		config.modifiers.init_modifiers(_stat_owner)
		_current_modifier = config.modifiers
	
	current_xp = 0
	current_level = level

	emit_signal("upgrade_applied", current_level, config)

	if step_levels.has(current_level):
		emit_signal("step_reached", current_level)

	if _is_max_level():
		emit_signal("max_level_reached")
	
	return true

## Performs the upgrade process.[br]
## Removes previous modifiers, deducts materials and XP, applies new modifiers,
## increments the level, and emits relevant signals. Internal use.
func do_upgrade() -> bool:
	# Double check conditions before proceeding
	if not can_upgrade():
		printerr("Upgrade: do_upgrade called when can_upgrade is false.")
		return false
	if not is_instance_valid(_stat_owner):
		printerr("Upgrade: Stat owner invalid during upgrade.")
		return false

	var config: UpgradeLevelConfig = level_configs[current_level]

	# Deduct materials
	if _inventory and config.required_materials:
		if not _inventory.consume_materials(config.required_materials):
			printerr("Upgrade: Failed to consume required materials for upgrade.")
			return false

	# Remove modifiers from the level we are leaving (if any were applied)
	remove_current_upgrade()

	# Apply new modifiers for the level being entered
	if config.modifiers:
		config.modifiers.init_modifiers(_stat_owner)
		_current_modifier = config.modifiers

	# Deduct XP and increment level
	current_xp -= config.xp_required
	current_level += 1 # Increment level *after* processing the config for the completed level

	# Emit signals AFTER state is updated
	# Pass the config of the level that was just *completed* / *applied*
	emit_signal("upgrade_applied", current_level, config) # current_level is now the new level number

	if step_levels.has(current_level):
		emit_signal("step_reached", current_level)

	if _is_max_level():
		emit_signal("max_level_reached")
	
	return true

## Removes the stat modifiers applied by the most recently completed level (if any).[br]
## Calls [method StatModifierSet._remove_effect] and [method StatModifierSet.uninit_modifiers].[br]
## Does [b]not[/b] emit the [signal upgrade_removed] signal; that is handled by [method do_upgrade].
func remove_current_upgrade() -> void:
	if _current_modifier:
		var config = level_configs[current_level - 1]
		_current_modifier.uninit_modifiers()
		_current_modifier = null
		emit_signal("upgrade_removed", current_level, config)

## Checks if the current level is greater than or equal to the number of defined level configurations.[br]
## Internal use.[br]
## [return]: [code]true[/code] if the maximum level has been reached or exceeded, [code]false[/code] otherwise.[br]
func _is_max_level() -> bool:
	return current_level >= level_configs.size()

# --- PREVIEW SYSTEM ---

## Checks if there is a next level configuration with modifiers to preview.[br]
## [return]: [code]true[/code] if not at max level and the next level config ([code]level_configs[current_level][/code]) has a valid [member UpgradeLevelConfig.modifiers] set.[br]
func has_preview() -> bool:
	# Check bounds first
	if _is_max_level() or current_level < 0: # current_level should not be < 0, but safety check
		return false
	# Check if the config at the current level exists and has modifiers
	return level_configs[current_level].modifiers != null

## Gets the [StatModifierSet] associated with the *next* upgrade level configuration.[br]
## Assumes [method has_preview] is true when calling.[br]
## [return]: The [StatModifierSet] for the next level ([code]level_configs[current_level].modifiers[/code]), or [code]null[/code] if none exists or called inappropriately.[br]
func get_preview_modifier_set() -> StatModifierSet:
	if not has_preview():
		printerr("UpgradeTrack: get_preview_modifier_set called when no preview is available.")
		return null
	# Bounds already checked by has_preview implicitly
	return level_configs[current_level].modifiers

## Simulates the effect of the next upgrade's modifiers without applying them permanently.[br]
## Useful for displaying potential stat changes in UI.[br]
## Requires the [StatModifierSet] class to have a [code]simulate_effect()[/code] method implemented.[br]
## [return]: A [Dictionary] representing the simulated stat changes (structure depends on [StatModifierSet] implementation). Returns empty [Dictionary] ([code]{}[/code]) if no preview is available or method is missing.[br]
func simulate_next_effect() -> Dictionary:
	var preview_mod_set = get_preview_modifier_set()
	if preview_mod_set and preview_mod_set.has_method("simulate_effect"):
		return preview_mod_set.simulate_effect()
	return {}

## Gets temporarily applied stats from the next upgrade's modifiers for preview purposes.[br]
## Useful for previewing effects that might involve temporary status applications.[br]
## Requires the [StatModifierSet] class to have a [code]get_temp_applied_stat()[/code] method implemented.[br]
## [return]: An [Array] representing temporary stats (structure depends on [StatModifierSet] implementation). Returns empty [Array] ([code][][/code]) if no preview is available or method is missing.[br]
func get_temp_applied_stats() -> Array:
	var preview_mod_set = get_preview_modifier_set()
	if preview_mod_set and preview_mod_set.has_method("get_temp_applied_stat"):
		return preview_mod_set.get_temp_applied_stat()
	return []

## Calculates the XP and material refund for the current level (if any).[br]
## [return]: A [Dictionary] with keys "xp" and "materials".
func get_total_refund() -> Dictionary:
	var xp_refund := current_xp
	var material_refund := {}

	for i in range(current_level):
		var config := level_configs[i]

		xp_refund += config.xp_required

		for mat in config.required_materials:
			material_refund[mat] = material_refund.get(mat, 0) + config.required_materials[mat]

	return {
		"xp": xp_refund,
		"materials": material_refund
	}

## Refunds the player's XP and materials for the current level (if any) and resets the upgrade to the initial state (level 0, 0 XP) removing any currently applied modifiers.[br].
## [return]: The total amount of XP refunded.
func do_refund() -> int:
	# First, get all refundable materials and XP from inventory
	var refund_data := get_total_refund()
	
	# Return all consumed materials to the player's inventory
	if _inventory and not refund_data.materials.is_empty():
		if _inventory.has_method("store_materials"):
			_inventory.store_materials(refund_data.materials)
		else:
			printerr("UpgradeTrack: Inventory does not have a store_materials method.")
			return 0
	
	# Reset XP back to 0
	reset_upgrades()
	
	# Emit the refund signal with total amount
	emit_signal("refund_applied",
		refund_data.xp,
		refund_data.materials
	)
	return refund_data.xp

## Resets the upgrade to its initial state (level 0, 0 XP).[br]
## Removes any currently applied modifiers.[br]
## [color=yellow]Warning:[/color] This does not refund spent materials or XP.
func reset_upgrades() -> void:
	remove_current_upgrade() # Remove modifiers from the current level
	current_level = 0
	current_xp = 0

## Converts the upgrade's current state to a dictionary for serialization.[br]
## [return]: A [Dictionary] containing the upgrade's serializable state.
func to_dict() -> Dictionary:
	var data := {
		"current_level": current_level,
		"current_xp": current_xp,
		"auto_upgrade": auto_upgrade,
	}
	
	# Save current modifier state if exists
	if _current_modifier:
		data["current_modifier"] = _current_modifier.to_dict() if _current_modifier.has_method("to_dict") else {}
		
	return data

## Restores the upgrade's state from a dictionary.[br]
## [param data]: The [Dictionary] containing the upgrade state to restore.[br]
## [return]: [code]true[/code] if successful, [code]false[/code] otherwise.
func from_dict(data: Dictionary) -> bool:
	# Check for required keys
	if not data.has("current_level") or not data.has("current_xp") or not data.has("auto_upgrade"):
		return false
	
	# Reset current state
	reset_upgrades()
	
	# Restore values
	auto_upgrade = data.get("auto_upgrade")
	current_xp = data.get("current_xp")	

	# Set level last as it will apply modifiers
	if not set_level(data.get("current_level", 0)):
		return false
	
	# Restore modifier state if present
	var current_modifier_data = data.get("current_modifier")
	if current_modifier_data and _current_modifier.has_method("from_dict"):
		_current_modifier.from_dict(current_modifier_data)
	
	return true
