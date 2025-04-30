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
	can_upgrade
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
	
	# Test get_temp_applied_stats
	var temp_stats = upgrade.get_temp_applied_stats()
	assert_not_null(temp_stats, "Should return temporary stats")
	
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
