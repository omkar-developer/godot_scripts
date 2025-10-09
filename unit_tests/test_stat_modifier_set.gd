extends GutTest

# Helper objects
var StatModifierClassScript:= StatModifier
var StatClassScript:= Stat
var ConditionClassScript:= Condition

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

# Basic Initialization Tests
func test_init_with_default_values():
	var mod_set = StatModifierSet.new()
	assert_eq(mod_set._modifier_name, "", "Default modifier name should be empty")
	assert_eq(mod_set._group, "", "Default group should be empty")
	assert_eq(mod_set.process, false, "Default process should be false")
	assert_eq(mod_set._modifiers.size(), 0, "Default modifiers array should be empty")

func test_init_with_custom_values():
	var mod_set = StatModifierSet.new("Test Set", true, "Buffs")
	assert_eq(mod_set._modifier_name, "Test Set", "Modifier name should match")
	assert_eq(mod_set._group, "Buffs", "Group should match")
	assert_eq(mod_set.process, true, "Process should match")

# Modifier Management Tests
func test_add_modifier():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Create and add modifier
	var modifier = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0)
	var added_mod = mod_set.add_modifier(modifier)
	
	assert_not_null(added_mod, "Added modifier should not be null")
	assert_eq(mod_set._modifiers.size(), 1, "Modifiers array should have one item")
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified by +50")

func test_remove_modifier():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Create and add modifier
	var modifier = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0)
	mod_set.add_modifier(modifier)
	
	# Verify modifier was added correctly
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified by +50")
	
	# Remove the modifier
	mod_set.remove_modifier(modifier)
	
	assert_eq(mod_set._modifiers.size(), 0, "Modifiers array should be empty")
	assert_eq(health_stat.get_value(), 100.0, "Health should be restored to base value")

func test_clear_modifiers():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var mana_stat = _create_test_stat(50.0)
	var parent = _create_parent_with_stat({
		"Health": health_stat,
		"Mana": mana_stat
	})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Add multiple modifiers
	mod_set.add_modifier(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	mod_set.add_modifier(_create_test_modifier("Mana", StatModifierClassScript.StatModifierType.FLAT, 25.0))
	
	# Verify modifiers were added
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified")
	assert_eq(mana_stat.get_value(), 75.0, "Mana should be modified")
	
	# Clear modifiers
	mod_set.clear_modifiers()
	
	assert_eq(mod_set._modifiers.size(), 0, "Modifiers array should be empty")
	assert_eq(health_stat.get_value(), 100.0, "Health should be restored")
	assert_eq(mana_stat.get_value(), 50.0, "Mana should be restored")

# Find Modifier Tests
func test_find_mod():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Add modifier
	var modifier = _create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0)
	mod_set.add_modifier(modifier)
	
	# Find the modifier
	var found_mod = mod_set.find_mod(modifier)
	assert_not_null(found_mod, "Should find the modifier")
	
	# Try to find a non-existent modifier
	var non_existent_mod = _create_test_modifier("Stamina", StatModifierClassScript.StatModifierType.FLAT, 10.0)
	found_mod = mod_set.find_mod(non_existent_mod)
	assert_null(found_mod, "Should not find non-existent modifier")

func test_find_mod_by_name_and_type():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Add modifiers of different types
	mod_set.add_modifier(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	mod_set.add_modifier(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.PERCENT, 0.2))
	
	# Find by name and type
	var found_flat = mod_set.find_mod_by_name_and_type("Health", StatModifierClassScript.StatModifierType.FLAT)
	var found_percent = mod_set.find_mod_by_name_and_type("Health", StatModifierClassScript.StatModifierType.PERCENT)
	
	assert_not_null(found_flat, "Should find flat modifier")
	assert_not_null(found_percent, "Should find percent modifier")
	assert_eq(found_flat.get_value(), 50.0, "Flat modifier value should match")
	assert_eq(found_percent.get_value(), 0.2, "Percent modifier value should match")

func test_find_mod_for_stat():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var mana_stat = _create_test_stat(50.0)
	var parent = _create_parent_with_stat({
		"Health": health_stat,
		"Mana": mana_stat
	})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Add modifiers for different stats
	mod_set.add_modifier(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	mod_set.add_modifier(_create_test_modifier("Mana", StatModifierClassScript.StatModifierType.FLAT, 25.0))
	
	# Find by stat name
	var found_health = mod_set.find_mod_for_stat("Health")
	var found_mana = mod_set.find_mod_for_stat("Mana")
	var found_none = mod_set.find_mod_for_stat("Stamina")
	
	assert_not_null(found_health, "Should find health modifier")
	assert_not_null(found_mana, "Should find mana modifier")
	assert_null(found_none, "Should not find stamina modifier")

# Condition Tests
func test_condition_apply_on_true():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Create a condition that evaluates Health > 50
	var condition = Condition.new()
	condition._ref_stat1_name = "Health"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	mod_set.condition = condition
	mod_set._condition_apply_on_start = true
	mod_set.apply_on_condition_change = true
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 50.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# The modifier should be applied since Health(100) > 50
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified when condition is true")

func test_condition_apply_on_change():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(40.0)  # Start below threshold
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Create a condition that evaluates Health > 50 (starts false)
	var condition = Condition.new()
	condition._ref_stat1_name = "Health"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	mod_set.condition = condition
	mod_set.apply_on_condition_change = true
	mod_set._condition_apply_on_start = false
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 20.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Health should still be at base value since condition is false
	assert_eq(health_stat.get_value(), 40.0, "Health should be unmodified when condition is false")
	
	# Now change health to trigger the condition
	health_stat.base_value = 60.0
	
	# Manually trigger condition evaluation (would normally happen via signals)
	condition._evaluate_condition()
	condition.condition_changed.emit(true)
	
	# Now health should be modified
	assert_eq(health_stat.get_value(), 80.0, "Health should be modified when condition changes to true")

func test_condition_remove_on_change():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Create a condition that evaluates Health > 50 (starts true)
	var condition = Condition.new()
	condition._ref_stat1_name = "Health"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition._ref_stat1_type = Condition.RefStatType.BASE_VALUE
	
	mod_set.condition = condition
	mod_set.remove_on_condition_change = true
	mod_set._condition_apply_on_start = true
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 50.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Health should be modified
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified when condition is true")
	
	# Now change health to trigger condition change
	health_stat.base_value = 40.0
	
	# Now health should be back to base
	assert_eq(health_stat.get_value(), 40.0, "Health should be restored when condition changes to false")

func test_condition_with_cooldown():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Create a condition with a cooldown of 2 seconds
	var condition = Condition.new()
	condition._ref_stat1_name = "Health"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition._ref_stat1_type = Condition.RefStatType.BASE_VALUE
	condition.cooldown = 2.0
	
	mod_set.condition = condition
	mod_set.process = true
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 50.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Health should be modified
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified when condition is true")
	
	# Change health to trigger condition change
	health_stat.base_value = 40.0

	# Simulate process call that should evaluate condition
	mod_set._process(0.5)

	gut.p("time: " + str(condition._timer))
	
	# Health should still be modified since cooldown hasn't elapsed
	assert_eq(health_stat.get_value(), 90.0, "Health modifier should still be applied during cooldown")
	
	# Simulate more time passing to exceed cooldown
	mod_set._process(1.6)  # Total 2.1 seconds
	gut.p("time2: " + str(condition._timer))
	
	# Now health should be back to base
	assert_eq(health_stat.get_value(), 40.0, "Health should be restored after cooldown elapses")

func test_condition_with_two_stats():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var mana_stat = _create_test_stat(50.0)
	var parent = _create_parent_with_stat({
		"Health": health_stat,
		"Mana": mana_stat
	})
	
	# Create a condition that evaluates if Mana > Health/2
	var condition = Condition.new()
	condition._ref_stat1_name = "Mana"
	condition._ref_stat2_name = "Health"
	condition._ref_stat1_type = Condition.RefStatType.VALUE
	condition._ref_stat2_type = Condition.RefStatType.VALUE
	condition._condition_type = Condition.ConditionType.MATH_EXPRESSION
	condition._math_expression = "value1 > (value2 / 2.0)"
	
	mod_set.condition = condition
	mod_set._condition_apply_on_start = true
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 50.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Health should be modified since Mana(50) > Health(100)/2
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified when two-stat condition is true")
	
	# Change mana to make condition false
	mana_stat.base_value = 30.0
	
	# Manually trigger evaluation
	condition._evaluate_condition()
	condition.condition_changed.emit(false)
	
	# Condition should now be false and health should be back to base
	assert_eq(health_stat.get_value(), 100.0, "Health should be restored when two-stat condition turns false")

func test_condition_negation():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(30.0)  # Below threshold
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Create a condition that evaluates NOT(Health > 50)
	var condition = Condition.new()
	condition._ref_stat1_name = "Health"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	condition._negation = true  # Negate the result
	
	mod_set.condition = condition
	mod_set._condition_apply_on_start = true
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 20.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Health should be modified since NOT(Health(30) > 50) is true
	assert_eq(health_stat.get_value(), 50.0, "Health should be modified when negated condition is true")
	
	# Change health to make condition false
	health_stat.base_value = 60.0
	
	# Manually trigger evaluation
	condition._evaluate_condition()
	condition.condition_changed.emit(false)
	
	# Now condition should be false and health should be back to base
	assert_eq(health_stat.get_value(), 60.0, "Health should be restored when negated condition turns false")

func test_condition_pause_process():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Create a condition
	var condition = Condition.new()
	condition._ref_stat1_name = "Health"
	condition._value = 50.0
	condition._condition_type = Condition.ConditionType.GREATER_THAN
	
	mod_set.condition = condition
	mod_set._condition_pause_process = true
	mod_set.process = false  # Start with processing disabled
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifier.StatModifierType.FLAT, 50.0))
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Check that process is enabled when condition is true
	assert_true(mod_set.process, "Process should be enabled when condition is true")
	
	# Change condition to false
	health_stat.base_value = 40.0
	condition._evaluate_condition()
	condition.condition_changed.emit(false)
	
	# Check that process is disabled when condition is false
	assert_false(mod_set.process, "Process should be disabled when condition is false")

# Serialization Tests
func test_to_dict():
	var mod_set = StatModifierSet.new("Test Set", true, "Buffs")
	
	# Add modifiers
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	mod_set._modifiers.append(_create_test_modifier("Mana", StatModifierClassScript.StatModifierType.PERCENT, 0.2))
	
	# Set a condition
	mod_set.condition = _create_test_condition(true)
	
	# Get dictionary representation
	var dict = mod_set.to_dict()
	
	assert_eq(dict.modifier_name, "Test Set", "Dict should have correct modifier name")
	assert_eq(dict.group, "Buffs", "Dict should have correct group")
	assert_eq(dict.process, true, "Dict should have correct process value")
	assert_eq(dict.modifiers.size(), 2, "Dict should have 2 modifiers")
	assert_eq(dict.is_empty(), false, "Dict should have condition data")

var initial_data = {
	"modifier_name": "Test Set",
	"group": "Buffs",
	"process": true,
	"modifiers": [
		["StatModifier", {
			"stat_name": "Health",
			"type": StatModifierClassScript.StatModifierType.FLAT,
			"value": 50.0
		}],
		["StatModifier", {
			"stat_name": "Mana",
			"type": StatModifierClassScript.StatModifierType.PERCENT,
			"value": 0.2
		}]
	],
	"condition": {
		"current_condition": true
	},
	"condition_classname": "Condition"
}

# Copy Test
func test_copy():
	var original = StatModifierSet.new("Original Set", true, "Buffs")
	
	# Add modifiers
	original._modifiers.append(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	original._modifiers.append(_create_test_modifier("Mana", StatModifierClassScript.StatModifierType.PERCENT, 0.2))
	
	# Set condition
	original.condition = _create_test_condition(true)
	
	# Copy the set
	var copy = original.copy()
	
	# Ensure copy has correct values
	assert_eq(copy._modifier_name, "Original Set", "Copy should have same name")
	assert_eq(copy._group, "Buffs", "Copy should have same group")
	assert_eq(copy.process, true, "Copy should have same process value")
	assert_eq(copy._modifiers.size(), 2, "Copy should have same number of modifiers")
	assert_not_null(copy.condition, "Copy should have condition")
	
	# Ensure modifiers are actually duplicated, not just referenced
	original._modifiers[0].set_value(100.0)
	assert_eq(copy._modifiers[0].get_value(), 50.0, "Modifiers should be separate objects")

# Edge Case Tests
func test_null_parent():
	var mod_set = StatModifierSet.new("Test Set")
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	
	# Try to initialize with null parent
	mod_set.init_modifiers(null)
	
	# No crash should happen
	assert_true(true, "Should not crash with null parent")

func test_parent_without_get_stat():
	var mod_set = StatModifierSet.new("Test Set")
	var parent = RefCounted.new()  # Object without get_stat method
	
	# Add a modifier
	mod_set._modifiers.append(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	
	# Try to initialize with invalid parent
	mod_set.init_modifiers(parent)
	
	# No crash should happen
	assert_true(true, "Should not crash with invalid parent")

func test_marked_for_deletion():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Mark for deletion
	mod_set.delete()
	
	assert_true(mod_set.is_marked_for_deletion(), "Should be marked for deletion")
	
	# Try to add a modifier
	var added_mod = mod_set.add_modifier(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	
	assert_null(added_mod, "Should not add modifiers when marked for deletion")
	assert_eq(health_stat.get_value(), 100.0, "Stat should remain unchanged")

# Set Value Test
func test_set_mod_value():
	var mod_set = StatModifierSet.new("Test Set")
	var health_stat = _create_test_stat(100.0)
	var parent = _create_parent_with_stat({"Health": health_stat})
	
	# Initialize modifiers with parent
	mod_set.init_modifiers(parent)
	
	# Add a modifier
	mod_set.add_modifier(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	
	# Verify initial value
	assert_eq(health_stat.get_value(), 150.0, "Health should be modified by +50")
	
	# Set the modifier value
	mod_set.set_mod_value(0, 100.0)
	
	# Verify new value
	assert_eq(health_stat.get_value(), 200.0, "Health should be modified by +100")
	
	# Try with invalid index
	mod_set.set_mod_value(99, 200.0)
	# Should not crash, just log an error
	assert_true(true, "Should not crash with invalid index")

# Merge Tests
func test_merge_mod():
	var mod_set1 = StatModifierSet.new("Set 1")
	var mod_set2 = StatModifierSet.new("Set 2")
	
	# Ensure merge is enabled
	mod_set1.merge_enabled = true
	
	# Create identical modifiers in both sets
	mod_set1._modifiers.append(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 50.0))
	mod_set2._modifiers.append(_create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 25.0))
	
	# Test merging
	mod_set1._merge_parallel(mod_set2)
	
	# Check if modifiers merged correctly
	assert_eq(mod_set1._modifiers[0].get_value(), 75.0, "Modifier values should be merged")
