extends GutTest

## Helper function to create a Stat instance for testing
func _create_test_stat(base_value: float = 100.0, min_value: float = 0.0, max_value: float = 200.0) -> Stat:
    var stat = Stat.new()
    stat.base_value = base_value
    stat.min_value = min_value
    stat.max_value = max_value
    return stat

## Helper function to create a parent object with a get_stat method
func _create_parent_with_stat(stat: Stat) -> RefCounted:
    # Create a new RefCounted object
    var parent = RefCounted.new()

    # Dynamically create a script with a `get_stat` method
    var script = GDScript.new()
    script.source_code = """
extends RefCounted

# The stat object to return
var _stat

# Constructor to initialize the stat
func initialize(stat):
    _stat = stat

# Method to fetch the stat by name
func get_stat(stat_name: String) -> Stat:
    return _stat
"""
    script.reload()  # Reload the script to compile it

    # Attach the script to the parent object
    parent.set_script(script)

    # Initialize the script with the provided stat
    parent.initialize(stat)

    return parent

## Basic Initialization Tests
func test_init_with_valid_values():
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    assert_eq(modifier.get_stat_name(), "Health", "Stat name should match")
    assert_eq(modifier.get_type(), StatModifier.StatModifierType.FLAT, "Modifier type should match")
    assert_eq(modifier.get_value(), 50.0, "Modifier value should match")

func test_init_with_invalid_values():
    var modifier = StatModifier.new("", StatModifier.StatModifierType.FLAT, -10.0)
    assert_eq(modifier.get_stat_name(), "", "Empty stat name should be allowed")
    assert_eq(modifier.get_value(), -10.0, "Negative values should be allowed")

## Stat Reference Tests
func test_init_stat_with_valid_parent():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    assert_true(modifier.init_stat(parent), "init_stat should succeed with valid parent")
    assert_true(modifier.is_valid(), "Modifier should be valid after init_stat")

func test_init_stat_with_invalid_parent():
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    assert_false(modifier.init_stat(null), "init_stat should fail with null parent")
    assert_false(modifier.is_valid(), "Modifier should not be valid after failed init_stat")

func test_uninit_stat():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier.init_stat(parent)
    modifier.uninit_stat()
    assert_false(modifier.is_valid(), "Modifier should not be valid after uninit_stat")

## Modifier Application Tests
func test_apply_flat_modifier():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier.init_stat(parent)
    var applied_change = modifier.apply()
    assert_eq(applied_change, 50.0, "Applied change should match the flat modifier value")
    assert_eq(stat.get_value(), 150.0, "Stat value should increase by the flat modifier")

func test_remove_flat_modifier():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier.init_stat(parent)
    modifier.apply()
    var removed_change = modifier.remove()
    assert_eq(removed_change, -50.0, "Removed change should match the flat modifier value")
    assert_eq(stat.get_value(), 100.0, "Stat value should return to original after removal")

func test_apply_only_once():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier._apply_only_once = true
    modifier.init_stat(parent)
    modifier.apply()
    var second_application = modifier.apply()
    assert_eq(second_application, 0.0, "Second application should do nothing for one-time modifiers")
    assert_eq(stat.get_value(), 150.0, "Stat value should not change after second application")

## Simulation Tests
func test_simulate_effect():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier.init_stat(parent)
    var simulation = modifier.simulate_effect()
    assert_eq(simulation["value_diff"], 50.0, "Simulated value difference should match the flat modifier")
    assert_eq(simulation["max_diff"], 0.0, "Simulated max difference should be zero for flat modifiers")
    assert_eq(stat.get_value(), 100.0, "Stat value should remain unchanged after simulation")

func test_simulate_invalid_effect():
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    var simulation = modifier.simulate_effect()
    assert_eq(simulation.size(), 0, "Simulation should return an empty dictionary for invalid modifiers")

## Merge Tests
func test_merge_valid_modifiers():
    var modifier1 = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    var modifier2 = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 25.0)
    assert_true(modifier1.merge(modifier2), "Merge should succeed for valid modifiers")
    assert_eq(modifier1.get_value(), 75.0, "Merged value should be the sum of both modifiers")

func test_merge_invalid_modifiers():
    var modifier1 = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    var modifier2 = StatModifier.new("Mana", StatModifier.StatModifierType.FLAT, 25.0)
    assert_false(modifier1.merge(modifier2), "Merge should fail for modifiers with different stat names")
    assert_eq(modifier1.get_value(), 50.0, "Original value should remain unchanged after failed merge")

## Serialization Tests
func test_to_dict_and_from_dict():
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier._is_applied = true
    modifier._applied_value = 50.0
    var dict = modifier.to_dict()
    var new_modifier = StatModifier.new()
    new_modifier.from_dict(dict)
    assert_eq(new_modifier.get_stat_name(), "Health", "Stat name should match after deserialization")
    assert_eq(new_modifier.get_type(), StatModifier.StatModifierType.FLAT, "Modifier type should match after deserialization")
    assert_eq(new_modifier.get_value(), 50.0, "Modifier value should match after deserialization")
    assert_eq(new_modifier.is_applied(), true, "Applied state should match after deserialization")
    assert_eq(new_modifier._applied_value, 50.0, "Applied value should match after deserialization")

## Edge Case Tests
func test_extreme_values():
    var stat = _create_test_stat()
    stat.final_value_clamped = true
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 1e9)
    modifier.init_stat(parent)
    modifier.apply()
    assert_eq(stat.get_value(), stat.get_max(), "Stat value should be clamped to max_value with extreme modifiers")

func test_negative_values():
    var stat = _create_test_stat()
    stat.final_value_clamped = true
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, -150.0)
    modifier.init_stat(parent)
    modifier.apply()
    assert_eq(stat.get_value(), stat.get_min(), "Stat value should be clamped to min_value with negative modifiers")


# Test applying percent modifiers
func test_apply_percent_modifier():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.PERCENT, 50.0)  # 50% increase
    modifier.init_stat(parent)
    var applied_change = modifier.apply()
    assert_eq(applied_change, 50.0, "Applied change should be 50% of base value")
    assert_eq(stat.get_value(), 150.0, "Stat value should increase by 50%")

# Test removing a modifier completely
func test_remove_modifier_completely():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 50.0)
    modifier.init_stat(parent)
    modifier.apply()
    var removed_change = modifier.remove()
    assert_eq(removed_change, -50.0, "Removed change should match the applied value")
    assert_eq(stat.get_value(), 100.0, "Stat value should return to base after removal")
    assert_false(modifier.is_applied(), "Modifier should no longer be applied")

# Test applying a modifier multiple times
func test_multiple_applications():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 10.0)
    modifier.init_stat(parent)
    modifier._apply_only_once = false  # Allow multiple applications
    
    modifier.apply()  # +10
    modifier.apply()  # +10
    modifier.apply()  # +10
    
    assert_eq(stat.get_value(), 130.0, "Stat should increase by modifier value each time")
    assert_eq(modifier._applied_value, 30.0, "Applied value should track total effect")

# Test partial removal of a modifier
func test_partial_removal():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 30.0)
    modifier.init_stat(parent)
    modifier._apply_only_once = false
    
    modifier.apply()  # +30
    modifier.apply()  # +30
    assert_eq(stat.get_value(), 160.0, "Stat should increase by total applied amount")
    
    var removed = modifier.remove(false)  # Remove one application (30)
    assert_eq(removed, -30.0, "Should remove one application amount")
    assert_eq(stat.get_value(), 130.0, "Stat should decrease by one application")
    assert_true(modifier.is_applied(), "Modifier should still be applied")
    assert_eq(modifier._applied_value, 30.0, "Applied value should reflect remaining effect")

# Test complete removal of multiple applications
func test_complete_removal():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 25.0)
    modifier.init_stat(parent)
    modifier._apply_only_once = false
    
    modifier.apply()  # +25
    modifier.apply()  # +25
    modifier.apply()  # +25
    assert_eq(stat.get_value(), 175.0, "Stat should increase by total applied amount")
    
    var removed = modifier.remove(true)  # Remove all
    assert_eq(removed, -75.0, "Should remove entire applied amount")
    assert_eq(stat.get_value(), 100.0, "Stat should return to base value")
    assert_false(modifier.is_applied(), "Modifier should no longer be applied")
    assert_eq(modifier._applied_value, 0.0, "Applied value should be reset to zero")

# Test negative modifiers
func test_negative_modifiers():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, -20.0)
    modifier.init_stat(parent)
    
    var applied = modifier.apply()
    assert_eq(applied, -20.0, "Applied change should be negative")
    assert_eq(stat.get_value(), 80.0, "Stat should decrease by modifier value")
    
    var removed = modifier.remove()
    assert_eq(removed, 20.0, "Removed change should be positive (absolute value)")
    assert_eq(stat.get_value(), 100.0, "Stat should return to base value")

# Test edge cases with mixed sign modifiers
func test_mixed_sign_applications():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 30.0)
    modifier.init_stat(parent)
    modifier._apply_only_once = false
    
    modifier.apply()  # +30
    assert_eq(stat.get_value(), 130.0, "Stat should increase")
    
    modifier.set_value(-40.0)  # Change to negative
    assert_eq(stat.get_value(), 60.0, "Stat should decrease after applying negative")
    assert_eq(modifier._applied_value, -40.0, "Applied value should be net effect (-40)")
    
    var removed = modifier.remove(false)  # Partial removal
    assert_eq(removed, 40.0, "Should remove most recent application amount")
    assert_eq(stat.get_value(), 100.0, "Stat should return to previous value")

# Test handling of value clamping at stat boundaries
func test_value_clamping():
    var stat = _create_test_stat(100.0, 0.0, 150.0)  # Max of 150
    stat.final_value_clamped = true
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 100.0)
    modifier.init_stat(parent)
    
    var applied = modifier.apply()
    assert_eq(applied, 100.0, "Applied flat modifier should be 100")
    assert_eq(stat.get_value(), 150.0, "Stat should be clamped to max value")
    assert_eq(modifier._applied_value, 100.0, "Applied value should track actual change")
    
    var removed = modifier.remove()
    assert_eq(removed, -100.0, "Removed change should match actual applied value")
    assert_eq(stat.get_value(), 100.0, "Stat should return to base value")

# Test setting value after application
func test_set_value_after_apply():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 20.0)
    modifier.init_stat(parent)
    
    modifier.apply()  # +20
    assert_eq(stat.get_value(), 120.0, "Stat should increase by initial value")
    
    modifier.set_value(50.0)  # Change to 50
    assert_eq(stat.get_value(), 150.0, "Stat should reflect new value after set_value")
    assert_eq(modifier._applied_value, 50.0, "Applied value should match new value")

# Test merging modifiers
func test_merge_modifiers():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    
    var mod1 = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 20.0)
    mod1.init_stat(parent)
    mod1.apply()
    
    var mod2 = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 30.0)
    
    var merged = mod1.merge(mod2)
    assert_true(merged, "Merge should succeed with compatible modifiers")
    assert_eq(mod1._value, 50.0, "Merged value should be sum of both values")
    
    # Check if applied value was updated
    assert_eq(stat.get_value(), 150.0, "Stat should reflect merged value")
    assert_eq(mod1._applied_value, 50.0, "Applied value should match merged value")

# Test floating point precision handling
func test_floating_point_precision():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 0.1)
    modifier.init_stat(parent)
    modifier._apply_only_once = false
    
    # Apply small increments
    for i in range(10):
        modifier.apply()
    
    assert_eq(stat.get_value(), 101.0, "Stat should accurately track small increments")
    
    # Remove small decrements
    for i in range(10):
        modifier.remove(false)
    
    assert_eq(stat.get_value(), 100.0, "Stat should return to base value after small decrements")
    assert_false(modifier.is_applied(), "Modifier should no longer be applied after complete removal")

# Test uninit_stat with no prior init
func test_uninit_stat2():
    var stat = _create_test_stat()
    var parent = _create_parent_with_stat(stat)
    var modifier = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 0.1)
    modifier.init_stat(parent)

    # Test uninit when remove_all is true
    modifier.uninit_stat(true)
    assert_false(modifier.is_applied(), "Modifier should no longer be applied after uninit")
    assert_eq(stat.get_value(), 100.0, "Stat should return to base value after uninit")

    # Re-init and test uninit when remove_all is false
    modifier.init_stat(parent)
    modifier.apply()
    assert_eq(stat.get_value(), 100.1, "Stat should increase by applied value")
    modifier.uninit_stat(false)
    assert_false(modifier.is_applied(), "Modifier should not be applied after uninit")
    assert_eq(modifier._applied_value, 0.0, "Applied value should still be zero")
    assert_eq(stat.get_value(), 100.1, "Stat should return to base value after uninit")