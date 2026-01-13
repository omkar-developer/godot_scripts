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

@export var consume_materials_on_upgrade: bool = true

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

## Growth pattern types for infinite levels
enum GrowthPattern {
	LINEAR,       ## Linear growth (base + multiplier * (level - last_level))
	EXPONENTIAL,  ## Exponential growth (base * pow(multiplier, level - last_level))
	POLYNOMIAL,   ## Polynomial growth (base * pow(level / last_level, exponent))
	LOGARITHMIC,  ## Logarithmic growth (base * (1 + log(level / last_level) * multiplier))
	CUSTOM        ## Use custom formula
}

@export_group("Infinite Level Settings")
## If [code]true[/code], automatically attempts to upgrade whenever XP is added and requirements are met
@export var enable_infinite_levels: bool = false
## Growth pattern type for XP requirements
@export var infinite_xp_pattern: GrowthPattern = GrowthPattern.EXPONENTIAL
## Growth pattern type for material requirements
@export var infinite_material_pattern: GrowthPattern = GrowthPattern.EXPONENTIAL
## Growth pattern type for modifier values
@export var infinite_modifier_pattern: GrowthPattern = GrowthPattern.EXPONENTIAL

## Growth rate multiplier for XP in predefined patterns
@export_range(1.01, 3.0) var infinite_xp_multiplier: float = 1.15
## Growth rate multiplier for materials in predefined patterns
@export_range(1.01, 3.0) var infinite_material_multiplier: float = 1.1
## Growth rate multiplier for modifiers in predefined patterns
@export_range(1.01, 3.0) var infinite_modifier_multiplier: float = 1.05

## Exponent for polynomial growth (if selected)
@export_range(1.1, 5.0) var infinite_xp_exponent: float = 2.0
@export_range(1.1, 5.0) var infinite_material_exponent: float = 2.0
@export_range(1.1, 5.0) var infinite_modifier_exponent: float = 1.5

## Custom formulas (used only if corresponding pattern is set to CUSTOM)
## Available variables: level (the target level), base (the base value), last_level (the last defined level)
@export var infinite_xp_formula: String = "base * pow(1.15, level - last_level)"
@export var infinite_material_formula: String = "base * pow(1.1, level - last_level)" 
@export var infinite_modifier_formula: String = "base * pow(1.05, level - last_level)"

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
		assert(is_instance_valid(_inventory), "UpgradeTrack.init: inventory must be a valid object.")
		assert(inventory.has_method("has_materials"), "Inventory must have a has_materials method.")
		assert(inventory.has_method("consume_materials"), "Inventory must have a consume_materials method.")
	_stat_owner = stat_owner
	_inventory = inventory

## Calculates a value based on the selected growth pattern
func _calculate_with_pattern(base_value: float, level: int, last_level: int, 
							pattern: GrowthPattern, multiplier: float, 
							exponent: float, custom_formula: String) -> float:
	match pattern:
		GrowthPattern.LINEAR:
			return base_value + multiplier * (level - last_level)
			
		GrowthPattern.EXPONENTIAL:
			return base_value * pow(multiplier, level - last_level)
			
		GrowthPattern.POLYNOMIAL:
			return base_value * pow(float(level) / last_level, exponent)
			
		GrowthPattern.LOGARITHMIC:
			# Ensure we don't take log of values <= 0
			var log_input = max(float(level) / last_level, 1.01)
			return base_value * (1.0 + log(log_input) * multiplier)
			
		GrowthPattern.CUSTOM:
			var expression = Expression.new()
			var error = expression.parse(custom_formula, ["level", "base", "last_level"])
			if error != OK:
				printerr("Upgrade: Error parsing custom formula: ", expression.get_error_text())
				# Fall back to exponential
				return base_value * pow(1.15, level - last_level)
				
			var result = expression.execute([level, base_value, last_level])
			if expression.has_execute_failed() or not (typeof(result) in [TYPE_FLOAT, TYPE_INT]):
				printerr("Upgrade: Error executing custom formula")
				# Fall back to exponential
				return base_value * pow(1.15, level - last_level)
				
			return float(result)
			
	# Default fallback
	return base_value * pow(1.15, level - last_level)

## Generates a level config for a level beyond the explicitly defined configs
func _generate_extrapolated_config(level: int) -> UpgradeLevelConfig:
	if level_configs.is_empty():
		push_error("Cannot extrapolate config: no base configs defined")
		return null
		
	var last_level = level_configs.size()
	var last_config = level_configs[last_level - 1]
	var new_config = UpgradeLevelConfig.new()
	
	# Calculate XP using selected pattern
	var xp_base = last_config.xp_required
	var new_xp = _calculate_with_pattern(
		xp_base, level, last_level,
		infinite_xp_pattern, infinite_xp_multiplier,
		infinite_xp_exponent, infinite_xp_formula
	)
	new_config.xp_required = int(max(1, new_xp))
	
	# Handle materials
	if not last_config.required_materials.is_empty():
		var mats: Dictionary[StringName, int] = {}
		new_config.required_materials = mats
		
		for material in last_config.required_materials:
			var mat_base = last_config.required_materials[material]
			var new_amount = _calculate_with_pattern(
				mat_base, level, last_level,
				infinite_material_pattern, infinite_material_multiplier,
				infinite_material_exponent, infinite_material_formula
			)
			new_config.required_materials[material] = int(max(1, new_amount))
	
	# Handle modifiers
	if last_config.modifiers:
		var new_modifiers = last_config.modifiers.copy()
		
		for mod in new_modifiers._modifiers:
			var mod_base = mod._value
			var new_value = _calculate_with_pattern(
				mod_base, level, last_level,
				infinite_modifier_pattern, infinite_modifier_multiplier,
				infinite_modifier_exponent, infinite_modifier_formula
			)
			mod._value = new_value
			
		new_config.modifiers = new_modifiers
	
	return new_config

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
			var new_modifiers: StatModifierSet = first_upgrade.modifiers.copy()
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
func add_xp(amount: int, accumulate: bool = false) -> bool:
	if amount <= 0:
		printerr("UpgradeTrack: Cannot add negative or zero XP.")
		return false
	if is_max_level():
		if accumulate:
			current_xp += amount
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
func get_remaining_xp_to_level() -> int:
	if not enable_infinite_levels and is_max_level():
		return 0
		
	var required: int
	if current_level >= level_configs.size():
		if not enable_infinite_levels:
			return 0
		var extrapolated_config = _generate_extrapolated_config(current_level + 1)
		required = extrapolated_config.xp_required
	else:
		required = level_configs[current_level].xp_required
		
	return max(0, required - current_xp)

## Gets the required XP for the next level (complete the current level).
func get_required_xp_for_next_level() -> int:
	if not enable_infinite_levels and is_max_level():
		return 0

	if current_level >= level_configs.size():
		var cfg = _generate_extrapolated_config(current_level + 1)
		return cfg.xp_required

	return level_configs[current_level].xp_required


## Gets the current level of the upgrade track.
func get_current_level() -> int:
	return current_level

## Calculates the progress towards the next level as a ratio between 0.0 and 1.0.[br]
## Returns 1.0 if the required XP is 0 (e.g., at max level or if config has 0 XP).[br]
## [return]: The progress ratio ([code]current_xp / required_xp[/code]), clamped between 0.0 and 1.0).[br]
func get_progress_ratio() -> float:
	var required = get_required_xp_for_next_level()
	return clamp(float(current_xp) / required, 0.0, 1.0) if required > 0 else 1.0

## Checks if the upgrade track can currently level up based on XP and material requirements.[br]
## Internal use.[br]
## [return]: [code]true[/code] if the track can level up, [code]false[/code] otherwise.[br]
func can_upgrade(added_xp: int=0) -> bool:
	if not enable_infinite_levels and is_max_level():
		return false

	var config: UpgradeLevelConfig
	if current_level >= level_configs.size():
		if not enable_infinite_levels:
			return false
		config = _generate_extrapolated_config(current_level + 1)
	else:
		config = level_configs[current_level]

	# Check materials
	if config.required_materials and not config.required_materials.is_empty():
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
	if get_remaining_xp_to_level() == 0:
		if is_max_level():
			return false		
		return do_upgrade()
	return add_xp(get_remaining_xp_to_level())

## Sets the level of the upgrade track.[br]
## Removes any previous modifiers and emits the [signal upgrade_removed] signal. Internal use.[br]
## [param level]: The level to set the upgrade track to. Must be a positive integer.
func set_level(level: int=1) -> bool:
	if level <= 0:
		printerr("UpgradeTrack: Cannot set level to a negative number or zero.")
		return false
	
	var config: UpgradeLevelConfig
	if level > level_configs.size():
		if not enable_infinite_levels:
			printerr("UpgradeTrack: Level %d is out of bounds for level_configs (size %d)." % [level, level_configs.size()])
			return false
		config = _generate_extrapolated_config(level)
	else:
		config = level_configs[level - 1]

	remove_current_upgrade()

	if config.modifiers:
		config.modifiers.init_modifiers(_stat_owner)
		_current_modifier = config.modifiers
	
	current_xp = 0
	current_level = level

	emit_signal("upgrade_applied", current_level, config)

	if step_levels.has(current_level):
		emit_signal("step_reached", current_level)

	if not enable_infinite_levels and is_max_level():
		emit_signal("max_level_reached")
	
	return true

## Performs the upgrade process.[br]
## Removes previous modifiers, deducts materials and XP, applies new modifiers,
## increments the level, and emits relevant signals. Internal use.
func do_upgrade(ignore_cost: bool = false) -> bool:
	# Double check conditions before proceeding
	if not can_upgrade() and not ignore_cost:
		printerr("Upgrade: do_upgrade called when can_upgrade is false.")
		return false

	var config: UpgradeLevelConfig
	if current_level >= level_configs.size():
		if not enable_infinite_levels:
			return false
		config = _generate_extrapolated_config(current_level + 1)
	else:
		config = level_configs[current_level]
	
	# Stat owner is only required if this level actually has modifiers
	if config.modifiers and not is_instance_valid(_stat_owner):
		printerr("Upgrade: Stat owner invalid during upgrade.")
		return false

	# Check and optionally consume materials
	if (_inventory and config.required_materials) and not ignore_cost:
		# Always verify materials are available
		if not _inventory.has_materials(config.required_materials):
			printerr("Upgrade: Not enough materials for upgrade.")
			return false
		
		# Only consume if the flag is enabled
		if consume_materials_on_upgrade:
			if not _inventory.consume_materials(config.required_materials):
				printerr("Upgrade: Failed to consume required materials for upgrade.")
				return false

	# Remove modifiers from the level we are leaving (if any were applied)
	remove_current_upgrade()

	# Apply new modifiers for the level being entered
	if config.modifiers:
		config.modifiers._apply = true
		config.modifiers.init_modifiers(_stat_owner)
		_current_modifier = config.modifiers

	# Deduct XP and increment level
	if not ignore_cost:
		current_xp -= config.xp_required
	current_level += 1

	# Emit signals AFTER state is updated
	emit_signal("upgrade_applied", current_level, config)

	if step_levels.has(current_level):
		emit_signal("step_reached", current_level)

	if not enable_infinite_levels and is_max_level():
		emit_signal("max_level_reached")
	
	return true

## Removes the stat modifiers applied by the most recently completed level (if any).[br]
## Calls [method StatModifierSet._remove_effect] and [method StatModifierSet.uninit_modifiers].[br]
## Does [b]not[/b] emit the [signal upgrade_removed] signal; that is handled by [method do_upgrade].
func remove_current_upgrade() -> void:
	if _current_modifier:
		var config: UpgradeLevelConfig
		if current_level > level_configs.size():
			config = _generate_extrapolated_config(current_level)
		else:
			config = level_configs[current_level - 1]
		
		_current_modifier.uninit_modifiers()
		_current_modifier = null
		emit_signal("upgrade_removed", current_level, config)

## Checks if the current level is greater than or equal to the number of defined level configurations.[br]
## Internal use.[br]
## [return]: [code]true[/code] if the maximum level has been reached or exceeded, [code]false[/code] otherwise.[br]
func is_max_level() -> bool:
	return not enable_infinite_levels and current_level >= level_configs.size()

# --- PREVIEW SYSTEM ---

## Checks if there is a next level configuration with modifiers to preview.[br]
## [return]: [code]true[/code] if not at max level and the next level config ([code]level_configs[current_level][/code]) has a valid [member UpgradeLevelConfig.modifiers] set.[br]
func has_preview() -> bool:
	# Check bounds first
	if not enable_infinite_levels and is_max_level(): 
		return false

	if current_level < level_configs.size():
		# Check if the config at the current level exists and has modifiers
		return level_configs[current_level].modifiers != null
	else:
		# For extrapolated levels, check if the last config has modifiers
		return level_configs.size() > 0 and level_configs[-1].modifiers != null

## Gets the [StatModifierSet] associated with the *next* upgrade level configuration.[br]
## Assumes [method has_preview] is true when calling.[br]
## [return]: The [StatModifierSet] for the next level ([code]level_configs[current_level].modifiers[/code]), or [code]null[/code] if none exists or called inappropriately.[br]
func get_preview_modifier_set() -> StatModifierSet:
	if not has_preview():
		printerr("UpgradeTrack: get_preview_modifier_set called when no preview is available.")
		return null
	
	var modifer_set: StatModifierSet
		
	var config: UpgradeLevelConfig
	if current_level >= level_configs.size():
		if not enable_infinite_levels:
			return null
		config = _generate_extrapolated_config(current_level)
		modifer_set = config.modifiers if config else null
	else:
		modifer_set = level_configs[current_level].modifiers.copy()
	modifer_set.init_modifiers(_stat_owner, false)
	return modifer_set

## Simulates the effect of the next upgrade's modifiers without applying them permanently.[br]
## Returns a Dictionary with the differences between current and simulated values.[br]
## [return]: A Dictionary in format { stat_name: { "old_value": float, "old_max": float, "value_diff": float, "max_diff": float } }[br]
func simulate_next_effect() -> Dictionary:
	var preview_mod_set = get_preview_modifier_set()
	if not preview_mod_set or not preview_mod_set.has_method("simulate_effect"):
		return {}

	# Store current stats before simulation
	var current_stats = {}
	var affected_stats = preview_mod_set.get_affected_stats()
	for stat_name in affected_stats:
		current_stats[stat_name] = {
			"value": affected_stats[stat_name].get_value(),
			"max": affected_stats[stat_name].get_max()
		}

	# Store current modifier state
	var current_mod = _current_modifier
	
	# Temporarily remove current modifiers
	if current_mod:
		current_mod.uninit_modifiers()
		_current_modifier = null
	
	# Get simulated effect
	var simulated_effect = preview_mod_set.simulate_effect()

	# Restore current modifiers
	if current_mod:
		current_mod.init_modifiers(_stat_owner)
		_current_modifier = current_mod
	
	# Calculate differences and format result
	var result = {}
	for stat_name in simulated_effect:
		if stat_name in current_stats:
			var new_value = simulated_effect[stat_name]["old_value"] + simulated_effect[stat_name]["value_diff"]
			var new_max = simulated_effect[stat_name]["old_max"] + simulated_effect[stat_name]["max_diff"]
			result[stat_name] = {
				"old_value": current_stats[stat_name]["value"],
				"old_max": current_stats[stat_name]["max"],
				"value_diff": new_value - current_stats[stat_name]["value"],
				"max_diff": new_max - current_stats[stat_name]["max"]
			}
	
	return result

## Calculates the XP and material refund for the current level (if any).[br]
## [return]: A [Dictionary] with keys "xp" and "materials".
func get_total_refund() -> Dictionary:
	var xp_refund := current_xp
	var material_refund := {}

	for i in range(current_level):
		var config: UpgradeLevelConfig
		if i >= level_configs.size():
			if not enable_infinite_levels:
				break
			config = _generate_extrapolated_config(i + 1)
			if not config:
				break
		else:
			config = level_configs[i]

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
	# First, gather refundable data
	var refund_data := get_total_refund()

	# Only refund materials if they were originally consumed
	if consume_materials_on_upgrade and _inventory and not refund_data.materials.is_empty():
		if _inventory.has_method("store_materials"):
			_inventory.store_materials(refund_data.materials)
		else:
			printerr("UpgradeTrack: Inventory does not have a store_materials method.")
			return 0

	# Reset XP and level
	reset_upgrades()

	# Emit refund signal
	emit_signal("refund_applied", refund_data.xp, refund_data.materials)

	return refund_data.xp


## Returns the [UpgradeLevelConfig] for the current level (if any) or null.
func get_current_level_config() -> UpgradeLevelConfig:
	var config: UpgradeLevelConfig
	
	if current_level >= level_configs.size():
		if not enable_infinite_levels:
			return null
		config = _generate_extrapolated_config(current_level + 1)
	else:
		config = level_configs[current_level]
	return config

## Resets the upgrade to its initial state (level 0, 0 XP).[br]
## Removes any currently applied modifiers.[br]
## [color=yellow]Warning:[/color] This does not refund spent materials or XP.
func reset_upgrades() -> void:
	remove_current_upgrade() # Remove modifiers from the current level
	current_level = 0
	current_xp = 0

## Returns a [Dictionary] representing the current upgrade track state.
func to_dict() -> Dictionary:
	var data := {
		"current_level": current_level,
		"current_xp": current_xp,
		"auto_upgrade": auto_upgrade,
		"enable_infinite_levels": enable_infinite_levels,

		# Patterns & scaling parameters
		"infinite_xp_pattern": infinite_xp_pattern,
		"infinite_material_pattern": infinite_material_pattern,
		"infinite_modifier_pattern": infinite_modifier_pattern,

		"infinite_xp_multiplier": infinite_xp_multiplier,
		"infinite_material_multiplier": infinite_material_multiplier,
		"infinite_modifier_multiplier": infinite_modifier_multiplier,

		"infinite_xp_exponent": infinite_xp_exponent,
		"infinite_material_exponent": infinite_material_exponent,
		"infinite_modifier_exponent": infinite_modifier_exponent,

		"infinite_xp_formula": infinite_xp_formula,
		"infinite_material_formula": infinite_material_formula,
		"infinite_modifier_formula": infinite_modifier_formula,
		"consume_materials_on_upgrade" : consume_materials_on_upgrade
	}

	# Serialize all level configs (deep)
	if level_configs.size() > 0:
		var levels_data: Array = []
		for cfg in level_configs:
			if cfg and cfg.has_method("to_dict"):
				levels_data.append(cfg.to_dict())
		data["level_configs"] = levels_data

	# Save current modifier (if exists)
	if _current_modifier:
		data["current_modifier"] = {
			"class_type": _current_modifier.get_script().get_global_name(),
			"data": _current_modifier.to_dict() if _current_modifier.has_method("to_dict") else {}
		}

	return data


## Restores the upgrade track state from a [Dictionary].
func from_dict(data: Dictionary) -> bool:
	if not data.has("current_level") or not data.has("current_xp"):
		return false

	reset_upgrades()

	auto_upgrade = data.get("auto_upgrade", auto_upgrade)
	enable_infinite_levels = data.get("enable_infinite_levels", enable_infinite_levels)

	# Restore pattern & scaling settings
	infinite_xp_pattern = data.get("infinite_xp_pattern", infinite_xp_pattern)
	infinite_material_pattern = data.get("infinite_material_pattern", infinite_material_pattern)
	infinite_modifier_pattern = data.get("infinite_modifier_pattern", infinite_modifier_pattern)

	infinite_xp_multiplier = data.get("infinite_xp_multiplier", infinite_xp_multiplier)
	infinite_material_multiplier = data.get("infinite_material_multiplier", infinite_material_multiplier)
	infinite_modifier_multiplier = data.get("infinite_modifier_multiplier", infinite_modifier_multiplier)

	infinite_xp_exponent = data.get("infinite_xp_exponent", infinite_xp_exponent)
	infinite_material_exponent = data.get("infinite_material_exponent", infinite_material_exponent)
	infinite_modifier_exponent = data.get("infinite_modifier_exponent", infinite_modifier_exponent)

	infinite_xp_formula = data.get("infinite_xp_formula", infinite_xp_formula)
	infinite_material_formula = data.get("infinite_material_formula", infinite_material_formula)
	infinite_modifier_formula = data.get("infinite_modifier_formula", infinite_modifier_formula)

	consume_materials_on_upgrade = data.get("consume_materials_on_upgrade", consume_materials_on_upgrade)

	current_xp = data.get("current_xp", 0.0)
	current_level = data.get("current_level", 0)

	# Restore serialized level configs
	level_configs.clear()
	var levels_data: Array = data.get("level_configs", [])
	for cfg_data in levels_data:
		var cfg := _instantiate_class("UpgradeLevelConfig")
		if cfg and cfg.has_method("from_dict"):
			cfg.from_dict(cfg_data)
		level_configs.append(cfg)

	# Restore current modifier (if any)
	var current_modifier_data = data.get("current_modifier")
	if current_modifier_data:
		var class_type = current_modifier_data.get("class_type", "StatModifierSet")
		_current_modifier = _instantiate_class(class_type)
		if _current_modifier and _current_modifier.has_method("from_dict"):
			_current_modifier.from_dict(current_modifier_data.get("data", {}))

	return true


## Instantiates a class from its global class name.
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
	if class_type == "StatModifierSet":
		return StatModifierSet.new()
	else:
		push_warning("Unknown class type: %s, defaulting to StatModifierSet." % class_type)
		return StatModifierSet.new()
