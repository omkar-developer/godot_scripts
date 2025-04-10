extends GutTest

# Test suite for BMMResistance class
class_name TestBMMResistance

# Helper objects
var StatModifierClassScript := StatModifier
var StatModifierSetClassScript := StatModifierSet
var BMModuleClassScript := BMModule
var BMMResistanceClassScript := BMMResistance

## Helper function to create a StatModifierSet for testing
func create_test_modifier_set(mod_name: String = "TestModSet", 
							process: bool = false,
							group: String = "TestGroup") -> StatModifierSet:
	var mod_set = StatModifierSet.new(mod_name, process, group)
	return mod_set

## Helper function to create a StatModifier for testing
func create_test_modifier(stat_name: String = "Health", 
						 type = StatModifierClassScript.StatModifierType.FLAT, 
						 value: float = 50.0) -> StatModifier:
	return StatModifier.new(stat_name, type, value)

## Test initialization
func test_initialization():
	var resistance_module = BMMResistance.new()
	
	assert_eq(resistance_module._immunities.size(), 0, "Immunities dictionary should be empty on initialization")
	assert_eq(resistance_module._resistances.size(), 0, "Resistances dictionary should be empty on initialization")

## Test adding immunity
func test_add_immunity():
	var resistance_module = BMMResistance.new()
	
	# Add immunity
	resistance_module.add_immunity("SlowDebuff", 5.0)
	
	assert_true(resistance_module._immunities.has("SlowDebuff"), "Should have immunity for SlowDebuff")
	assert_eq(resistance_module._immunities["SlowDebuff"], 5.0, "Should have correct duration for immunity")

## Test setting resistance
func test_set_resistance():
	var resistance_module = BMMResistance.new()
	
	# Set resistance
	resistance_module.set_resistance("PoisonDebuff", 75.0)
	
	assert_true(resistance_module._resistances.has("PoisonDebuff"), "Should have resistance for PoisonDebuff")
	assert_eq(resistance_module._resistances["PoisonDebuff"], 75.0, "Should have correct resistance percentage")
	
	# Test clamping of resistance values
	resistance_module.set_resistance("OvercappedDebuff", 150.0)
	assert_eq(resistance_module._resistances["OvercappedDebuff"], 100.0, "Resistance should be clamped to 100%")
	
	resistance_module.set_resistance("NegativeDebuff", -10.0)
	assert_eq(resistance_module._resistances["NegativeDebuff"], 0.0, "Resistance should be clamped to 0%")

## Test on_before_apply with immunity
func test_on_before_apply_immunity():
	var resistance_module = BMMResistance.new()
	var buff_manager = autofree(BuffManager.new())
	resistance_module.init(buff_manager)
	
	# Add immunity
	resistance_module.add_immunity("ImmuneDebuff", 5.0)
	
	# Create modifier
	var mod_set = create_test_modifier_set("ImmuneDebuff")
	
	# Test immunity blocking
	var result = resistance_module.on_before_apply(mod_set)
	
	assert_false(result, "Modifier application should be blocked due to immunity")

## Test on_before_apply with resistance
func test_on_before_apply_resistance():
	var resistance_module = BMMResistance.new()
	var buff_manager = autofree(BuffManager.new())
	resistance_module.init(buff_manager)
	
	# Subclass resistance module to control randomness for testing
	var test_resistance = BMMResistance.new()
	var script = GDScript.new()
	script.source_code = """
extends BMMResistance

# Override randf for testing
func _test_randf(value: float) -> float:
	return value

func on_before_apply(modifier: StatModifierSet) -> bool:
	var modifier_name = modifier._modifier_name
	
	# Check immunity
	if _immunities.has(modifier_name):
		return false
	
	# Check resistance
	if _resistances.has(modifier_name):
		var resistance = _resistances[modifier_name]
		if _test_randf(0.5) * 100.0 <= resistance:
			return false
	
	return true
"""
	script.reload()
	test_resistance.set_script(script)
	test_resistance.init(buff_manager)
	
	# Set resistance at 75%
	test_resistance.set_resistance("ResistDebuff", 75.0)
	
	# Create modifier
	var mod_set = create_test_modifier_set("ResistDebuff")
	
	# With randf = 0.5 (50%) and resistance = 75%, application should be blocked
	var result = test_resistance.on_before_apply(mod_set)
	
	assert_false(result, "Modifier application should be blocked due to resistance")
	
	# Set resistance at 25%
	test_resistance.set_resistance("LowResistDebuff", 25.0)
	
	# Create modifier
	var low_mod_set = create_test_modifier_set("LowResistDebuff")
	
	# With randf = 0.5 (50%) and resistance = 25%, application should succeed
	result = test_resistance.on_before_apply(low_mod_set)
	
	assert_true(result, "Modifier application should succeed with low resistance")

## Test process method for updating immunity durations
func test_process_update_immunities():
	var resistance_module = BMMResistance.new()
	var buff_manager = autofree(BuffManager.new())
	resistance_module.init(buff_manager)
	
	# Add immunities with different durations
	resistance_module.add_immunity("ShortImmunity", 1.0)
	resistance_module.add_immunity("LongImmunity", 3.0)
	
	# Process for 0.5 seconds
	resistance_module.process(0.5)
	
	# Check updated durations
	assert_eq(resistance_module._immunities["ShortImmunity"], 0.5, "ShortImmunity duration should decrease")
	assert_eq(resistance_module._immunities["LongImmunity"], 2.5, "LongImmunity duration should decrease")
	
	# Process for 1 more second
	resistance_module.process(1.0)
	
	# Check if expired immunity was removed
	assert_false(resistance_module._immunities.has("ShortImmunity"), "Expired immunity should be removed")
	assert_true(resistance_module._immunities.has("LongImmunity"), "Longer immunity should still exist")
	assert_eq(resistance_module._immunities["LongImmunity"], 1.5, "LongImmunity duration should continue to decrease")
