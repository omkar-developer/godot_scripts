extends GutTest

## Helper function to create a Stat instance for testing
func _create_test_stat(base_value: float = 100.0, min_value: float = 0.0, max_value: float = 200.0) -> Stat:
	var stat = Stat.new()
	stat.base_value = base_value
	stat.min_value = min_value
	stat.max_value = max_value
	return stat

## Helper function to create a parent object with multiple stats
func _create_parent_with_stats(stats_dict: Dictionary) -> RefCounted:
	# Create a new RefCounted object
	var parent = RefCounted.new()

	# Dynamically create a script with a `get_stat` method
	var script = GDScript.new()
	script.source_code = """
extends RefCounted

# Dictionary of stats to return
var _stats = {}

# Constructor to initialize the stats
func initialize(stats_dict: Dictionary):
	_stats = stats_dict

# Method to fetch the stat by name
func get_stat(stat_name: String) -> Stat:
	if _stats.has(stat_name):
		return _stats[stat_name]
	return null
"""
	script.reload()  # Reload the script to compile it

	# Attach the script to the parent object
	parent.set_script(script)

	# Initialize the script with the provided stats
	parent.initialize(stats_dict)

	return parent

## Helper function to create a simple test setup with target and reference stats
func _create_test_setup() -> Dictionary:
	var health_stat = _create_test_stat(100.0, 0.0, 200.0)
	var strength_stat = _create_test_stat(50.0, 10.0, 100.0)
	
	var stats_dict = {
		"health": health_stat,
		"strength": strength_stat
	}
	
	var parent = _create_parent_with_stats(stats_dict)
	
	return {
		"parent": parent,
		"health_stat": health_stat,
		"strength_stat": strength_stat
	}

#region Basic Initialization Tests

func test_basic_initialization():
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	
	assert_eq(composite_mod.get_stat_name(), "health", "Target stat name should match")
	assert_eq(composite_mod.get_type(), StatModifier.StatModifierType.FLAT, "Modifier type should match")
	assert_eq(composite_mod.get_value(), 2.0, "Multiplier value should match")
	assert_eq(composite_mod._ref_stat_name, "strength", "Reference stat name should match")
	assert_eq(composite_mod._ref_stat_type, StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY, 
		"Reference stat type should match")

func test_initialization_with_parent():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	
	var result = composite_mod.init_stat(setup.parent)
	
	assert_true(result, "Initialization with parent should succeed")
	assert_true(composite_mod.is_valid(), "Modifier should be valid after initialization")
	assert_not_null(composite_mod._ref_stat, "Reference stat should be set")
	assert_eq(composite_mod._ref_stat, setup.strength_stat, "Reference stat should point to the correct stat")

func test_initialization_with_invalid_parent():
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	
	var result = composite_mod.init_stat(null)
	
	assert_false(result, "Initialization with null parent should fail")
	assert_false(composite_mod.is_valid(), "Modifier should be invalid after failed initialization")

#endregion

#region Reference Value Calculation Tests

func test_base_value_multiply():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod.init_stat(setup.parent)
	
	# Strength base value (50) * modifier value (2.0) = 100
	assert_eq(composite_mod._ref_value(), 100.0, "BASE_VALUE_MULTIPLY should multiply base value by modifier value")

func test_value_multiply():
	var setup = _create_test_setup()
	setup.strength_stat.add_flat(10.0)  # Now strength value is 60
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.VALUE_MULTIPLY
	composite_mod.init_stat(setup.parent)
	
	# Strength current value (60) * modifier value (2.0) = 120
	assert_eq(composite_mod._ref_value(), 120.0, "VALUE_MULTIPLY should multiply current value by modifier value")

func test_max_value_multiply():
	var setup = _create_test_setup()
	setup.strength_stat.add_max_flat(20.0)  # Now strength max is 120
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.MAX_VALUE_MULTIPLY
	composite_mod.init_stat(setup.parent)
	
	# Strength max value (120) * modifier value (2.0) = 240
	assert_eq(composite_mod._ref_value(), 240.0, "MAX_VALUE_MULTIPLY should multiply max value by modifier value")

func test_percent_calculations():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 50.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.PERCENT_BASE_VALUE
	composite_mod.init_stat(setup.parent)
	
	# 50% of strength base value (50) = 25
	assert_eq(composite_mod._ref_value(), 25.0, "PERCENT_BASE_VALUE should calculate percentage of base value")
	
	# Change to PERCENT_VALUE
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.PERCENT_VALUE
	# 50% of strength current value (50) = 25
	assert_eq(composite_mod._ref_value(), 25.0, "PERCENT_VALUE should calculate percentage of current value")
	
	# Change to PERCENT_MAX_VALUE
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.PERCENT_MAX_VALUE
	# 50% of strength max value (100) = 50
	assert_eq(composite_mod._ref_value(), 50.0, "PERCENT_MAX_VALUE should calculate percentage of max value")

#endregion

#region Expression Tests

func test_simple_expression():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 1.0)
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.EXPRESSION
	composite_mod._math_expression = "strength * 2"
	composite_mod.init_stat(setup.parent)
	
	# Expression: strength value (50) * 2 = 100, then multiplied by modifier value (1.0) = 100
	assert_eq(composite_mod._ref_value(), 100.0, "Simple expression should be evaluated correctly")

func test_complex_expression():
	var setup = _create_test_setup()
	var intelligence_stat = _create_test_stat(30.0, 10.0, 50.0)
	setup.parent.initialize({
		"health": setup.health_stat,
		"strength": setup.strength_stat,
		"intelligence": intelligence_stat
	})
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 1.0)
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.EXPRESSION
	composite_mod._math_expression = "strength:value * 0.5 + intelligence:value * 1.5"
	composite_mod.init_stat(setup.parent)
	
	# Expression: (strength (50) * 0.5) + (intelligence (30) * 1.5) = 25 + 45 = 70
	# Then multiplied by modifier value (1.0) = 70
	assert_eq(composite_mod._ref_value(), 70.0, "Complex expression should be evaluated correctly")

func test_invalid_expression():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 1.0)
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.EXPRESSION
	composite_mod._math_expression = "invalid_stat:value * 2"
	composite_mod.init_stat(setup.parent)
	
	# Invalid expression should return 0
	assert_eq(composite_mod._ref_value(), 0.0, "Invalid expression should return 0")

#endregion

#region Dynamic Update Tests

func test_static_update_mode():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._snapshot_stats = true
	composite_mod.init_stat(setup.parent)
	
	# Apply the modifier
	composite_mod.apply()
	
	# Initial health should be 100 + (50 * 2) = 200
	assert_eq(setup.health_stat.get_value(), 200.0, "Initial health should be modified correctly")
	
	# Change the reference stat
	setup.strength_stat.base_value = 60.0
	
	# Health should still be 200 since we're in static mode
	assert_eq(setup.health_stat.get_value(), 200.0, "Health should not change when ref stat changes in static mode")

func test_dynamic_update_mode():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._snapshot_stats = false
	composite_mod.init_stat(setup.parent)
	
	# Apply the modifier
	composite_mod.apply()
	
	# Initial health should be 100 + (50 * 2) = 200
	assert_eq(setup.health_stat.get_value(), 200.0, "Initial health should be modified correctly")
	
	watch_signals(setup.strength_stat)
	# Change the reference stat and emit signal
	setup.strength_stat.base_value = 60.0
	
	assert_signal_emitted(setup.strength_stat, "value_changed")
	
	# Health should update to 100 + (60 * 2) = 220
	assert_eq(setup.health_stat.get_value(), 220.0, "Health should update when ref stat changes in dynamic mode")

#endregion

#region Apply and Remove Tests

func test_apply_modifier():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod.init_stat(setup.parent)
	
	# Apply the modifier
	var result = composite_mod.apply()
	
	# Apply should return the amount applied (50 * 2 = 100)
	assert_eq(result, 100.0, "Apply should return the amount applied")
	
	# Health should be 100 + 100 = 200
	assert_eq(setup.health_stat.get_value(), 200.0, "Health should be modified correctly")
	
	# Modifier should be marked as applied
	assert_true(composite_mod.is_applied(), "Modifier should be marked as applied")

func test_apply_only_once():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._apply_only_once = true
	composite_mod.init_stat(setup.parent)
	
	# Apply the modifier
	composite_mod.apply()
	
	# Health should be 100 + 100 = 200
	assert_eq(setup.health_stat.get_value(), 200.0, "Health should be modified correctly")
	
	# Try to apply again
	var result = composite_mod.apply()
	
	# Apply should return 0 since it's already applied
	assert_eq(result, 0.0, "Second apply should return 0 when apply_only_once is true")
	
	# Health should still be 200
	assert_eq(setup.health_stat.get_value(), 200.0, "Health should not be modified again")

func test_remove_modifier():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod.init_stat(setup.parent)
	
	# Apply the modifier
	composite_mod.apply()
	
	# Health should be 100 + 100 = 200
	assert_eq(setup.health_stat.get_value(), 200.0, "Health should be modified correctly")
	
	# Remove the modifier
	var remove_result = composite_mod.remove()
	
	# Remove should return the amount removed (negative)
	assert_eq(remove_result, -100.0, "Remove should return the negative of the amount removed")
	
	# Health should be back to 100
	assert_eq(setup.health_stat.get_value(), 100.0, "Health should be restored to original value")
	
	# Modifier should be marked as not applied
	assert_false(composite_mod.is_applied(), "Modifier should be marked as not applied")

#endregion

#region Simulation Tests

func test_simulate_effect():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod.init_stat(setup.parent)
	
	# Simulate the effect without applying
	var effect = composite_mod.simulate_effect()
	
	# Effect should contain the predicted changes
	assert_has(effect, "value_diff", "Simulation should contain value_diff")
	assert_eq(effect.value_diff, 100.0, "Simulated value difference should be 100")
	
	# Health should not be modified
	assert_eq(setup.health_stat.get_value(), 100.0, "Health should not be modified by simulation")

#endregion

#region Serialization Tests

func test_to_dict():
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._snapshot_stats = false
	composite_mod._math_expression = "test_expression"
	
	var dict = composite_mod.to_dict()
	
	assert_eq(dict.stat_name, "health", "Dictionary should contain correct stat_name")
	assert_eq(dict.type, StatModifier.StatModifierType.FLAT, "Dictionary should contain correct type")
	assert_eq(dict.value, 2.0, "Dictionary should contain correct value")
	assert_eq(dict.ref_stat_name, "strength", "Dictionary should contain correct ref_stat_name")
	assert_eq(dict.ref_stat_type, StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY, 
		"Dictionary should contain correct ref_stat_type")
	assert_eq(dict.snapshot_stats, false, "Dictionary should contain correct snapshot_stats")
	assert_eq(dict.math_expression, "test_expression", "Dictionary should contain correct math_expression")
	assert_eq(dict.class, "StatModifierComposite", "Dictionary should contain correct class")

func test_from_dict():
	var dict = {
		"stat_name": "health",
		"type": StatModifier.StatModifierType.FLAT,
		"value": 2.0,
		"ref_stat_name": "strength",
		"ref_stat_type": StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY,
		"snapshot_stats": false,
		"math_expression": "test_expression",
		"is_applied": true,
		"apply_only_once": false
	}
	
	var composite_mod = StatModifierComposite.new()
	composite_mod.from_dict(dict)
	
	assert_eq(composite_mod.get_stat_name(), "health", "from_dict should set correct stat_name")
	assert_eq(composite_mod.get_type(), StatModifier.StatModifierType.FLAT, "from_dict should set correct type")
	assert_eq(composite_mod.get_value(), 2.0, "from_dict should set correct value")
	assert_eq(composite_mod._ref_stat_name, "strength", "from_dict should set correct ref_stat_name")
	assert_eq(composite_mod._ref_stat_type, StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY, 
		"from_dict should set correct ref_stat_type")
	assert_eq(composite_mod._snapshot_stats, false, "from_dict should set correct snapshot_stats")
	assert_eq(composite_mod._math_expression, "test_expression", "from_dict should set correct math_expression")
	assert_eq(composite_mod._is_applied, true, "from_dict should set correct is_applied")
	assert_eq(composite_mod._apply_only_once, true, "from_dict should set correct apply_only_once")

#endregion

#region Edge Cases Tests

func test_invalid_ref_stat():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "non_existent_stat"
	composite_mod.init_stat(setup.parent)
	
	# Modifier should not be valid
	assert_false(composite_mod.is_valid(), "Modifier with invalid ref stat should not be valid")
	
	# Apply should return 0
	var result = composite_mod.apply()
	assert_eq(result, 0.0, "Apply with invalid ref stat should return 0")

func test_is_equal():
	var mod1 = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	mod1._ref_stat_name = "strength"
	mod1._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	
	var mod2 = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	mod2._ref_stat_name = "strength"
	mod2._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	
	var mod3 = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 3.0)
	mod3._ref_stat_name = "strength"
	mod3._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	
	var mod4 = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	mod4._ref_stat_name = "intelligence"
	mod4._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	
	assert_true(mod1.is_equal(mod2), "Identical modifiers should be equal")
	assert_true(mod1.is_equal(mod3), "Modifiers with different values should be equal")
	assert_false(mod1.is_equal(mod4), "Modifiers with different ref stats should not be equal")

func test_uninit_stat():
	var setup = _create_test_setup()
	
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._snapshot_stats = false
	composite_mod.init_stat(setup.parent)
	
	# Apply the modifier
	composite_mod.apply()
	
	# Uninitialize the stat
	composite_mod.uninit_stat()
	
	# References should be cleared
	assert_null(composite_mod._ref_stat, "Reference stat should be cleared after uninit")
	assert_null(composite_mod._ref_stat_manager, "Reference stat manager should be cleared after uninit")
	assert_false(composite_mod.is_valid(), "Modifier should not be valid after uninit")

func test_null_reference_stat():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "non_existent_stat"
	
	var result = composite_mod.init_stat(setup.parent)
	
	assert_true(result, "Initialization should succeed even with invalid ref stat name")
	assert_false(composite_mod.is_valid(), "Modifier should be invalid with non-existent ref stat")
	assert_null(composite_mod._ref_stat, "Reference stat should be null")
	
	var apply_result = composite_mod.apply()
	assert_eq(apply_result, 0.0, "Apply should return 0 with invalid ref stat")

func test_diminishing_returns_calculation():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.PERCENT_NORMALIZED, 10.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.DIMINISHING_RETURNS
	
	composite_mod.init_stat(setup.parent)
	
	var initial_health = setup.health_stat.get_value()
	var change = composite_mod.apply()
	
	# Calculate diminishing returns: 1 - (1 / (1 + strength.value (50) * mod_value (10) * 0.01))
	# = 1 - (1 / (1 + 5)) = 1 - (1/6) = 1 - 0.16666... = ~0.833333...
	# As a percentage increase to health: ~83.33%
	var expected_change = initial_health * 0.833333
	assert_almost_eq(change, expected_change, 0.01, "Diminishing returns calculation should be correct")
#endregion
#region Connection Cleanup Tests

func test_uninit_stat_clears_connections():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._snapshot_stats = false  # Enable dynamic updates
	
	composite_mod.init_stat(setup.parent)
	
	# Ensure connections were made
	assert_true(setup.strength_stat.is_connected("value_changed", composite_mod._update_value), 
		"Dynamic connection to reference stat should be established")
	
	# Now uninitialize
	composite_mod.uninit_stat()
	
	# Check that connections were properly cleared
	assert_false(setup.strength_stat.is_connected("value_changed", composite_mod._update_value), 
		"Connection to reference stat should be cleared after uninit")
	assert_null(composite_mod._ref_stat, "Reference stat should be null after uninit")
	assert_null(composite_mod._ref_stat_manager, "Reference stat manager should be null after uninit")

func test_ref_stat_manager_connections_cleared():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.EXPRESSION
	composite_mod._math_expression = "strength:value + health:max"
	composite_mod._snapshot_stats = false  # Enable dynamic updates
	
	composite_mod.init_stat(setup.parent)
	
	# Ensure ref_stat_manager exists and has connections
	assert_not_null(composite_mod._ref_stat_manager, "RefStatManager should be created")
	assert_true(composite_mod._ref_stat_manager.is_connected("ref_stats_changed", composite_mod._update_value), 
		"RefStatManager should be connected to update_value")
	
	# Now uninitialize
	composite_mod.uninit_stat()
	
	# The manager should be cleared and null
	assert_null(composite_mod._ref_stat_manager, "RefStatManager should be null after uninit")

#endregion
#region Multiple Applications Tests

func test_multiple_applications_with_snapshots():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._snapshot_stats = true  # Enable snapshots
	
	composite_mod.init_stat(setup.parent)
	
	# First application
	var initial_health = setup.health_stat.get_value()
	var first_change = composite_mod.apply()
	
	# Calculate expected first change: strength.base_value (50) * mod_value (2.0) = 100
	assert_eq(first_change, 100.0, "First application should add strength.base_value * mod_value")
	assert_eq(setup.health_stat.get_value(), initial_health + 100.0, "Health should increase by 100")
	
	# Now modify the reference stat
	setup.strength_stat.base_value = 75.0
	
	# Apply again - with snapshots enabled, this should capture the new reference value
	var second_change = composite_mod.apply()
	
	# Calculate expected second change: strength.base_value (75) * mod_value (2.0) = 150
	assert_eq(second_change, 150.0, "Second application should add NEW strength.base_value * mod_value")
	assert_eq(setup.health_stat.get_value(), initial_health + 100.0 + 150.0, 
		"Health should increase by an additional 150")

func test_multiple_applications_without_snapshots():
	var setup = _create_test_setup()
	var composite_mod = StatModifierComposite.new("health", StatModifier.StatModifierType.FLAT, 2.0)
	composite_mod._ref_stat_name = "strength"
	composite_mod._ref_stat_type = StatModifierComposite.RefStatType.BASE_VALUE_MULTIPLY
	composite_mod._snapshot_stats = false  # Dynamic updates
	composite_mod._apply_only_once = false  # Allow multiple applications
	
	composite_mod.init_stat(setup.parent)
	
	# First application
	var initial_health = setup.health_stat.get_value()
	var first_change = composite_mod.apply()
	
	# Calculate expected first change: strength.base_value (50) * mod_value (2.0) = 100
	assert_eq(first_change, 100.0, "First application should add strength.base_value * mod_value")
	assert_eq(setup.health_stat.get_value(), initial_health + 100.0, "Health should increase by 100")
	
	# Modify the reference stat
	setup.strength_stat.base_value = 75.0
	
	# Call _update_value directly to simulate a signal from strength_stat
	composite_mod._update_value(75.0, setup.strength_stat.get_max(), 50.0, setup.strength_stat.get_max())
	
	# Check that the health stat was updated dynamically
	var expected_health = initial_health + 150.0  # Now using 75 * 2 = 150
	assert_eq(setup.health_stat.get_value(), expected_health, 
		"Health should update dynamically when reference stat changes")

#endregion
