extends GutTest

## Base Value and Clamping Tests
func test_base_value_within_range():
	var stat = Stat.new()
	stat.base_value = 50.0
	assert_eq(stat.base_value, 50.0, "Base value should be set to 50.0")

func test_base_value_clamped_below_min():
	var stat = Stat.new()
	stat.base_value_clamped = true
	stat.min_value = 10.0
	stat.base_value = 5.0
	assert_eq(stat.base_value, 10.0, "Base value should be clamped to min_value")

func test_base_value_clamped_above_max():
	var stat = Stat.new()
	stat.base_value_clamped = true
	stat.max_value = 100.0
	stat.base_value = 150.0
	assert_eq(stat.base_value, 100.0, "Base value should be clamped to max_value")

func test_min_equals_max():
	var stat = Stat.new()
	stat.min_value = 100.0
	stat.max_value = 100.0
	stat.base_value = 50.0
	stat.base_value_clamped = true
	assert_eq(stat.get_value(), 100.0, "Value should be clamped to min_value (or max_value)")

## Signal Emission Tests
func test_signal_emission_on_base_value_change():
	var stat = Stat.new()
	
	# Use a dictionary to track signal emission and parameters
	var signal_data = {
		"emitted": false,
		"new_value": 0.0,
		"new_max": 0.0,
		"old_value": 0.0,
		"old_max": 0.0
	}
	
	# Define the signal handler
	var _on_value_changed = func(_new_value, _new_max, _old_value, _old_max):
		signal_data["emitted"] = true
		signal_data["new_value"] = _new_value
		signal_data["new_max"] = _new_max
		signal_data["old_value"] = _old_value
		signal_data["old_max"] = _old_max
	
	# Connect the signal to a named function
	stat.connect("value_changed", _on_value_changed)

	# Change the base value to trigger the signal
	stat.base_value = 50.0

	# Assert that the signal was emitted
	assert_true(signal_data["emitted"], "Signal should be emitted when base value changes")

	# Validate the signal parameters
	assert_eq(signal_data["new_value"], 50.0, "New value should match the updated base value")
	assert_eq(signal_data["old_value"], 0.0, "Old value should match the previous base value")
	assert_eq(signal_data["new_max"], stat.get_max(), "New max should match the calculated max value")
	assert_eq(signal_data["old_max"], stat.get_max(), "Old max should match the calculated max value")

func test_signal_not_emitted_when_disabled():
	var stat = Stat.new()
	
	# Use a dictionary to track signal emission
	var signal_data = {
		"emitted": false
	}

	# Disable signals
	stat.enable_signal = false    
	
	# Define the signal handler
	var _on_value_changed = func(_new_value, _new_max, _old_value, _old_max):
		signal_data["emitted"] = true
	
	# Connect the signal to a named function
	stat.connect("value_changed", _on_value_changed)

	# Change the base value
	stat.base_value = 50.0

	# Assert that the signal was NOT emitted
	assert_false(signal_data["emitted"], "Signal should not be emitted when enable_signal is false")

## Modifiers Tests
func test_flat_modifier_addition():
	var stat = Stat.new()
	stat.base_value = 100.0
	stat.flat_modifier = 10.0
	assert_eq(stat.get_value(), 110.0, "Final value should include flat modifier")

func test_percent_modifier_multiplication():
	var stat = Stat.new()
	stat.base_value = 100.0
	stat.percent_modifier = 50.0
	assert_eq(stat.get_value(), 150.0, "Final value should include percent modifier")

func test_combined_modifiers():
	var stat = Stat.new()
	stat.base_value = 100.0
	stat.flat_modifier = 10.0
	stat.percent_modifier = 50.0
	assert_eq(stat.get_value(), 160.0, "Final value should combine flat and percent modifiers")

func test_extreme_modifiers():
	var stat = Stat.new()
	stat.final_value_clamped = true
	stat.base_value = 100.0
	stat.flat_modifier = 1e9
	stat.percent_modifier = 1e9
	assert_eq(stat.get_value(), stat.get_max(), "Value should be clamped to max_value with extreme modifiers")

## Final Value Clamping Tests
func test_final_value_clamped_below_min():
	var stat = Stat.new()
	stat.final_value_clamped = true
	stat.min_value = 10.0
	stat.base_value = 5.0
	stat.flat_modifier = -10.0
	assert_eq(stat.get_value(), 10.0, "Final value should be clamped to min_value")

func test_final_value_clamped_above_max():
	var stat = Stat.new()
	stat.final_value_clamped = true
	stat.max_value = 100.0
	stat.base_value = 150.0
	stat.flat_modifier = 50.0
	assert_eq(stat.get_value(), 100.0, "Final value should be clamped to max_value")

## Serialization and Deserialization Tests
func test_to_dict():
	var stat = Stat.new()
	stat.base_value = 50.0
	stat.flat_modifier = 10.0
	stat.percent_modifier = 20.0
	var dict = stat.to_dict()
	assert_eq(dict["base_value"], 50.0, "Base value should be serialized correctly")
	assert_eq(dict["flat_modifier"], 10.0, "Flat modifier should be serialized correctly")
	assert_eq(dict["percent_modifier"], 20.0, "Percent modifier should be serialized correctly")

func test_from_dict():
	var stat = Stat.new()
	var dict = {
		"base_value": 50.0,
		"flat_modifier": 10.0,
		"percent_modifier": 20.0
	}
	stat.from_dict(dict)
	assert_eq(stat.base_value, 50.0, "Base value should be deserialized correctly")
	assert_eq(stat.flat_modifier, 10.0, "Flat modifier should be deserialized correctly")
	assert_eq(stat.percent_modifier, 20.0, "Percent modifier should be deserialized correctly")

## Utility Function Tests
func test_normalized_value():
	var stat = Stat.new()
	stat.base_value = 50.0
	stat.max_value = 100.0
	assert_eq(stat.get_normalized_value(), 0.5, "Normalized value should be 0.5")

func test_difference():
	var stat = Stat.new()
	stat.base_value = 50.0
	stat.flat_modifier = 10.0
	assert_eq(stat.get_difference(), 10.0, "Difference should match the flat modifier")

func test_is_max_and_is_min():
	var stat = Stat.new()
	stat.base_value = 100.0
	stat.max_value = 100.0
	assert_true(stat.is_max(), "is_max() should return true when value equals max_value")
	stat.base_value = 0.0
	stat.min_value = 0.0
	assert_true(stat.is_min(), "is_min() should return true when value equals min_value")

## Edge Case Tests
func test_reset_modifiers():
	var stat = Stat.new()
	stat.flat_modifier = 10.0
	stat.percent_modifier = 20.0
	stat.reset_modifiers()
	assert_eq(stat.flat_modifier, 0.0, "Flat modifier should be reset to 0.0")
	assert_eq(stat.percent_modifier, 0.0, "Percent modifier should be reset to 0.0")

func test_boolean_representation():
	var stat = Stat.new()
	stat.set_as_bool(true)
	assert_eq(stat.base_value, 1.0, "Base value should be set to 1.0 for true")
	stat.set_as_bool(false)
	assert_eq(stat.base_value, 0.0, "Base value should be set to 0.0 for false")

func test_string_representation():
	var stat = Stat.new()
	stat.base_value = 50.0
	stat.flat_modifier = 10.0
	stat.percent_modifier = 20.0
	var expected = "Value: 70.0 (Base: 50.0, Flat: 10.0, Percent: 20.0%)"
	assert_eq(stat.string(), expected, "String representation should match expected output")

## StatType Tests
func test_float_type_default():
	var stat = Stat.new()
	assert_eq(stat.stat_type, Stat.StatType.FLOAT, "Default stat type should be FLOAT")
	
func test_float_type_precision():
	var stat = Stat.new(50.75)
	assert_eq(stat.get_value(), 50.75, "Float type should preserve decimal precision")
	
func test_int_type_conversion():
	var stat = Stat.new(50.75)
	stat.stat_type = Stat.StatType.INT
	assert_eq(stat.get_value(), 50.0, "INT type should truncate to integer")
	
	# Test with a different value to ensure consistency
	stat.base_value = 75.9
	assert_eq(stat.get_value(), 75.0, "INT type should truncate to integer")

func test_bool_type_conversion():
	var stat = Stat.new(0.5)
	stat.stat_type = Stat.StatType.BOOL
	assert_eq(stat.get_value(), 1.0, "Value above EPSILON should convert to 1.0")
	
	stat.base_value = 0.0
	assert_eq(stat.get_value(), 0.0, "Zero value should remain 0.0")
	
	# Test with a very small value below EPSILON
	stat.base_value = 0.00001 # Assuming EPSILON is 0.0001
	assert_eq(stat.get_value(), 0.0, "Value below EPSILON should convert to 0.0")

func test_type_conversion_with_modifiers():
	# Test with INT type
	var stat = Stat.new(10.7)
	stat.stat_type = Stat.StatType.INT
	stat.percent_modifier = 50.0
	stat.flat_modifier = 2.3
	# (10.7 + (10.7 * 0.5) + 2.3) = 18.35 → truncated to 18.0
	assert_eq(stat.get_value(), 18.0, "INT type should apply modifiers then truncate")
	
	# Test with BOOL type
	stat = Stat.new(0.0)
	stat.stat_type = Stat.StatType.BOOL
	stat.flat_modifier = 0.00001
	assert_eq(stat.get_value(), 0.0, "Small modifier not exceeding EPSILON should remain 0")
	
	stat.flat_modifier = 0.5
	assert_eq(stat.get_value(), 1.0, "Modifier pushing value above EPSILON should convert to 1.0")

func test_set_as_bool_method():
	var stat = Stat.new()
	stat.stat_type = Stat.StatType.BOOL
	
	stat.set_as_bool(true)
	assert_eq(stat.base_value, 1.0, "set_as_bool(true) should set base_value to 1.0")
	assert_eq(stat.get_value(), 1.0, "get_value() should return 1.0 when set as true")
	
	stat.set_as_bool(false)
	assert_eq(stat.base_value, 0.0, "set_as_bool(false) should set base_value to 0.0")
	assert_eq(stat.get_value(), 0.0, "get_value() should return 0.0 when set as false")

func test_get_as_bool_method():
	var stat = Stat.new(0.0)
	assert_false(stat.get_as_bool(), "get_as_bool() should return false for zero value")
	
	stat.base_value = 1.0
	assert_true(stat.get_as_bool(), "get_as_bool() should return true for non-zero value")
	
	stat.base_value = 0.5
	assert_true(stat.get_as_bool(), "get_as_bool() should return true for any non-zero value")

func test_epsilon_comparison_in_is_max_min():
	# Test floating point type with epsilon comparison
	var stat = Stat.new(100.0)
	stat.max_value = 100.0
	stat.stat_type = Stat.StatType.FLOAT
	
	assert_true(stat.is_max(), "Floating point value at max should be detected via epsilon comparison")
	
	stat.base_value = 99.99999
	assert_true(stat.is_max(), "Value within EPSILON of max should return true for is_max()")
	
	stat.base_value = 99.99
	assert_false(stat.is_max(), "Value outside EPSILON of max should return false for is_max()")
	
	# Similar tests for is_min()
	stat.base_value = stat.min_value
	assert_true(stat.is_min(), "Value at min should return true for is_min()")
	
	stat.base_value = stat.min_value + 0.00005
	assert_true(stat.is_min(), "Value within EPSILON of min should return true for is_min()")

func test_add_methods_with_type_conversion():
	# INT type
	var stat = Stat.new(10.0)
	stat.stat_type = Stat.StatType.INT
	
	var added = stat.add_value(5.7)
	assert_eq(stat.base_value, 15.0, "add_value should apply type conversion")
	assert_eq(added, 5.0, "add_value should return the actual change amount after conversion")
	
	added = stat.add_flat(2.9)
	assert_eq(stat.flat_modifier, 2.0, "add_flat should apply type conversion")
	assert_eq(added, 2.0, "add_flat should return the actual change amount after conversion")
	
	# BOOL type
	stat = Stat.new(0.0)
	stat.stat_type = Stat.StatType.BOOL
	
	added = stat.add_value(0.00001)
	assert_eq(stat.base_value, 0.0, "Small value add should not change bool state")
	assert_eq(added, 0.0, "Small value add should return no change for bool")
	
	added = stat.add_value(0.5)
	assert_eq(stat.base_value, 1.0, "Value above EPSILON should change bool state to true")
	assert_eq(added, 1.0, "Should return the change from 0.0 to 1.0")

func test_serialization_with_type():
	var stat = Stat.new(42.0)
	stat.stat_type = Stat.StatType.INT
	
	var dict = stat.to_dict()
	assert_eq(dict["stat_type"], Stat.StatType.INT, "to_dict() should include stat_type")
	
	var new_stat = Stat.new()
	new_stat.from_dict(dict)
	assert_eq(new_stat.stat_type, Stat.StatType.INT, "from_dict() should restore stat_type")
	assert_eq(new_stat.get_value(), 42.0, "from_dict() should restore values with type conversion")

func test_max_methods_with_type_conversion():
	# INT type
	var stat = Stat.new()
	stat.stat_type = Stat.StatType.INT
	stat.max_value = 100.0
	
	var added = stat.add_max_value(10.7)
	assert_eq(stat.max_value, 110.0, "add_max_value should apply type conversion")
	assert_eq(added, 10.0, "add_max_value should return the actual change after conversion")
	
	added = stat.add_max_flat(5.9)
	assert_eq(stat.max_flat_modifier, 5.0, "add_max_flat should apply type conversion")
	assert_eq(added, 5.0, "add_max_flat should return the actual change after conversion")
	
	# BOOL type max checks
	stat = Stat.new()
	stat.stat_type = Stat.StatType.BOOL
	stat.max_value = 1.0
	
	var max_val = stat.get_max()
	assert_eq(max_val, 1.0, "Maximum for bool type should be 1.0")
	
	stat.max_value = 2.0 
	max_val = stat.get_max()
	assert_eq(max_val, 1.0, "Maximum for bool type should always convert to 1.0")

func test_normalized_value_with_types():
	# Test with INT type
	var stat = Stat.new(50.0, false, 0.0, 100.0)
	stat.stat_type = Stat.StatType.INT
	assert_eq(stat.get_normalized_value(), 0.5, "Normalized value should work with INT type")
	
	# With BOOL type
	stat = Stat.new(1.0, false, 0.0, 1.0)
	stat.stat_type = Stat.StatType.BOOL
	assert_eq(stat.get_normalized_value(), 1.0, "Normalized value for true bool should be 1.0")
	
	stat.base_value = 0.0
	assert_eq(stat.get_normalized_value(), 0.0, "Normalized value for false bool should be 0.0")

func test_get_difference_with_types():
	# Test with INT type
	var stat = Stat.new(50.0)
	stat.stat_type = Stat.StatType.INT
	stat.flat_modifier = 10.7 # Will convert to 10
	
	assert_eq(stat.get_difference(), 10.0, "get_difference should return integer difference")
	
	# With BOOL type 
	stat = Stat.new(0.0)
	stat.stat_type = Stat.StatType.BOOL
	stat.flat_modifier = 0.5 # Enough to flip to true
	
	assert_eq(stat.get_difference(), 1.0, "get_difference for bool should return 1.0 when flipped")
