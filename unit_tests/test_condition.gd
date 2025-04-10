extends GutTest

# Helper class to watch signals
class SignalWatcher:
	extends RefCounted
	var signal_count = 0
	var last_condition_value = false
	
	func on_condition_changed(condition_value):
		signal_count += 1
		last_condition_value = condition_value


# Helper function to create a Stat instance for testing
func _create_test_stat(base_value: float = 100.0, min_value: float = 0.0, max_value: float = 200.0) -> Stat:
	var stat = Stat.new()
	stat.base_value = base_value
	stat.min_value = min_value
	stat.max_value = max_value
	return stat

# Helper function to create a parent object with stats
func _create_parent_with_stats(stats_dict: Dictionary) -> RefCounted:
	# Create a new RefCounted object
	var parent = RefCounted.new()
	
	# Dynamically create a script with a `get_stat` method
	var script = GDScript.new()
	script.source_code = """
extends RefCounted

# Dictionary of stats
var _stats = {}

# Constructor to initialize the stats
func initialize(stats_dict: Dictionary) -> void:
	_stats = stats_dict

# Method to fetch the stat by name
func get_stat(stat_name: String):
	if _stats.has(stat_name):
		return _stats[stat_name]
	return null
"""
	script.reload()
	
	# Attach the script to the parent object
	parent.set_script(script)
	
	# Initialize the script with the provided stats
	parent.call("initialize", stats_dict)
	
	return parent
	
# Test basic condition initialization
func test_condition_initialization():
	var hp_stat = _create_test_stat(100.0)
	var mp_stat = _create_test_stat(50.0)
	
	var stats_dict = {"hp": hp_stat, "mp": mp_stat}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "hp"
	condition._ref_stat2_name = "mp"
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "HP should be greater than MP")
	
	condition.uninit_stat()

# Test condition with equal values
func test_condition_equal():
	var stat_a = _create_test_stat(100.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.EQUAL
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "Stats should be equal")
	
	# Change one stat's value
	stat_a.base_value = 150.0
	assert_false(condition.get_condition(), "Stats should no longer be equal")
	
	condition.uninit_stat()

# Test condition with greater than
func test_condition_greater_than():
	var stat_a = _create_test_stat(150.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "stat_a should be greater than stat_b")
	
	# Make them equal
	stat_a.base_value = 100.0
	assert_false(condition.get_condition(), "stat_a should not be greater than stat_b")
	
	condition.uninit_stat()

# Test condition with less than
func test_condition_less_than():
	var stat_a = _create_test_stat(50.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.LESS_THAN
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "stat_a should be less than stat_b")
	
	# Make them equal
	stat_a.base_value = 100.0
	assert_false(condition.get_condition(), "stat_a should not be less than stat_b")
	
	condition.uninit_stat()

# Test condition with greater than or equal
func test_condition_greater_than_equal():
	var stat_a = _create_test_stat(100.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.GREATER_THAN_EQUAL
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "stat_a should be greater than or equal to stat_b")
	
	# Make stat_a less than stat_b
	stat_a.base_value = 50.0
	assert_false(condition.get_condition(), "stat_a should not be greater than or equal to stat_b")
	
	condition.uninit_stat()

# Test condition with less than or equal
func test_condition_less_than_equal():
	var stat_a = _create_test_stat(100.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.LESS_THAN_EQUAL
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "stat_a should be less than or equal to stat_b")
	
	# Make stat_a greater than stat_b
	stat_a.base_value = 150.0
	assert_false(condition.get_condition(), "stat_a should not be less than or equal to stat_b")
	
	condition.uninit_stat()

# Test condition with not equal
func test_condition_not_equal():
	var stat_a = _create_test_stat(150.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.NOT_EQUAL
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "stat_a and stat_b should not be equal")
	
	# Make them equal
	stat_a.base_value = 100.0
	assert_false(condition.get_condition(), "stat_a and stat_b should be equal")
	
	condition.uninit_stat()

# Test condition with negation
func test_condition_negation():
	var stat_a = _create_test_stat(150.0)
	var stat_b = _create_test_stat(100.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition._negation = true
	
	condition.init_stat(parent)
	assert_true(condition.is_valid(), "condition state shoud be valid")
	assert_false(condition.get_condition(), "Negated condition should be false")
	
	# Make stat_a less than stat_b
	stat_a.base_value = 50.0
	assert_true(condition.get_condition(), "Negated condition should now be true")
	
	condition.uninit_stat()

# Test condition with math expression
func test_condition_math_expression():
	var stat_a = _create_test_stat(100.0)
	var stat_b = _create_test_stat(50.0)
	
	var stats_dict = {"stat_a": stat_a, "stat_b": stat_b}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "stat_a"
	condition._ref_stat2_name = "stat_b"
	condition._condition_type = Condition.ConditionType.MATH_EXPRESSION
	condition._math_expression = "value1 > value2 * 1.5"
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "Math expression should evaluate to true")
	
	# Make stat_a smaller
	stat_a.base_value = 70.0
	stat_a.emit_signal("value_changed", 70.0, 200.0, 100.0, 200.0)
	assert_false(condition.get_condition(), "Math expression should evaluate to false")
	
	condition.uninit_stat()

# Test condition with single stat and value
func test_condition_with_value():
	var hp_stat = _create_test_stat(100.0)
	
	var stats_dict = {"hp": hp_stat}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "hp"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "HP should be greater than the value")
	
	condition._value = 150.0
	condition._update(false)
	assert_false(condition.get_condition(), "HP should not be greater than the new value")
	
	condition.uninit_stat()

# Test different stat reference types
func test_stat_reference_types():
	var stat = _create_test_stat(100.0, 0.0, 200.0)
	
	var stats_dict = {"stat": stat}
	var parent = _create_parent_with_stats(stats_dict)
	
	# Test base value
	var condition = Condition.new()
	condition._ref_stat1_name = "stat"
	condition._ref_stat1_type = Condition.RefStatType.BASE_VALUE
	condition._value = 100.0
	condition._condition_type = Condition.ConditionType.EQUAL
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "Base value should equal 100")
	
	# Test max value
	condition._ref_stat1_type = Condition.RefStatType.MAX_VALUE
	condition._value = 200.0
	condition._update(false)
	assert_true(condition.get_condition(), "Max value should equal 200")
	
	# Test normalized percent
	condition._ref_stat1_type = Condition.RefStatType.NORMALIZED_PERCENT
	condition._value = 0.5
	condition._update(false)
	assert_true(condition.get_condition(), "Normalized percent should equal 0.5")
	
	condition.uninit_stat()

# Test condition signal emission
func test_condition_signal():
	var hp_stat = _create_test_stat(100.0)
	
	var stats_dict = {"hp": hp_stat}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "hp"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	# Create a helper class to track signals
	var signal_watcher = SignalWatcher.new()
	
	# Connect the signal to the watcher
	condition.connect("condition_changed", signal_watcher.on_condition_changed)
	
	condition.init_stat(parent)
	assert_eq(signal_watcher.signal_count, 1, "Signal should be emitted once during initialization")
	assert_true(signal_watcher.last_condition_value, "Initial signal value should be true")
	
	# Change value to trigger signal again
	hp_stat.base_value = 40.0
	
	assert_eq(signal_watcher.signal_count, 2, "Signal should be emitted again after value change")
	assert_false(signal_watcher.last_condition_value, "New signal value should be false")
	
	condition.uninit_stat()

# Test cooldown functionality
func test_condition_cooldown():
	var hp_stat = _create_test_stat(100.0)
	
	var stats_dict = {"hp": hp_stat}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "hp"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition.cooldown = 1.0  # 1 second cooldown
	
	condition.init_stat(parent)
	assert_true(condition.get_condition(), "Initial condition should be true")
	
	# Change value
	hp_stat.base_value = 40.0
	
	# Condition should not update immediately due to cooldown
	assert_true(condition.get_condition(), "Condition should not change during cooldown")
	
	# Simulate time passing (process function)
	condition._timer = 0.0  # Force timer to end
	condition._update(false)  # Force update
	
	assert_false(condition.get_condition(), "Condition should change after cooldown")
	
	condition.uninit_stat()

# Test serialization and deserialization
func test_serialization():
	var hp_stat = _create_test_stat(100.0)
	
	var stats_dict = {"hp": hp_stat}
	var parent = _create_parent_with_stats(stats_dict)
	
	var condition = Condition.new()
	condition._ref_stat1_name = "hp"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition.cooldown = 1.5
	
	condition.init_stat(parent)
	
	# Serialize
	var data = condition.to_dict()
	
	# Create new condition and deserialize
	var new_condition = Condition.new()
	new_condition.from_dict(data)
	
	# Verify properties were properly transferred
	assert_eq(new_condition._ref_stat1_name, "hp", "Ref stat name should be preserved")
	assert_eq(new_condition._value, 50.0, "Value should be preserved")
	assert_eq(new_condition._condition_type, Condition.ConditionType.GREATER_THAN, "Condition type should be preserved")
	assert_eq(new_condition.cooldown, 1.5, "Cooldown should be preserved")
	
	condition.uninit_stat()

# Test invalid conditions
func test_invalid_conditions():
	# Test with non-existent stats
	var parent = _create_parent_with_stats({})
	
	var condition = Condition.new()
	condition._ref_stat1_name = "non_existent_stat"
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition._value = 50.0
	
	condition.init_stat(parent)
	assert_false(condition.get_condition(), "Condition with non-existent stat should return false")
	
	# Test with invalid math expression
	condition._condition_type = Condition.ConditionType.MATH_EXPRESSION
	condition._math_expression = "this is not a valid expression"
	condition.init_stat(parent)
	assert_false(condition.get_condition(), "Condition with invalid math expression should return false")
	
	condition.uninit_stat()
