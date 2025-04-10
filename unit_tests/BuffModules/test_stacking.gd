extends GutTest

# Test suite for BMM_Stacking class
class_name TestBMMStacking

# Helper objects
var StatModifierClassScript := StatModifier
var StatModifierSetClassScript := StatModifierSet
var StatModifierSetTimedClassScript := StatModifierSetTimed
var StackConfigClassScript := StackConfig
var BMM_StackingClassScript := BMM_Stacking

## Helper function to create a parent object with a get_stat method
func create_parent_with_stat(stats: Dictionary) -> Node:
	# Create a new Node
	var parent = Node.new()
	# Add a script with a get_stat method
	var script = GDScript.new()
	script.source_code = """
extends Node
# The stat dictionary to hold stats by name
var _stats = {}
# Method to fetch the stat by name
func get_stat(stat_name: String):
	return _stats.get(stat_name)
"""
	script.reload()
	parent.set_script(script)
	# Set up the stats dictionary
	parent._stats = stats
	return parent

## Helper function to create a StatModifier for testing
func create_test_modifier(stat_name: String = "Health", 
						 type = StatModifierClassScript.StatModifierType.FLAT, 
						 value: float = 50.0) -> StatModifier:
	return StatModifier.new(stat_name, type, value)

## Helper function to create a StatModifierSet for testing
func create_test_modifier_set(mod_name: String = "TestModSet", 
							process: bool = false,
							group: String = "TestGroup") -> StatModifierSet:
	var mod_set = StatModifierSet.new(mod_name, process, group)
	return mod_set

## Helper function to create a StatModifierSetTimed for testing
func create_test_modifier_set_timed(mod_name: String = "TestModSet", 
								  duration: float = 10.0,
								  process: bool = true,
								  group: String = "TestGroup") -> StatModifierSetTimed:
	var mod_set = StatModifierSetTimed.new(mod_name, process, group, true, 00.0, 0.0, 3600.0, duration)
	return mod_set

## Test initialization
func test_initialization():
	var stacking_module = BMM_Stacking.new()
	
	assert_eq(stacking_module._stacks.size(), 0, "Stacks dictionary should be empty on initialization")
	assert_eq(stacking_module.stack_configs.size(), 0, "Stack configs array should be empty on initialization")

## Test adding stack config
func test_add_config():
	var stacking_module = BMM_Stacking.new()
	
	# Add config
	stacking_module.add_config("StackableBuff", 3, BMM_Stacking.STACK_BEHAVIOR_ADD)
	
	assert_eq(stacking_module.stack_configs.size(), 1, "Should have one stack config")
	assert_eq(stacking_module.stack_configs[0].modifier_name, "StackableBuff", "Config should have correct modifier name")
	assert_eq(stacking_module.stack_configs[0].max_stacks, 3, "Config should have correct max stacks")
	assert_eq(stacking_module.stack_configs[0].stack_behavior, BMM_Stacking.STACK_BEHAVIOR_ADD, "Config should have correct behavior")

## Test get_stack_count
func test_get_stack_count():
	var stacking_module = BMM_Stacking.new()
	
	# Set stack count
	stacking_module._stacks["StackableBuff"] = 2
	
	# Get stack count
	var count = stacking_module.get_stack_count("StackableBuff")
	
	assert_eq(count, 2, "Should return correct stack count")
	
	# Get non-existent stack count
	var default_count = stacking_module.get_stack_count("NonExistentBuff")
	
	assert_eq(default_count, 0, "Should return 0 for non-existent modifier")

## Test _get_stack_config
func test_get_stack_config():
	var stacking_module = BMM_Stacking.new()
	
	# Add config
	stacking_module.add_config("ConfiguredBuff", 3, BMM_Stacking.STACK_BEHAVIOR_REFRESH)
	
	# Get config for configured buff
	var config = stacking_module._get_stack_config("ConfiguredBuff")
	
	assert_eq(config.modifier_name, "ConfiguredBuff", "Should return correct config")
	assert_eq(config.max_stacks, 3, "Config should have correct max stacks")
	
	# Get config for non-configured buff
	var default_config = stacking_module._get_stack_config("DefaultBuff")
	
	assert_eq(default_config.modifier_name, "DefaultBuff", "Should return default config with correct name")
	assert_eq(default_config.max_stacks, 1, "Default config should have max_stacks = 1")
	assert_eq(default_config.stack_behavior, 0, "Default config should have default behavior")

## Test on_before_apply with first application
func test_on_before_apply_first_application():
	var stacking_module = BMM_Stacking.new()
	var buff_manager = autofree(BuffManager.new())
	var parent = autofree(create_parent_with_stat({}))
	
	parent.add_child(buff_manager)
	buff_manager._parent = parent
	stacking_module.init(buff_manager)
	
	# Create modifier
	var mod_set = create_test_modifier_set("NewBuff")
	
	# Process first application
	var result = stacking_module.on_before_apply(mod_set)
	
	assert_true(result, "First application should succeed")
	assert_eq(stacking_module._stacks["NewBuff"], 1, "Stack count should be set to 1")

## Test on_before_apply with max stacks reached
func test_on_before_apply_max_stacks():
	var stacking_module = BMM_Stacking.new()
	var buff_manager = autofree(BuffManager.new())
	var parent = autofree(create_parent_with_stat({}))
	
	parent.add_child(buff_manager)
	buff_manager._parent = parent
	stacking_module.init(buff_manager)
	
	# Add config with max 2 stacks
	stacking_module.add_config("LimitedBuff", 2)
	
	# Create modifier and add to manager (simulate first application)
	var mod_set = create_test_modifier_set("LimitedBuff")
	buff_manager.apply_modifier(mod_set)
	stacking_module._stacks["LimitedBuff"] = 2  # Set to max stacks
	
	# Create new instance of same modifier
	var new_mod_set = create_test_modifier_set("LimitedBuff")
	
	# Try to apply beyond max stacks
	var result = stacking_module.on_before_apply(new_mod_set)
	
	assert_false(result, "Application should be blocked when max stacks reached")

## Test on_before_apply with REFRESH behavior
func test_on_before_apply_refresh_behavior():
	var stacking_module = BMM_Stacking.new()
	var buff_manager = autofree(BuffManager.new())
	var parent = autofree(create_parent_with_stat({}))
	
	parent.add_child(buff_manager)
	buff_manager._parent = parent
	stacking_module.init(buff_manager)
	
	# Add config with REFRESH behavior
	stacking_module.add_config("RefreshBuff", 2, BMM_Stacking.STACK_BEHAVIOR_REFRESH)
	
	# Create original modifier with Health +10
	var original_mod = create_test_modifier_set("RefreshBuff")
	original_mod.add_modifier(create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 10.0))
	
	# Apply to manager
	buff_manager.apply_modifier(original_mod)
	stacking_module._stacks["RefreshBuff"] = 1
	
	# Create new instance with Health +20
	var new_mod = create_test_modifier_set("RefreshBuff")
	new_mod.add_modifier(create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 20.0))
	
	# Apply second stack
	var result = stacking_module.on_before_apply(new_mod)
	
	assert_true(result, "Application should succeed")
	assert_eq(stacking_module._stacks["RefreshBuff"], 2, "Stack count should be incremented")

## Test on_before_apply with ADD behavior
func test_on_before_apply_add_behavior():
	var stacking_module = BMM_Stacking.new()
	var buff_manager = autofree(BuffManager.new())
	var parent = autofree(create_parent_with_stat({}))
	
	parent.add_child(buff_manager)
	buff_manager._parent = parent
	stacking_module.init(buff_manager)
	
	# Add config with ADD behavior
	stacking_module.add_config("AddBuff", 3, BMM_Stacking.STACK_BEHAVIOR_ADD)
	
	# Create original timed modifier with 10s duration
	var original_mod = create_test_modifier_set_timed("AddBuff", 10.0)
	
	# Apply to manager
	buff_manager.apply_modifier(original_mod)
	stacking_module._stacks["AddBuff"] = 1
	
	# Create new instance with 5s duration
	var new_mod = create_test_modifier_set_timed("AddBuff", 5.0)
	
	# Apply second stack
	var result = stacking_module.on_before_apply(new_mod)
	
	assert_true(result, "Application should succeed")
	assert_eq(stacking_module._stacks["AddBuff"], 2, "Stack count should be incremented")

## Test on_before_apply with INDEPENDENT behavior
func test_on_before_apply_independent_behavior():
	var stacking_module = BMM_Stacking.new()
	var buff_manager = autofree(BuffManager.new())
	var parent = autofree(create_parent_with_stat({}))
	
	parent.add_child(buff_manager)
	buff_manager._parent = parent
	stacking_module.init(buff_manager)
	
	# Add config with INDEPENDENT behavior
	stacking_module.add_config("IndependentBuff", 3, BMM_Stacking.STACK_BEHAVIOR_INDEPENDENT)
	
	# Create modifier
	var mod_set = create_test_modifier_set("IndependentBuff")
	
	# Apply to manager
	buff_manager.apply_modifier(mod_set)
	stacking_module._stacks["IndependentBuff"] = 1
	
	# Create new instance
	var new_mod = create_test_modifier_set("IndependentBuff")
	
	# Apply second stack
	var result = stacking_module.on_before_apply(new_mod)
	
	assert_true(result, "Application should succeed")
	assert_eq(stacking_module._stacks["IndependentBuff"], 2, "Stack count should be incremented")
	assert_eq(new_mod._modifier_name, "IndependentBuff1", 
			  "Modifier name should be changed to include stack number")

## Test on_after_remove
func test_on_after_remove():
	var stacking_module = BMM_Stacking.new()
	
	# Set up stacks
	stacking_module._stacks["BaseBuff"] = 3
	
	# Create modifier that is being removed
	var mod_set = create_test_modifier_set("BaseBuff")  # This would be the 3rd stack with index 2
	
	# Call on_after_remove
	stacking_module.on_after_remove(mod_set)
	
	# Check if stack entry was removed
	assert_false(stacking_module._stacks.has("BaseBuff"), "Stack entry should be removed")
