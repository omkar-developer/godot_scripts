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