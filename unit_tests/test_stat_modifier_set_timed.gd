extends GutTest

# Helper objects
var StatModifierClassScript := StatModifier
var StatClassScript := Stat
var ConditionClassScript := Condition
var StatModifierSetClassScript := StatModifierSet
var StatModifierSetTimedClassScript := StatModifierSetTimed

## Helper function to create a Stat instance for testing
func _create_test_stat(base_value: float = 100.0, min_value: float = 0.0, max_value: float = 200.0) -> Stat:
	var stat = StatClassScript.new()
	stat.base_value = base_value
	stat.min_value = min_value
	stat.max_value = max_value
	return stat

## Helper function to create a parent object with a get_stat method
func _create_parent_with_stat(stats: Dictionary) -> RefCounted:
	# Create a new RefCounted object
	var parent = RefCounted.new()

	# Dynamically create a script with a `get_stat` method
	var script = GDScript.new()
	script.source_code = """
extends RefCounted

# The stat dictionary to hold stats by name
var _stats = {}

# Constructor to initialize the stats
func initialize(stats: Dictionary):
	_stats = stats

# Method to fetch the stat by name
func get_stat(stat_name: String):
	return _stats.get(stat_name)
"""
	script.reload()  # Reload the script to compile it

	# Attach the script to the parent object
	parent.set_script(script)

	# Initialize the script with the provided stats
	parent.initialize(stats)

	return parent

## Helper function to create a basic StatModifier for testing
func _create_test_modifier(stat_name: String = "Health", 
						   type = StatModifierClassScript.StatModifierType.FLAT, 
						   value: float = 50.0) -> StatModifier:
	return StatModifier.new(stat_name, type, value)

## Helper function to create a Condition for testing
func _create_test_condition(initial_state: bool = true) -> Condition:
	var condition = Condition.new()
	condition._current_condition = initial_state
	return condition

## Helper function to create a mock Timer for advancing time in tests
class MockTimer:
	var time := 0.0
	var delta := 0.0
	
	func set_delta(new_delta: float) -> void:
		delta = new_delta
	
	func advance(amount: float = -1.0) -> float:
		var advance_amount = amount if amount >= 0 else delta
		time += advance_amount
		return advance_amount

# Basic Initialization Tests for StatModifierSetTimed
func test_timed_init_with_default_values():
	var mod_set = StatModifierSetTimedClassScript.new()
	assert_eq(mod_set._modifier_name, "", "Default modifier name should be empty")
	assert_eq(mod_set._group, "", "Default group should be empty")
	assert_eq(mod_set.process, false, "Default process should be false")
	assert_eq(mod_set.apply_at_start, true, "Default apply_at_start should be true")
	assert_eq(mod_set.interval, 0.0, "Default interval should be 0.0")
	assert_eq(mod_set.duration, 0.0, "Default duration should be 0.0")
	assert_eq(mod_set.total_ticks, -1.0, "Default total_ticks should be -1.0")
	assert_eq(mod_set.merge_type, 3, "Default merge_type should be 3 (ADD_DURATION | ADD_VALUE)")

func test_timed_init_with_custom_values():
	var mod_set = StatModifierSetTimedClassScript.new(
		"Test Timed Set", true, "DoTs", false, 1.0, 0.5, 10.0, 5.0, 10, 7, false
	)
	assert_eq(mod_set._modifier_name, "Test Timed Set", "Modifier name should match")
	assert_eq(mod_set._group, "DoTs", "Group should match")
	assert_eq(mod_set.process, true, "Process should match")
	assert_eq(mod_set.apply_at_start, false, "apply_at_start should match")
	assert_eq(mod_set.interval, 1.0, "interval should match")
	assert_eq(mod_set.minimum_interval, 0.5, "minimum_interval should match")
	assert_eq(mod_set.maximum_interval, 10.0, "maximum_interval should match")
	assert_eq(mod_set.duration, 5.0, "duration should match")
	assert_eq(mod_set.total_ticks, 10, "total_ticks should match")
	assert_eq(mod_set.merge_type, 7, "merge_type should match")
	assert_eq(mod_set.remove_effect_on_finish, false, "remove_effect_on_finish should match")

# Timer and Tick Tests
func test_interval_tick_system():
	var mock_timer = MockTimer.new()
	mock_timer.set_delta(0.5)
	
	var mod_set = StatModifierSetTimedClassScript.new(
		"Test", true, "Timed", true, 1.0, 0.0, 10.0, 0.0, 5
	)
	
	# Set up a counter to track how many times _apply_effect is called
	var apply_counter = {
		   "value": 0
	}
	
	# Create a mock apply_effect method
	mod_set.on_effect_apply.connect(func():
		apply_counter["value"] += 1)
	
	# Process several times and check tick counter
	for i in range(10):
		mod_set._process(mock_timer.advance())
	
	assert_eq(apply_counter["value"], 5, "Should have applied effect 5 times at 1 second intervals over 5 seconds")
	assert_eq(mod_set.ticks, 5, "Tick counter should be 5")
	assert_true(mod_set.is_marked_for_deletion(), "ModSet should be marked for deletion after reaching total_ticks")

func test_duration_system():
	var mock_timer = MockTimer.new()
	mock_timer.set_delta(1.0)
	
	var mod_set = StatModifierSetTimedClassScript.new(
		"Test", true, "Duration", true, 0.0, 0.0, 10.0, 5.0, -1
	)
	
	# Process several times and check if it's deleted after duration
	for i in range(4):
		mod_set._process(mock_timer.advance())
		assert_false(mod_set.is_marked_for_deletion(), "ModSet should not be marked for deletion before duration")
	
	# This should trigger deletion as we hit 5.0 seconds
	mod_set._process(mock_timer.advance())
	assert_true(mod_set.is_marked_for_deletion(), "ModSet should be marked for deletion after duration")

# Merge Tests
func test_merge_add_duration():
	var mod_set1 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 0.0, 0.0, 10.0, 5.0, -1, 
		StatModifierSetTimedClassScript.MergeType.ADD_DURATION
	)
	
	var mod_set2 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 0.0, 0.0, 10.0, 3.0, -1,
		StatModifierSetTimedClassScript.MergeType.ADD_DURATION
	)
	
	mod_set1.merge_mod(mod_set2)
	assert_eq(mod_set1.duration, 8.0, "Duration should be sum of both durations")

func test_merge_add_value():
	var stat = _create_test_stat(100.0)
	var stats = {"Health": stat}
	var parent = _create_parent_with_stat(stats)
	
	var mod_flat = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0)
	var mod_set1 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 0.0, 0.0, 10.0, 5.0, -1, 
		StatModifierSetTimedClassScript.MergeType.ADD_VALUE
	)
	
	var mod_flat2 = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 30.0)
	var mod_set2 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 0.0, 0.0, 10.0, 3.0, -1,
		StatModifierSetTimedClassScript.MergeType.ADD_VALUE
	)

	mod_set1.init_modifiers(parent)
	mod_set2.init_modifiers(parent)
	
	mod_set1.add_modifier(mod_flat)
	mod_set2.add_modifier(mod_flat2)	
	
	mod_set1.merge_mod(mod_set2)
	
	var flat_mod = mod_set1.find_mod_by_name_and_type("Health", StatModifierClassScript.StatModifierType.FLAT)
	assert_not_null(flat_mod, "Flat mod should exist")
	assert_eq(flat_mod.get_value(), 80.0, "Value should be sum of both modifiers")

func test_merge_add_interval():
	var mod_set1 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 2.0, 1.0, 10.0, 5.0, -1, 
		StatModifierSetTimedClassScript.MergeType.ADD_INTERVAL
	)
	
	var mod_set2 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 3.0, 1.0, 10.0, 3.0, -1,
		StatModifierSetTimedClassScript.MergeType.ADD_INTERVAL
	)
	
	mod_set1.merge_mod(mod_set2)
	assert_eq(mod_set1.interval, 5.0, "Interval should be sum of both intervals")
	
	# Test maximum capping
	mod_set1.interval = 7.0
	mod_set1.merge_mod(mod_set2)
	assert_eq(mod_set1.interval, 10.0, "Interval should be capped at maximum_interval")

func test_merge_reduce_interval():
	var mod_set1 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 5.0, 1.0, 10.0, 5.0, -1, 
		StatModifierSetTimedClassScript.MergeType.REDUCE_INTERVAL
	)
	
	var mod_set2 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 3.0, 1.0, 10.0, 3.0, -1,
		StatModifierSetTimedClassScript.MergeType.REDUCE_INTERVAL
	)
	
	mod_set1.merge_mod(mod_set2)
	assert_eq(mod_set1.interval, 2.0, "Interval should be reduced by second interval")
	
	# Test minimum capping
	mod_set1.interval = 2.0
	mod_set1.merge_mod(mod_set2)
	assert_eq(mod_set1.interval, 1.0, "Interval should be capped at minimum_interval")

func test_merge_reset_timers():
	var mock_timer = MockTimer.new()
	mock_timer.set_delta(1.0)
	
	var mod_set1 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 5.0, 1.0, 10.0, 10.0, -1, 
		(StatModifierSetTimedClassScript.MergeType.RESET_DURATION | 
		 StatModifierSetTimedClassScript.MergeType.RESET_INTERVAL_TIMER)
	)
	
	var mod_set2 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 3.0, 1.0, 10.0, 3.0, -1
	)
	
	# Advance timers
	mod_set1.timer = 5.0
	mod_set1.tick_timer = 3.0
	
	mod_set1.merge_mod(mod_set2)
	assert_eq(mod_set1.timer, 0.0, "Duration timer should be reset")
	assert_eq(mod_set1.tick_timer, 0.0, "Tick timer should be reset")

func test_merge_delete():
	var mod_set1 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 5.0, 1.0, 10.0, 5.0, -1, 
		StatModifierSetTimedClassScript.MergeType.DELETE
	)
	
	var mod_set2 = StatModifierSetTimedClassScript.new(
		"Merge Test", false, "", true, 3.0, 1.0, 10.0, 3.0, -1
	)
	
	mod_set1.merge_mod(mod_set2)
	assert_true(mod_set1.is_marked_for_deletion(), "ModSet should be marked for deletion after merge")

# Serialization Tests
func test_to_dict_from_dict():
	var stat = _create_test_stat(100.0)
	var stat2 = _create_test_stat(100.0)
	var stats = {"Health": stat, "Mana": stat2}
	var parent = _create_parent_with_stat(stats)

	var original = StatModifierSetTimedClassScript.new(
		"Test Serialization", true, "SaveLoad", false, 2.5, 1.0, 10.0, 7.5, 5, 
		StatModifierSetTimedClassScript.MergeType.ADD_DURATION | 
		StatModifierSetTimedClassScript.MergeType.ADD_VALUE,
		true
	)

	original.init_modifiers(parent)
	
	# Add some modifiers
	var mod1:StatModifier = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0)
	var mod2:StatModifier = _create_test_modifier("Mana", StatModifierClassScript.StatModifierType.PERCENT, 0.25)
	original.add_modifier(mod1)
	original.add_modifier(mod2)
	
	# Set timers
	original.timer = 3.2
	original.tick_timer = 1.7
	original.ticks = 2
	
	# Convert to dict
	var dict = original.to_dict()
	
	# Create new object from dict
	var loaded = StatModifierSetTimedClassScript.new()
	loaded.init_modifiers(parent)
	loaded.from_dict(dict)
	
	# Verify all properties were copied correctly
	assert_eq(loaded._modifier_name, "Test Serialization", "Modifier name should match")
	assert_eq(loaded._group, "SaveLoad", "Group should match")
	assert_eq(loaded.process, true, "Process should match")
	assert_eq(loaded.apply_at_start, false, "apply_at_start should match")
	assert_eq(loaded.interval, 2.5, "interval should match")
	assert_eq(loaded.minimum_interval, 1.0, "minimum_interval should match")
	assert_eq(loaded.maximum_interval, 10.0, "maximum_interval should match")
	assert_eq(loaded.duration, 7.5, "duration should match")
	assert_eq(loaded.total_ticks, 5, "total_ticks should match")
	assert_eq(loaded.timer, 3.2, "timer should match")
	assert_eq(loaded.tick_timer, 1.7, "tick_timer should match")
	assert_eq(loaded.ticks, 2, "ticks should match")
	assert_eq(loaded._modifiers.size(), 2, "Should have loaded 2 modifiers")
	
	# Check loaded modifiers
	var health_mod = loaded.find_mod_for_stat("Health")
	var mana_mod = loaded.find_mod_for_stat("Mana")
	assert_not_null(health_mod, "Health modifier should exist")
	assert_not_null(mana_mod, "Mana modifier should exist")
	assert_eq(health_mod.get_value(), 50.0, "Health modifier value should match")
	assert_eq(mana_mod.get_value(), 0.25, "Mana modifier value should match")

# Copy Tests
func test_copy():
	var original = StatModifierSetTimedClassScript.new(
		"Test Copy", true, "Duplication", false, 2.5, 1.0, 10.0, 7.5, 5, 
		StatModifierSetTimedClassScript.MergeType.ADD_DURATION | 
		StatModifierSetTimedClassScript.MergeType.ADD_VALUE,
		true
	)
	
	# Add some modifiers
	var mod1 = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0)
	var mod2 = _create_test_modifier("Mana", StatModifierClassScript.StatModifierType.PERCENT, 0.25)
	original.add_modifier(mod1)
	original.add_modifier(mod2)
	
	# Add condition
	var condition = _create_test_condition(true)
	original.condition = condition
	
	# Set timers
	original.timer = 3.2
	original.tick_timer = 1.7
	original.ticks = 2
	
	# Copy the object
	var copy = original.copy()
	
	# Verify all properties were copied correctly
	assert_eq(copy._modifier_name, "Test Copy", "Modifier name should match")
	assert_eq(copy._group, "Duplication", "Group should match")
	assert_eq(copy.process, true, "Process should match")
	assert_eq(copy.apply_at_start, false, "apply_at_start should match")
	assert_eq(copy.interval, 2.5, "interval should match")
	assert_eq(copy.minimum_interval, 1.0, "minimum_interval should match")
	assert_eq(copy.maximum_interval, 10.0, "maximum_interval should match")
	assert_eq(copy.duration, 7.5, "duration should match")
	assert_eq(copy.total_ticks, 5, "total_ticks should match")
	assert_eq(copy.timer, 3.2, "timer should match")
	assert_eq(copy.tick_timer, 1.7, "tick_timer should match")
	assert_eq(copy.ticks, 2, "ticks should match")
	assert_eq(copy._modifiers.size(), 2, "Should have copied 2 modifiers")
	assert_not_null(copy.condition, "Condition should be copied")
	
	# Make sure copies are independent
	original.timer = 5.0
	original.interval = 3.0
	assert_eq(copy.timer, 3.2, "Copy should have independent timer value")
	assert_eq(copy.interval, 2.5, "Copy should have independent interval value")
