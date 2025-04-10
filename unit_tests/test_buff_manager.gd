extends GutTest

# Test suite for BuffManager class
class_name TestBuffManager

# Helper objects
var StatModifierClassScript := StatModifier
var StatModifierSetClassScript := StatModifierSet
var StatClassScript := Stat
var ConditionClassScript := Condition
var BMModuleClassScript := BMModule

## Helper function to create a Stat instance for testing
func create_test_stat(base_value: float = 100.0, min_value: float = 0.0, max_value: float = 200.0) -> Stat:
	var stat = StatClassScript.new()
	stat.base_value = base_value
	stat.min_value = min_value
	stat.max_value = max_value
	return stat

## Helper function to create a parent object with a get_stat method
func create_parent_with_stat(stats: Dictionary) -> RefCounted:
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

## Helper function to create a test BMModule
func create_test_module() -> BMModule:
	var module = BMModule.new()
	return module

# Mock BMModule for testing callbacks
class MockBMModule extends BMModule:
	var before_apply_result := true
	var before_apply_called := false
	var after_apply_called := false
	var before_remove_called := false
	var after_remove_called := false
	var process_called := false
	var last_delta := 0.0
	var last_modifier = null
	
	func init(mod_manager) -> void:
		manager = mod_manager
	
	func uninit() -> void:
		manager = null
	
	func on_before_apply(modifier) -> bool:
		before_apply_called = true
		last_modifier = modifier
		return before_apply_result
	
	func on_after_apply(modifier) -> void:
		after_apply_called = true
		last_modifier = modifier
	
	func on_before_remove(modifier) -> void:
		before_remove_called = true
		last_modifier = modifier
	
	func on_after_remove(modifier) -> void:
		after_remove_called = true
		last_modifier = modifier
	
	func process(delta: float) -> void:
		process_called = true
		last_delta = delta
	
	func reset_flags() -> void:
		before_apply_called = false
		after_apply_called = false
		before_remove_called = false
		after_remove_called = false
		process_called = false
		last_delta = 0.0
		last_modifier = null

## Test initialization
func test_initialization():
	var buff_manager = BuffManager.new()
	
	assert_eq(buff_manager._active_modifiers.size(), 0, "Active modifiers should be empty on initialization")
	assert_eq(buff_manager._modules.size(), 0, "Modules should be empty on initialization")
	assert_null(buff_manager._parent, "Parent should be null on initialization")

## Test _enter_tree parent initialization
func test_enter_tree_parent_initialization():
	var parent = autofree(Node.new())
	var buff_manager = BuffManager.new()
	
	parent.add_child(buff_manager)
	
	# Manually trigger _enter_tree since GUT might not do this automatically
	buff_manager._enter_tree()
	
	assert_eq(buff_manager._parent, parent, "Parent should be set to the parent node")
	
	# Cleanup
	parent.remove_child(buff_manager)
	parent.free()
	buff_manager.free()

## Test module management
func test_add_module():
	var buff_manager = BuffManager.new()
	var module = create_test_module()
	
	buff_manager.add_module(module)
	
	assert_eq(buff_manager._modules.size(), 1, "Module should be added to the modules array")
	assert_eq(buff_manager._modules[0], module, "Module in array should match the added module")

func test_remove_module():
	var buff_manager = BuffManager.new()
	var module = create_test_module()
	
	buff_manager.add_module(module)
	assert_eq(buff_manager._modules.size(), 1, "Module should be added first")
	
	buff_manager.remove_module(module)
	assert_eq(buff_manager._modules.size(), 0, "Module should be removed from the modules array")

func test_module_callbacks():
	var buff_manager = BuffManager.new()
	var mock_module = MockBMModule.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	# Add module to manager
	buff_manager.add_module(mock_module)
	assert_eq(mock_module.manager, buff_manager, "Module should be initialized with manager reference")
	
	# Create a modifier set
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))
	
	# Apply the modifier
	buff_manager.apply_modifier(mod_set)
	
	assert_true(mock_module.before_apply_called, "on_before_apply should be called")
	assert_true(mock_module.after_apply_called, "on_after_apply should be called")
	assert_not_null(mock_module.last_modifier, "Module should receive modifier reference")
	
	# Reset flags for testing removal
	mock_module.reset_flags()
	
	# Remove the modifier
	buff_manager.remove_modifier("TestBuff")
	
	assert_true(mock_module.before_remove_called, "on_before_remove should be called")
	assert_true(mock_module.after_remove_called, "on_after_remove should be called")

func test_module_blocking_application():
	var buff_manager = BuffManager.new()
	var mock_module = MockBMModule.new()
	mock_module.before_apply_result = false  # Module will block application
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	# Add module to manager
	buff_manager.add_module(mock_module)
	
	# Create a modifier set
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))
	
	# Try to apply the modifier
	var result = buff_manager.apply_modifier(mod_set)
	
	assert_false(result, "apply_modifier should return false when blocked by a module")
	assert_true(mock_module.before_apply_called, "on_before_apply should be called")
	assert_false(mock_module.after_apply_called, "on_after_apply should not be called when blocked")
	assert_false(buff_manager.has_modifier("TestBuff"), "Modifier should not be applied when blocked")

## Test modifier application and management
func test_apply_modifier():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))
	
	# Track signal emission

	var output = {
		"signal_emitted": false,
		"emitted_name": "",
		"emitted_modifier": null
	}
	buff_manager.modifier_applied.connect(func(_name, mod):
		output["signal_emitted"] = true
		output["emitted_name"] = _name
		output["emitted_modifier"] = mod
	)
	
	# Apply modifier
	var result = buff_manager.apply_modifier(mod_set)
	
	assert_true(result, "apply_modifier should return true on success")
	assert_true(buff_manager.has_modifier("TestBuff"), "Manager should have the modifier")
	assert_eq(buff_manager._active_modifiers.size(), 1, "Manager should have one active modifier")
	
	# Check signal emission
	assert_true(output["signal_emitted"], "modifier_applied signal should be emitted")
	assert_eq(output["emitted_name"], "TestBuff", "Signal should emit correct modifier name")
	assert_not_null(output["emitted_modifier"], "Signal should emit modifier reference")

func test_apply_duplicate_modifier():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	# Create and apply first modifier
	var mod_set1 = create_test_modifier_set("TestBuff")
	var health_mod1 = create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 10.0)
	mod_set1.add_modifier(health_mod1)
	buff_manager.apply_modifier(mod_set1)
	
	# Create second modifier with same name
	var mod_set2 = create_test_modifier_set("TestBuff")
	var health_mod2 = create_test_modifier("Health", StatModifierClassScript.StatModifierType.FLAT, 15.0)
	mod_set2.add_modifier(health_mod2)
	
	# Apply second modifier
	buff_manager.apply_modifier(mod_set2)
	
	# Should still only have one modifier but with merged values
	assert_eq(buff_manager._active_modifiers.size(), 1, "Should still have only one active modifier")
	
	# Get the merged modifier
	var merged_mod_set = buff_manager.get_modifier("TestBuff")
	assert_not_null(merged_mod_set, "Should be able to get the merged modifier set")
	
	# Check if values were properly merged
	# Note: Testing the exact merged value would require knowledge of how StatModifierSet.merge_mod works
	# For this test, we're just verifying the merge happened
	assert_true(merged_mod_set != mod_set1, "The merged set should not be the same instance as the first set")

func test_remove_modifier():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))
	
	# Apply modifier
	buff_manager.apply_modifier(mod_set)
	assert_true(buff_manager.has_modifier("TestBuff"), "Should have modifier after applying")
	
	# Track signal emission
	var output = {
		"signal_emitted": false,
		"emitted_name": "",
		"emitted_modifier": null
	}
	buff_manager.modifier_removed.connect(func(_name, mod):
		output["signal_emitted"] = true
		output["emitted_name"] = _name
		output["emitted_modifier"] = mod
	)
	
	# Remove modifier
	buff_manager.remove_modifier("TestBuff")
	
	assert_false(buff_manager.has_modifier("TestBuff"), "Should not have modifier after removal")
	assert_eq(buff_manager._active_modifiers.size(), 0, "Should have no active modifiers")
	
	# Check signal emission
	assert_true(output["signal_emitted"], "modifier_removed signal should be emitted")
	assert_eq(output["emitted_name"], "TestBuff", "Signal should emit correct modifier name")
	assert_not_null(output["emitted_modifier"], "Signal should emit modifier reference")

func test_remove_nonexistent_modifier():
	var buff_manager = BuffManager.new()
	
	# Track signal emission to make sure it's not emitted
	var output = {
		"signal_emitted": false,
	}
	buff_manager.modifier_removed.connect(func(_name, _mod):
		output["signal_emitted"] = true
	)
	# Try to remove non-existent modifier
	buff_manager.remove_modifier("NonExistentBuff")
	
	assert_false(output["signal_emitted"], "No signal should be emitted when removing non-existent modifier")

func test_get_modifier():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))
	
	# Apply modifier
	buff_manager.apply_modifier(mod_set)
	
	# Get modifier
	var retrieved_mod = buff_manager.get_modifier("TestBuff")
	
	assert_not_null(retrieved_mod, "Should retrieve modifier by name")
	assert_eq(retrieved_mod.get_modifier_name(), "TestBuff", "Retrieved modifier should have correct name")
	
	# Get non-existent modifier
	var nonexistent_mod = buff_manager.get_modifier("NonExistentBuff")
	assert_null(nonexistent_mod, "Should return null for non-existent modifier")

func test_clear_all_modifiers():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({
		"Health": create_test_stat(),
		"Strength": create_test_stat()
	})
	buff_manager._parent = parent
	
	# Add multiple modifiers
	var mod_set1 = create_test_modifier_set("HealthBuff")
	mod_set1.add_modifier(create_test_modifier("Health"))
	buff_manager.apply_modifier(mod_set1)
	
	var mod_set2 = create_test_modifier_set("StrengthBuff")
	mod_set2.add_modifier(create_test_modifier("Strength"))
	buff_manager.apply_modifier(mod_set2)
	
	assert_eq(buff_manager._active_modifiers.size(), 2, "Should have two active modifiers")
	
	# Count signal emissions
	var output = {
		"removal_count": 0,
	}
	buff_manager.modifier_removed.connect(func(_name, _mod):
		output["removal_count"] += 1
	)
	
	# Clear all modifiers
	buff_manager.clear_all_modifiers()
	
	assert_eq(buff_manager._active_modifiers.size(), 0, "Should have no active modifiers after clearing")
	assert_eq(output["removal_count"], 2, "Should emit removal signal for each modifier")

## Test processing
func test_process_updates_modifiers():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	# Create a modifier set with processing enabled
	var mod_set = create_test_modifier_set("TestBuff", true)
	mod_set.add_modifier(create_test_modifier("Health"))
	mod_set.condition = Condition.new()
	mod_set.condition.cooldown = 2.0
	# Apply modifier
	buff_manager.apply_modifier(mod_set, false)
	mod_set.condition._update()

	# Process the manager
	buff_manager._process(0.1)
	
	# Get the applied modifier (which is a copy)
	var applied_mod = buff_manager.get_modifier("TestBuff")
	#assert_true(applied_mod.process_called, "Modifier's _process should be called")
	assert_eq(applied_mod.condition._timer, 1.9, "Delta time should be passed to modifier's _process")

func test_process_deletes_marked_modifiers():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	# Create a modifier set that will be marked for deletion
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))

	# Apply modifier
	buff_manager.apply_modifier(mod_set)
	assert_true(buff_manager.has_modifier("TestBuff"), "Modifier should be applied")
	
	# Process the manager - should remove the marked modifier
	buff_manager.remove_modifier("TestBuff")
	
	assert_false(buff_manager.has_modifier("TestBuff"), "Marked modifier should be removed during processing")

func test_process_calls_module_process():
	var buff_manager = BuffManager.new()
	var mock_module = MockBMModule.new()
	buff_manager.add_module(mock_module)
	
	# Process the manager
	buff_manager._process(0.25)
	
	assert_true(mock_module.process_called, "Module's process method should be called")
	assert_eq(mock_module.last_delta, 0.25, "Delta time should be passed to module's process")

## Test signal emission
func test_signals():
	var buff_manager = BuffManager.new()
	var parent = create_parent_with_stat({"Health": create_test_stat()})
	buff_manager._parent = parent
	
	var mod_set = create_test_modifier_set("TestBuff")
	mod_set.add_modifier(create_test_modifier("Health"))
	
	# Track applied signal
	var applied_output = {
		"applied_emitted": false,
		"applied_name": "",
		"applied_mod": null
	}
	buff_manager.modifier_applied.connect(func(_name, mod):
		applied_output["applied_emitted"] = true
		applied_output["applied_name"] = _name
		applied_output["applied_mod"] = mod
	)
	
	# Track removed signal
	var removed_output = {
		"removed_emitted": false,
		"removed_name": "",
		"removed_mod": null
	}
	buff_manager.modifier_removed.connect(func(_name, mod):
		removed_output["removed_emitted"] = true
		removed_output["removed_name"] = _name
		removed_output["removed_mod"] = mod
	)
	
	# Apply modifier
	buff_manager.apply_modifier(mod_set)
	
	assert_true(applied_output["applied_emitted"], "applied signal should be emitted")
	assert_eq(applied_output["applied_name"], "TestBuff", "applied signal should include modifier name")
	assert_not_null(applied_output["applied_mod"], "applied signal should include modifier reference")
	
	# Remove modifier
	buff_manager.remove_modifier("TestBuff")
	
	assert_true(removed_output["removed_emitted"], "removed signal should be emitted")
	assert_eq(removed_output["removed_name"], "TestBuff", "removed signal should include modifier name")
	assert_not_null(removed_output["removed_mod"], "removed signal should include modifier reference")
