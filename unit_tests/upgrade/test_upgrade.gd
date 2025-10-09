extends GutTest

var mock_stat_owner
var mock_inventory
var upgrade: Upgrade

const BASE_HEALTH := 100.0
const BASE_MANA := 50.0
const BASE_STRENGTH := 10.0
const BASE_DEFENSE := 5.0
const BASE_SPEED := 7.0
const BASE_INTELLIGENCE := 8.0

class MockInventory:
	var return_val = true
	var consumed = false
	var returned = false
	func consume_materials(_materials: Dictionary[StringName, int]) -> bool:
		consumed = true
		return true
	
	func has_materials(_material: Dictionary[StringName, int]) -> bool:
		return return_val

	func store_materials(_materials: Dictionary) -> void:
		returned = true

class TestCharacter extends Node:
	var stats := {}
	var buff_manager: BuffManager
	
	func _init() -> void:
		# Create common RPG stats
		stats["health"] = Stat.new()
		stats["health"].base_value = BASE_HEALTH
		stats["health"].max_value = BASE_HEALTH		

		stats["strength"] = Stat.new()
		stats["strength"].base_value = BASE_STRENGTH
		
		stats["defense"] = Stat.new()
		stats["defense"].base_value = BASE_DEFENSE
		
		stats["speed"] = Stat.new()
		stats["speed"].base_value = BASE_SPEED
		
		stats["intelligence"] = Stat.new()
		stats["intelligence"].base_value = BASE_INTELLIGENCE
		
		# Initialize buff manager
		buff_manager = BuffManager.new()
		add_child(buff_manager)
		buff_manager._parent = self
	
	func get_stat(stat_name: String) -> Stat:
		return stats.get(stat_name)
		
func before_each():
	mock_stat_owner = autofree(TestCharacter.new())
	mock_inventory = autofree(MockInventory.new())
	upgrade = Upgrade.new()
	
	# Define a simple system with 3 levels
	upgrade.auto_upgrade = false
	
	# Fix type mismatch with proper array typing
	var step_levels: Array[int] = [2] # Level Century 2 is a step level
	upgrade.step_levels = step_levels
	
	# Create level configs with proper StatModifierSet
	var level_1 = UpgradeLevelConfig.new()
	level_1.xp_required = 100
	level_1.modifiers = create_modifier_set("level_1_mods", {"strength": 5})
	var dict1: Dictionary[StringName, int] = {"iron": 10}
	level_1.required_materials = dict1
	
	var level_2 = UpgradeLevelConfig.new()
	level_2.xp_required = 250
	var dict2: Dictionary[StringName, int] = {"iron": 20, "gold": 5}
	level_2.modifiers = create_modifier_set("level_2_mods", {"strength": 10, "defense": 5})
	level_2.required_materials = dict2
	
	var level_3 = UpgradeLevelConfig.new()
	level_3.xp_required = 500
	level_3.modifiers = create_modifier_set("level_3_mods", {"strength": 15, "defense": 10, "speed": 5})
	var dict3: Dictionary[StringName, int] = {"iron": 30, "gold": 10, "diamond": 2}
	level_3.required_materials = dict3
	
	var level_configs: Array[UpgradeLevelConfig] = [level_1, level_2, level_3]
	upgrade.level_configs = level_configs
	
	# Initialize upgrade
	upgrade.init_upgrade(mock_stat_owner, mock_inventory)

# Helper function to create a StatModifierSet
func create_modifier_set(_name: String, stat_values: Dictionary) -> StatModifierSet:
	var mod_set := StatModifierSet.new(_name, false, "upgrade")
	
	for stat_name in stat_values:
		var stat_mod: StatModifier  = StatModifier.new()
		stat_mod._stat_name = stat_name
		stat_mod._value = stat_values[stat_name]
		stat_mod._type = StatModifier.StatModifierType.FLAT
		mod_set.add_modifier(stat_mod)
		
	return mod_set

func test_initial_state():
	assert_eq(upgrade.current_level, 0, "Initial level should be 0")
	assert_eq(upgrade.current_xp, 0, "Initial XP should be 0")
	
func test_add_xp_without_leveling():
	upgrade.add_xp(50)
	assert_eq(upgrade.current_xp, 50, "XP should be added correctly")
	assert_eq(upgrade.current_level, 0, "Level should not increase")
	
func test_get_current_xp_required():
	assert_eq(upgrade.get_current_xp_required(), 100, "XP required for level 1 should be 100")
	
func test_manual_upgrade_with_sufficient_xp():
	# Add enough XP for level 1
	upgrade.add_xp(100)
	assert_eq(upgrade.current_xp, 100, "XP should be added correctly")
	
	# Perform the upgrade
	watch_signals(upgrade)
	upgrade.do_upgrade()
	
	assert_eq(upgrade.current_level, 1, "Level should increase to 1")
	assert_eq(upgrade.current_xp, 0, "XP should reset to 0")
	assert_signal_emitted(upgrade, "upgrade_applied")
	assert_true(mock_inventory.consumed, "consume_materials")
	
func test_auto_upgrade():
	upgrade.auto_upgrade = true
	
	# Add enough XP for level 1
	watch_signals(upgrade)
	upgrade.add_xp(100)
	
	assert_eq(upgrade.current_level, 1, "Level should auto-upgrade to 1")
	assert_signal_emitted(upgrade, "upgrade_applied")
	
func test_insufficient_materials():
	mock_inventory.return_val = false
	
	# Add enough XP for level 1
	upgrade.add_xp(100)
	
	# Try to upgrade
	var can_upgrade = upgrade.can_upgrade()
	assert_false(can_upgrade, "Should not be able to upgrade without materials")

func test_step_level_reached():
	upgrade.auto_upgrade = true
	watch_signals(upgrade)
	
	# Add enough XP to reach level 2 (step level)
	upgrade.add_xp(100) # Level 1
	upgrade.add_xp(250) # Level 2
	
	assert_eq(upgrade.current_level, 2, "Level should be 2")
	assert_signal_emitted(upgrade, "step_reached")
	assert_signal_emit_count(upgrade, "upgrade_applied", 2)
	
func test_max_level_reached():
	upgrade.auto_upgrade = true
	watch_signals(upgrade)
	
	# Add enough XP to reach max level
	upgrade.add_xp(100) # Level 1
	upgrade.add_xp(250) # Level 2
	upgrade.add_xp(500) # Level 3
	
	assert_eq(upgrade.current_level, 3, "Level should be 3")
	assert_signal_emitted(upgrade, "max_level_reached")
	
	# Add more XP
	upgrade.add_xp(100)
	assert_eq(upgrade.current_level, 3, "Level should not exceed max")
	
func test_remove_current_upgrade():
	upgrade.auto_upgrade = true
	upgrade.add_xp(100) # Reach level 1
	
	watch_signals(upgrade)
	upgrade.remove_current_upgrade()
	
	assert_signal_emitted(upgrade, "upgrade_removed")
	
func test_reset_track():
	upgrade.auto_upgrade = true
	upgrade.add_xp(100) # Reach level 1
	
	watch_signals(upgrade)
	upgrade.reset_upgrades()
	
	assert_eq(upgrade.current_level, 0, "Level should reset to 0")
	assert_eq(upgrade.current_xp, 0, "XP should reset to 0")
	assert_signal_emitted(upgrade, "upgrade_removed")
	
func test_preview_functionality():
	# Test has_preview when not at max level
	assert_true(upgrade.has_preview(), "Should have preview at level 0")
	
	# Since we're now using StatModifierSet, we need to adjust how we verify preview data
	var preview_mod_set = upgrade.get_preview_modifier_set()
	assert_not_null(preview_mod_set, "Preview modifier set should not be null")
	
	# Find strength modifier in set
	var strength_mod = preview_mod_set.find_mod_for_stat("strength")
	assert_not_null(strength_mod, "Should have strength modifier")
	assert_eq(strength_mod._value, 5.0, "Preview should show level 1 strength bonus")
	
	# Test simulate_next_effect
	var simulated_stats = upgrade.simulate_next_effect()
	assert_not_null(simulated_stats, "Should return simulated stats")
	
	# Reach max level and test preview again
	upgrade.auto_upgrade = true
	upgrade.add_xp(100) # Level 1
	upgrade.add_xp(250) # Level 2
	upgrade.add_xp(500) # Level 3
	
	assert_false(upgrade.has_preview(), "Should not have preview at max level")

func test_create_config():
	var config = UpgradeLevelConfig.new()
	config.xp_required = 200
	
	# Create a proper StatModifierSet
	var mod_set = StatModifierSet.new("test_mods", false, "upgrade")
	
	var strength_mod = StatModifier.new()
	strength_mod._stat_name = "strength"
	strength_mod._value = 10.0
	strength_mod._type = StatModifier.StatModifierType.FLAT
	mod_set.add_modifier(strength_mod)
	
	var defense_mod = StatModifier.new()
	defense_mod._stat_name = "defense"
	defense_mod._value = 5.0
	defense_mod._type = StatModifier.StatModifierType.FLAT
	mod_set.add_modifier(defense_mod)
	
	config.modifiers = mod_set
	
	# Required materials as dictionary
	var materials: Dictionary[StringName, int] = {"iron": 20, "gold": 5}
	config.required_materials = materials
	
	assert_eq(config.xp_required, 200, "XP required should be 200")
	
	# Check modifiers using StatModifierSet methods
	var strength = config.modifiers.find_mod_for_stat("strength")
	var defense = config.modifiers.find_mod_for_stat("defense")
	
	assert_not_null(strength, "Strength modifier should exist")
	assert_not_null(defense, "Defense modifier should exist")
	assert_eq(strength._value, 10.0, "Strength modifier should be 10")
	assert_eq(defense._value, 5.0, "Defense modifier should be 5")
	
	assert_eq(config.required_materials["iron"], 20, "Iron requirement should be 20")
	assert_eq(config.required_materials["gold"], 5, "Gold requirement should be 5")


func test_refund():
	upgrade.auto_upgrade = true
	
	# Test 1: Partial refund
	var initial_xp = 50
	upgrade.add_xp(initial_xp)
	
	var total_refund = upgrade.get_total_refund()
	assert_true(total_refund.xp > 0, "Should have some XP to refund")
	
	mock_inventory.returned = false
	watch_signals(upgrade)
	var xp_refunded = upgrade.do_refund()
	
	assert_eq(upgrade.current_xp, 0, "XP should be refunded")
	assert_eq(xp_refunded, total_refund.xp, "XP refunded should be correct")
	assert_signal_emitted(upgrade, "refund_applied", {"amount": total_refund.xp})
	assert_false(mock_inventory.returned, "Inventory items shouldnt have been returned")
	
	# Test 2: Full level refund
	var full_upgrade = 850
	upgrade.add_xp(full_upgrade)
	
	total_refund = upgrade.get_total_refund()
	mock_inventory.returned = false
	
	watch_signals(upgrade)
	upgrade.do_refund()
	
	assert_eq(total_refund.materials["iron"], 60, "iron should have been properly refunded")
	assert_eq(total_refund.materials["diamond"], 2, "diamond should have been properly refunded")
	assert_eq(total_refund.xp, 850, "xp should have been properly refunded")
	assert_eq(upgrade.current_xp, 0, "XP should be refunded for full level")
	assert_signal_emitted(upgrade, "refund_applied", {"amount": total_refund.xp})
	assert_true(mock_inventory.returned, "All materials should have been returned")

func test_enable_infinite_levels():
	upgrade.enable_infinite_levels = true
	assert_true(upgrade.enable_infinite_levels, "Infinite levels should be enabled")
	
	# Check that we don't consider max level when infinite is enabled
	upgrade.current_level = upgrade.level_configs.size()
	assert_false(upgrade.is_max_level(), "With infinite levels, there should be no max level")
	
	upgrade.enable_infinite_levels = false
	assert_true(upgrade.is_max_level(), "With infinite levels disabled, we should be at max level")

func test_extrapolate_linear_growth():
	# Setup linear growth pattern
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.LINEAR
	upgrade.infinite_material_pattern = Upgrade.GrowthPattern.LINEAR
	upgrade.infinite_modifier_pattern = Upgrade.GrowthPattern.LINEAR
	upgrade.infinite_xp_multiplier = 100
	upgrade.infinite_material_multiplier = 10
	upgrade.infinite_modifier_multiplier = 5
	
	# Set level to max of defined configs
	upgrade.set_level(upgrade.level_configs.size() + 1)
	
	# Get the extrapolated config for next level
	var extrapolated_config = upgrade._generate_extrapolated_config(upgrade.level_configs.size() + 1)
	
	# Test XP calculation
	var last_defined_xp = upgrade.level_configs[-1].xp_required
	var expected_xp = last_defined_xp + upgrade.infinite_xp_multiplier * 1
	assert_eq(extrapolated_config.xp_required, int(expected_xp), 
		"Linear XP should be base + multiplier * (level_diff)")
	
	# Test material calculation
	var last_iron = upgrade.level_configs[-1].required_materials["iron"]
	var expected_iron = last_iron + upgrade.infinite_material_multiplier * 1
	assert_eq(extrapolated_config.required_materials["iron"], int(expected_iron), 
		"Linear material amount should be base + multiplier * (level_diff)")
	
	# Test modifier calculation
	var strength_mod = extrapolated_config.modifiers._modifiers[0]
	var last_strength = upgrade.level_configs[-1].modifiers._modifiers[0]._value
	var expected_strength = last_strength + upgrade.infinite_modifier_multiplier * 1
	assert_eq(strength_mod._value, expected_strength, 
		"Linear modifier value should be base + multiplier * (level_diff)")

func test_extrapolate_exponential_growth():
	# Setup exponential growth pattern
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.EXPONENTIAL
	upgrade.infinite_material_pattern = Upgrade.GrowthPattern.EXPONENTIAL
	upgrade.infinite_modifier_pattern = Upgrade.GrowthPattern.EXPONENTIAL
	upgrade.infinite_xp_multiplier = 1.5
	upgrade.infinite_material_multiplier = 1.2
	upgrade.infinite_modifier_multiplier = 1.1
	
	# Set level to max of defined configs
	upgrade.set_level(upgrade.level_configs.size())
	
	# Get configs for next two levels to check progression
	var next_level = upgrade.level_configs.size() + 1
	var extrapolated_config1 = upgrade._generate_extrapolated_config(next_level)
	var extrapolated_config2 = upgrade._generate_extrapolated_config(next_level + 1)
	
	# Test XP calculation
	var last_defined_xp = upgrade.level_configs[-1].xp_required
	var expected_xp1 = last_defined_xp * pow(upgrade.infinite_xp_multiplier, 1)
	var expected_xp2 = last_defined_xp * pow(upgrade.infinite_xp_multiplier, 2)
	
	assert_eq(extrapolated_config1.xp_required, int(expected_xp1), 
		"Exponential XP should be base * pow(multiplier, level_diff)")
	assert_eq(extrapolated_config2.xp_required, int(expected_xp2), 
		"Exponential XP should continue growing")
	
	# Check that XP is exponentially increasing
	assert_gt(extrapolated_config2.xp_required - extrapolated_config1.xp_required,
		extrapolated_config1.xp_required - last_defined_xp,
		"Exponential growth should have increasing differences")

func test_extrapolate_polynomial_growth():
	# Setup polynomial growth pattern
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.POLYNOMIAL
	upgrade.infinite_xp_exponent = 2.0
	
	# Set level to max of defined configs
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	# Get the extrapolated config
	var next_level = last_level + 1
	var extrapolated_config = upgrade._generate_extrapolated_config(next_level)
	
	# Test XP calculation
	var last_defined_xp = upgrade.level_configs[-1].xp_required
	var expected_xp = last_defined_xp * pow(float(next_level) / last_level, upgrade.infinite_xp_exponent)
	
	assert_eq(extrapolated_config.xp_required, int(expected_xp), 
		"Polynomial XP should be base * pow(level_ratio, exponent)")

func test_extrapolate_logarithmic_growth():
	# Setup logarithmic growth pattern
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.LOGARITHMIC
	upgrade.infinite_xp_multiplier = 2.0
	
	# Set level to max of defined configs
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	# Get configs for levels further out to check slowing growth
	var next_level = last_level + 1
	var far_level = last_level + 10
	var extrapolated_config1 = upgrade._generate_extrapolated_config(next_level)
	var extrapolated_config2 = upgrade._generate_extrapolated_config(next_level + 1)
	var extrapolated_config_far = upgrade._generate_extrapolated_config(far_level)
	
	# Test XP calculation
	var last_defined_xp = upgrade.level_configs[-1].xp_required
	var expected_xp = last_defined_xp * (1.0 + log(float(next_level) / last_level) * upgrade.infinite_xp_multiplier)
	
	assert_eq(extrapolated_config1.xp_required, int(expected_xp), 
		"Logarithmic XP should be base * (1 + log(level_ratio) * multiplier)")
	
	# Check that growth is slowing down
	var diff1 = extrapolated_config2.xp_required - extrapolated_config1.xp_required
	var diff_far = (extrapolated_config_far.xp_required - extrapolated_config1.xp_required) / 9.0  # Average growth per level
	
	assert_gt(diff1, diff_far, "Logarithmic growth should slow down over time")

func test_extrapolate_custom_formula():
	# Setup custom formula growth
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.CUSTOM
	upgrade.infinite_xp_formula = "base + (level * level) - (last_level * last_level)"
	
	# Set level to max of defined configs
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	# Get the extrapolated config
	var next_level = last_level + 1
	var extrapolated_config = upgrade._generate_extrapolated_config(next_level)
	
	# Test XP calculation
	var last_defined_xp = upgrade.level_configs[-1].xp_required
	var expected_xp = last_defined_xp + (next_level * next_level) - (last_level * last_level)
	
	assert_eq(extrapolated_config.xp_required, int(expected_xp), 
		"Custom formula XP should be calculated correctly")

func test_custom_formula_with_error():
	# Setup invalid custom formula
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.CUSTOM
	upgrade.infinite_xp_formula = "this is not a valid formula!"
	
	# Set level to max of defined configs
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	# Get the extrapolated config
	var next_level = last_level + 1
	var extrapolated_config = upgrade._generate_extrapolated_config(next_level)
	
	# Test that we fall back to exponential growth
	var last_defined_xp = upgrade.level_configs[-1].xp_required
	var fallback_xp = last_defined_xp * pow(1.15, next_level - last_level)
	
	assert_eq(extrapolated_config.xp_required, int(fallback_xp), 
		"Invalid custom formula should fall back to exponential growth")

func test_upgrade_past_defined_levels():
	# Setup
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.EXPONENTIAL
	upgrade.infinite_xp_multiplier = 1.5
	
	## Set to just below last level
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level - 1)
	
	## Add enough XP to level up twice
	var xp_for_last_defined = upgrade.level_configs[last_level - 1].xp_required
	var extrapolated_next = upgrade._generate_extrapolated_config(last_level + 1)
	var total_needed = xp_for_last_defined + extrapolated_next.xp_required
	
	## Simulate auto-upgrade
	upgrade.auto_upgrade = true
	
	## Add slightly more than needed for two levels
	upgrade.add_xp(total_needed + 10)
	
	## We should now be at level+1 (first infinite level)
	assert_eq(upgrade.current_level, last_level + 1, 
		"Should level up past defined levels with infinite enabled")
	
	## XP should be the remainder
	assert_eq(upgrade.current_xp, 10, "Remaining XP should be correct")

func test_infinite_leveling_disabled():
	## Setup - infinite disabled
	upgrade.enable_infinite_levels = false
	
	## Set to last level
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	## Add some XP
	upgrade.add_xp(1000, true)
	
	## Level shouldn't change
	assert_eq(upgrade.current_level, last_level, 
		"Should not level up past max when infinite levels disabled")
	
	## XP should still be added
	assert_eq(upgrade.current_xp, 1000, "XP should still accumulate")

func test_can_upgrade_with_infinite():
	## Setup
	upgrade.enable_infinite_levels = true
	upgrade.auto_upgrade = false  ## Manual upgrades for testing
	
	## Set to last level 
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	## First we shouldn't be able to upgrade (not enough XP)
	assert_false(upgrade.can_upgrade(), "Should not be able to upgrade without XP")
	
	## Add exactly enough XP
	var extrapolated = upgrade._generate_extrapolated_config(last_level + 1)
	upgrade.current_xp = extrapolated.xp_required
	
	## Now we should be able to upgrade
	assert_true(upgrade.can_upgrade(), "Should be able to upgrade with enough XP")
	
	## Do the upgrade
	assert_true(upgrade.do_upgrade(), "Upgrade should succeed")
	assert_eq(upgrade.current_level, last_level + 1, "Level should increment")
	assert_eq(upgrade.current_xp, 0, "XP should be reset")

func test_get_current_xp_required_with_infinite():
	## Setup
	upgrade.enable_infinite_levels = true
	
	## Set to last level
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	## Get required XP for next level
	var extrapolated = upgrade._generate_extrapolated_config(last_level + 1)
	var expected_required = extrapolated.xp_required
	
	## Check if get_current_xp_required matches
	assert_eq(upgrade.get_current_xp_required(), expected_required, 
		"get_current_xp_required should return extrapolated XP amount")
	
	## Add some XP
	var partial_xp = expected_required / 2
	upgrade.current_xp = partial_xp
	
	## Check remaining required
	assert_eq(upgrade.get_current_xp_required(), expected_required - partial_xp, 
		"get_current_xp_required should subtract current XP")

func test_serialize_deserialize_with_infinite():
	## Setup original object
	upgrade.enable_infinite_levels = true
	upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.EXPONENTIAL
	upgrade.infinite_xp_multiplier = 1.75
	upgrade.current_level = 2
	upgrade.current_xp = 123
	
	## Serialize
	var data = upgrade.to_dict()
	
	## Create new object and deserialize
	var new_upgrade = Upgrade.new()
	new_upgrade.level_configs = upgrade.level_configs  ## Need to copy configs
	new_upgrade.init_upgrade(mock_stat_owner, mock_inventory)
	new_upgrade.from_dict(data)
	
	## Verify serialized properties
	assert_eq(new_upgrade.enable_infinite_levels, true, "enable_infinite_levels should serialize")
	assert_eq(new_upgrade.infinite_xp_pattern, Upgrade.GrowthPattern.EXPONENTIAL, "infinite_xp_pattern should serialize")
	assert_eq(new_upgrade.infinite_xp_multiplier, 1.75, "infinite_xp_multiplier should serialize")
	assert_eq(new_upgrade.current_level, 2, "current_level should serialize")
	assert_eq(new_upgrade.current_xp, 123, "current_xp should serialize")

func test_has_preview_with_infinite():
	## Setup
	upgrade.enable_infinite_levels = true
	
	## Set to last level
	var last_level = upgrade.level_configs.size()
	upgrade.set_level(last_level)
	
	## Preview should be available if the last config has modifiers
	var has_modifiers = upgrade.level_configs[-1].modifiers != null
	assert_eq(upgrade.has_preview(), has_modifiers, 
		"has_preview with infinite levels should check if last config has modifiers")
	
	## Get preview modifier set
	if has_modifiers:
		var preview_set = upgrade.get_preview_modifier_set()
		assert_not_null(preview_set, "Preview modifier set should not be null")
		
		## The preview should be an extrapolated set
		var extrapolated = upgrade._generate_extrapolated_config(last_level + 1)
		
		## First modifier in both sets should have same stat name
		assert_eq(preview_set._modifiers[0]._stat_name, 
				  extrapolated.modifiers._modifiers[0]._stat_name,
				  "Preview modifiers should match extrapolated ones")

func test_upgrade_without_consuming_materials():
	# Add enough XP for level 1
	upgrade.add_xp(100)
	
	# Perform upgrade with ignore_cost flag to skip material consumption
	mock_inventory.consumed = false
	watch_signals(upgrade)
	var result = upgrade.do_upgrade(true) # ignore_cost = true
	
	assert_true(result, "Upgrade should succeed even without consuming materials")
	assert_eq(upgrade.current_level, 1, "Level should increase to 1")
	assert_false(mock_inventory.consumed, "Materials should NOT be consumed")
	assert_signal_emitted(upgrade, "upgrade_applied")
