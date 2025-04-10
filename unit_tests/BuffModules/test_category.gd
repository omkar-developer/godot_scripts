extends GutTest

# Test suite for BMMCategory class
class_name TestBMMCategory

# Helper objects
var StatModifierClassScript := StatModifier
var StatModifierSetClassScript := StatModifierSet
var BMModuleClassScript := BMModule
var BMMCategoryClassScript := BMMCategory

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

## Test initialization
func test_initialization():
	var category_module = BMMCategory.new()
	
	assert_eq(category_module._categories.size(), 0, "Categories dictionary should be empty on initialization")

## Test category assignment
func test_set_get_category():
	var category_module = BMMCategory.new()
	var buff_manager = BuffManager.new()
	category_module.init(buff_manager)
	
	# Set category for a modifier
	category_module.set_category("SpeedBuff", BMMCategory.Category.POSITIVE)
	
	# Get category for the modifier
	var category = category_module.get_category("SpeedBuff")
	
	assert_eq(category, BMMCategory.Category.POSITIVE, "Should return the correct category for the modifier")
	
	# Get category for non-existent modifier
	var default_category = category_module.get_category("NonExistentBuff")
	
	assert_eq(default_category, BMMCategory.Category.NEUTRAL, 
			 "Should return NEUTRAL category for non-existent modifier")
	
	# Cleanup
	buff_manager.free()

## Test remove_category
func test_remove_category():
	var category_module = BMMCategory.new()
	var buff_manager = autofree(BuffManager.new())
	var parent = autofree(create_parent_with_stat({}))
	
	parent.add_child(buff_manager)
	buff_manager._parent = parent
	category_module.init(buff_manager)
	
	# Create and apply modifiers with different categories
	var mod_set1 = create_test_modifier_set("PositiveBuff1")
	var mod_set2 = create_test_modifier_set("PositiveBuff2")
	var mod_set3 = create_test_modifier_set("NegativeBuff")
	
	buff_manager.apply_modifier(mod_set1)
	buff_manager.apply_modifier(mod_set2)
	buff_manager.apply_modifier(mod_set3)
	
	# Set categories
	category_module.set_category("PositiveBuff1", BMMCategory.Category.POSITIVE)
	category_module.set_category("PositiveBuff2", BMMCategory.Category.POSITIVE)
	category_module.set_category("NegativeBuff", BMMCategory.Category.NEGATIVE)
	
	# Track removals
	var removed_modifiers = {
		"PositiveBuff1": false,
		"PositiveBuff2": false,
		"NegativeBuff": false
	}
	buff_manager.modifier_removed.connect(func(_name, _mod):
		if removed_modifiers.has(_name):
			removed_modifiers[_name] = true
	)
	
	# Remove POSITIVE category
	category_module.remove_category(BMMCategory.Category.POSITIVE)
	
	# Check if positive buffs were removed
	assert_true(removed_modifiers["PositiveBuff1"], "PositiveBuff1 should be removed")
	assert_true(removed_modifiers["PositiveBuff2"], "PositiveBuff2 should be removed")
	assert_false(removed_modifiers["NegativeBuff"], "NegativeBuff should not be removed")
	assert_false(buff_manager.has_modifier("PositiveBuff1"), "PositiveBuff1 should be removed from manager")
	assert_false(buff_manager.has_modifier("PositiveBuff2"), "PositiveBuff2 should be removed from manager")
	assert_true(buff_manager.has_modifier("NegativeBuff"), "NegativeBuff should still exist in manager")
	
	# Check if categories were erased
	assert_false(category_module._categories.has("PositiveBuff1"), 
				"PositiveBuff1 category should be erased")
	assert_false(category_module._categories.has("PositiveBuff2"), 
				"PositiveBuff2 category should be erased")
	assert_true(category_module._categories.has("NegativeBuff"), 
			   "NegativeBuff category should still exist")

## Test on_after_remove callback
func test_on_after_remove():
	var category_module = BMMCategory.new()
	var buff_manager = autofree(BuffManager.new())
	category_module.init(buff_manager)
	
	# Set category for a modifier
	category_module.set_category("TestBuff", BMMCategory.Category.POSITIVE)
	
	# Create mock modifier
	var mod_set = create_test_modifier_set("TestBuff")
	
	# Call on_after_remove
	category_module.on_after_remove(mod_set)
	
	# Check if category was erased
	assert_false(category_module._categories.has("TestBuff"), 
				"TestBuff category should be erased after removal")
