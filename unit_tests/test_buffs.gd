extends GutTest

# Practical integration tests for BuffManager with common game buff/debuff types
class_name PracticalBuffManagerTests

# Helper objects
var StatModifierClassScript := StatModifier
var StatModifierSetClassScript := StatModifierSet
var StatModifierSetTimedClassScript := StatModifierSetTimed
var StatClassScript := Stat
var ConditionClassScript := Condition
var BuffManagerClassScript := BuffManager

# Common stat values
const BASE_HEALTH := 100.0
const BASE_MANA := 50.0
const BASE_STRENGTH := 10.0
const BASE_DEFENSE := 5.0
const BASE_SPEED := 7.0
const BASE_INTELLIGENCE := 8.0

# Test game character class with stats
class TestCharacter extends Node:
	var stats := {}
	var buff_manager: BuffManager
	
	func _init() -> void:
		# Create common RPG stats
		stats["Health"] = Stat.new()
		stats["Health"].base_value = BASE_HEALTH
		stats["Health"].max_value = BASE_HEALTH
		
		stats["Mana"] = Stat.new()
		stats["Mana"].base_value = BASE_MANA
		stats["Mana"].max_value = BASE_MANA
		
		stats["Strength"] = Stat.new()
		stats["Strength"].base_value = BASE_STRENGTH
		
		stats["Defense"] = Stat.new()
		stats["Defense"].base_value = BASE_DEFENSE
		
		stats["Speed"] = Stat.new()
		stats["Speed"].base_value = BASE_SPEED
		
		stats["Intelligence"] = Stat.new()
		stats["Intelligence"].base_value = BASE_INTELLIGENCE
		
		# Initialize buff manager
		buff_manager = BuffManager.new()
		add_child(buff_manager)
		buff_manager._parent = self
	
	func get_stat(stat_name: String) -> Stat:
		return stats.get(stat_name)
	
	func get_damage_output() -> float:
		# Simple damage calculation for testing
		return stats["Strength"].get_value() * 1.5
	
	func get_defense_rating() -> float:
		# Simple defense calculation for testing
		return stats["Defense"].get_value() * 0.8
	
	func get_movement_speed() -> float:
		# Simple speed calculation
		return stats["Speed"].get_value()
	
	func get_magic_power() -> float:
		# Magic power calculation
		return stats["Intelligence"].get_value() * 1.2

# Helper function to create a StatModifierSet for a specific buff/debuff
func create_buff(_name: String, duration: float = 0.0) -> StatModifierSet:
	if duration > 0:
		# Use the actual StatModifierSetTimed class
		var modifier_set := StatModifierSetTimed.new(
			_name,          # modifier_name
			true,          # _process_every_frame
			"",            # group
			true,          # _apply_at_start
			0.0,           # _interval - no interval ticks, just duration
			0.0,           # _minimum_interval
			3600.0,        # _maximum_interval
			duration,      # _duration
			-1,            # _total_ticks - unlimited
			StatModifierSetTimed.MergeType.ADD_DURATION | StatModifierSetTimed.MergeType.ADD_VALUE,  # _merge_type
			true           # _remove_effect_on_finish
		)
		return modifier_set
	else:
		# Use regular StatModifierSet for non-timed buffs
		var modifier_set := StatModifierSet.new(_name, true)
		return modifier_set

# Duration-based buff module for testing timed buffs
class DurationBuffModule extends RefCounted:
	var manager = null
	
	func init(mod_manager) -> void:
		manager = mod_manager
	
	func uninit() -> void:
		manager = null
	
	func on_before_apply(_modifier) -> bool:
		return true
	
	func on_after_apply(_modifier) -> void:
		pass
	
	func on_before_remove(_modifier) -> void:
		pass
	
	func on_after_remove(_modifier) -> void:
		pass
	
	func process(_delta: float) -> void:
		pass

# Single-stat buff tests

func test_strength_buff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial damage output
	var initial_damage = character.get_damage_output()
	
	# Create a strength buff (+5 strength)
	var strength_buff = create_buff("StrengthBuff")
	var strength_mod = StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, 5.0)
	strength_buff.add_modifier(strength_mod)
	
	# Apply buff
	character.buff_manager.apply_modifier(strength_buff)
	
	# Check that strength is increased
	assert_eq(character.get_stat("Strength").get_value(), BASE_STRENGTH + 5.0, "Strength should be increased by 5")
	assert_gt(character.get_damage_output(), initial_damage, "Damage output should increase with strength buff")
	
	# Remove buff
	character.buff_manager.remove_modifier("StrengthBuff")
	
	# Check that strength is back to normal
	assert_eq(character.get_stat("Strength").get_value(), BASE_STRENGTH, "Strength should return to base value")
	assert_eq(character.get_damage_output(), initial_damage, "Damage output should return to initial value")
	
	character.queue_free()

func test_defense_debuff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial defense rating
	var initial_defense = character.get_defense_rating()
	
	# Create a defense debuff (-2 defense)
	var defense_debuff = create_buff("DefenseDebuff")
	var defense_mod = StatModifier.new("Defense", StatModifier.StatModifierType.FLAT, -2.0)
	defense_debuff.add_modifier(defense_mod)
	
	# Apply debuff
	character.buff_manager.apply_modifier(defense_debuff)
	
	# Check that defense is reduced
	assert_eq(character.get_stat("Defense").get_value(), BASE_DEFENSE - 2.0, "Defense should be decreased by 2")
	assert_lt(character.get_defense_rating(), initial_defense, "Defense rating should decrease with defense debuff")
	
	# Remove debuff
	character.buff_manager.remove_modifier("DefenseDebuff")
	
	# Check that defense is back to normal
	assert_eq(character.get_stat("Defense").get_value(), BASE_DEFENSE, "Defense should return to base value")
	
	character.queue_free()

func test_speed_percentage_buff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial speed
	var initial_speed = character.get_movement_speed()
	
	# Create a speed buff (+30% speed)
	var speed_buff = create_buff("SpeedBuff")
	var speed_mod = StatModifier.new("Speed", StatModifier.StatModifierType.PERCENT, 30.0)
	speed_buff.add_modifier(speed_mod)
	
	# Apply buff
	character.buff_manager.apply_modifier(speed_buff)
	
	# Check that speed is increased by 30%
	var expected_speed = BASE_SPEED * 1.3
	assert_almost_eq(character.get_stat("Speed").get_value(), expected_speed, 0.01, "Speed should be increased by 30%")
	assert_gt(character.get_movement_speed(), initial_speed, "Movement speed should increase with speed buff")
	
	# Remove buff
	character.buff_manager.remove_modifier("SpeedBuff")
	
	# Check that speed is back to normal
	assert_eq(character.get_stat("Speed").get_value(), BASE_SPEED, "Speed should return to base value")
	
	character.queue_free()

# Multi-stat buff tests

func test_berserker_rage_buff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial values
	var initial_strength = character.get_stat("Strength").get_value()
	var initial_defense = character.get_stat("Defense").get_value()
	var initial_speed = character.get_stat("Speed").get_value()
	
	# Create a "Berserker Rage" buff (+25% strength, +15% speed, -10% defense)
	var rage_buff = create_buff("BerserkerRage")
	rage_buff.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.PERCENT, 25.0))
	rage_buff.add_modifier(StatModifier.new("Speed", StatModifier.StatModifierType.PERCENT, 15.0))
	rage_buff.add_modifier(StatModifier.new("Defense", StatModifier.StatModifierType.PERCENT, -10.0))
	
	# Apply buff
	character.buff_manager.apply_modifier(rage_buff)
	
	# Check effects
	assert_almost_eq(character.get_stat("Strength").get_value(), initial_strength * 1.25, 0.01, "Strength should be increased by 25%")
	assert_almost_eq(character.get_stat("Speed").get_value(), initial_speed * 1.15, 0.01, "Speed should be increased by 15%")
	assert_almost_eq(character.get_stat("Defense").get_value(), initial_defense * 0.9, 0.01, "Defense should be decreased by 10%")
	
	# Remove buff
	character.buff_manager.remove_modifier("BerserkerRage")
	
	# Check that stats are back to normal
	assert_eq(character.get_stat("Strength").get_value(), initial_strength, "Strength should return to base value")
	assert_eq(character.get_stat("Speed").get_value(), initial_speed, "Speed should return to base value")
	assert_eq(character.get_stat("Defense").get_value(), initial_defense, "Defense should return to base value")
	
	character.queue_free()

func test_wizards_focus_buff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial values
	var initial_intelligence = character.get_stat("Intelligence").get_value()
	var initial_mana = character.get_stat("Mana").get_value()
	var initial_magic_power = character.get_magic_power()
	
	# Create a "Wizard's Focus" buff (+15% intelligence, +20 mana)
	var focus_buff = create_buff("WizardsFocus")
	focus_buff.add_modifier(StatModifier.new("Intelligence", StatModifier.StatModifierType.PERCENT, 15.0))
	focus_buff.add_modifier(StatModifier.new("Mana", StatModifier.StatModifierType.FLAT, 20.0))
	
	# Apply buff
	character.buff_manager.apply_modifier(focus_buff)
	
	# Check effects
	assert_almost_eq(character.get_stat("Intelligence").get_value(), initial_intelligence * 1.15, 0.01, "Intelligence should be increased by 15%")
	assert_eq(character.get_stat("Mana").get_value(), initial_mana + 20.0, "Mana should be increased by 20")
	assert_gt(character.get_magic_power(), initial_magic_power, "Magic power should increase")
	
	# Remove buff
	character.buff_manager.remove_modifier("WizardsFocus")
	
	# Check that stats are back to normal
	assert_eq(character.get_stat("Intelligence").get_value(), initial_intelligence, "Intelligence should return to base value")
	assert_eq(character.get_stat("Mana").get_value(), initial_mana, "Mana should return to base value")
	assert_eq(character.get_magic_power(), initial_magic_power, "Magic power should return to initial value")
	
	character.queue_free()

# Timed buff tests

func test_temporary_strength_buff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial values
	var initial_strength = character.get_stat("Strength").get_value()
	
	# Create a temporary strength buff (+5 strength for 2 seconds)
	var strength_buff = create_buff("TemporaryStrengthBuff", 2.0) as StatModifierSetTimed
	strength_buff.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, 5.0))
	
	# Apply buff
	character.buff_manager.apply_modifier(strength_buff)
	
	# Verify buff is active
	assert_eq(character.get_stat("Strength").get_value(), initial_strength + 5.0, "Strength should be increased by 5")
	assert_true(character.buff_manager.has_modifier("TemporaryStrengthBuff"), "Buff should be active")
	
	# Process for 1 second (half duration)
	character.buff_manager._process(1.0)
	assert_true(character.buff_manager.has_modifier("TemporaryStrengthBuff"), "Buff should still be active at 1 second")
	
	# Process for another 1.5 seconds (past duration)
	character.buff_manager._process(1.5)
	assert_false(character.buff_manager.has_modifier("TemporaryStrengthBuff"), "Buff should be removed after duration")
	assert_eq(character.get_stat("Strength").get_value(), initial_strength, "Strength should return to base value")
	
	character.queue_free()

func test_poison_debuff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial health
	var initial_health = character.get_stat("Health").get_value()
	
	# Create a poison debuff (-5% health for 3 seconds)
	var poison_debuff = create_buff("PoisonDebuff", 3.0) as StatModifierSetTimed
	poison_debuff.add_modifier(StatModifier.new("Health", StatModifier.StatModifierType.PERCENT, -5.0))
	
	# Apply debuff
	character.buff_manager.apply_modifier(poison_debuff)
	
	# Verify debuff is active
	var expected_health = initial_health * 0.95
	assert_almost_eq(character.get_stat("Health").get_value(), expected_health, 0.01, "Health should be decreased by 5%")
	assert_true(character.buff_manager.has_modifier("PoisonDebuff"), "Debuff should be active")
	
	# Process for 3.5 seconds (past duration)
	character.buff_manager._process(3.5)
	assert_false(character.buff_manager.has_modifier("PoisonDebuff"), "Debuff should be removed after duration")
	assert_eq(character.get_stat("Health").get_value(), initial_health, "Health should return to base value")
	
	character.queue_free()

# Stacking buff tests

func test_stacking_strength_buffs():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial values
	var initial_strength = character.get_stat("Strength").get_value()
	
	# Create first strength buff (+3 strength)
	var strength_buff1 = create_buff("StrengthBuff1")
	strength_buff1.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, 3.0))
	
	# Create second strength buff (+2 strength)
	var strength_buff2 = create_buff("StrengthBuff2")
	strength_buff2.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, 2.0))
	
	# Apply first buff
	character.buff_manager.apply_modifier(strength_buff1)
	assert_eq(character.get_stat("Strength").get_value(), initial_strength + 3.0, "Strength should be increased by 3")
	
	# Apply second buff
	character.buff_manager.apply_modifier(strength_buff2)
	assert_eq(character.get_stat("Strength").get_value(), initial_strength + 5.0, "Strength should be increased by total of 5")
	
	# Remove first buff
	character.buff_manager.remove_modifier("StrengthBuff1")
	assert_eq(character.get_stat("Strength").get_value(), initial_strength + 2.0, "Strength should now be increased by 2")
	
	# Remove second buff
	character.buff_manager.remove_modifier("StrengthBuff2")
	assert_eq(character.get_stat("Strength").get_value(), initial_strength, "Strength should return to base value")
	
	character.queue_free()

func test_conflicting_buffs():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial values
	var initial_speed = character.get_stat("Speed").get_value()
	
	# Create speed buff (+30% speed)
	var speed_buff = create_buff("SpeedBuff")
	speed_buff.add_modifier(StatModifier.new("Speed", StatModifier.StatModifierType.PERCENT, 30.0))
	
	# Create speed debuff (-20% speed)
	var speed_debuff = create_buff("SpeedDebuff")
	speed_debuff.add_modifier(StatModifier.new("Speed", StatModifier.StatModifierType.PERCENT, -20.0))
	
	# Apply speed buff
	character.buff_manager.apply_modifier(speed_buff)
	var expected_buffed_speed = initial_speed * 1.3
	assert_almost_eq(character.get_stat("Speed").get_value(), expected_buffed_speed, 0.01, "Speed should be increased by 30%")
	
	# Apply speed debuff simultaneously 
	character.buff_manager.apply_modifier(speed_debuff)
	
	# Net effect should be +10% speed (30% - 20%)
	var expected_net_speed = initial_speed * 1.1  # This is approximate due to how percentage modifiers stack
	assert_almost_eq(character.get_stat("Speed").get_value(), expected_net_speed, 0.1, "Speed should have net increase of ~10%")
	
	# Remove both
	character.buff_manager.remove_modifier("SpeedBuff")
	character.buff_manager.remove_modifier("SpeedDebuff")
	assert_eq(character.get_stat("Speed").get_value(), initial_speed, "Speed should return to base value")
	
	character.queue_free()

# Special buff scenarios

func test_health_percentage_buff_with_max_value():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Set health to 50% of max
	character.get_stat("Health").base_value = BASE_HEALTH * 0.5
	
	# Record initial values
	var initial_health = character.get_stat("Health").get_value()
	var initial_max_health = character.get_stat("Health").max_value
	
	# Create buff that increases max health by 20% and current health by 10%
	var health_buff = create_buff("HealthBuff")
	health_buff._modifier_name = "HealthBuff"
	health_buff.add_modifier(StatModifier.new("Health", StatModifier.StatModifierType.PERCENT, 10.0))
	
	# Create a "max" modifier for the max health
	var max_health_mod = StatModifier.new("Health", StatModifier.StatModifierType.MAX_PERCENT, 20.0)
	health_buff.add_modifier(max_health_mod)
	
	# Apply buff
	character.buff_manager.apply_modifier(health_buff)
	
	# Check effects - both current health and max health should increase
	var expected_max_health = initial_max_health * 1.2
	var expected_health = initial_health * 1.1
	
	assert_almost_eq(character.get_stat("Health").get_max(), expected_max_health, 0.01, "Max health should increase by 20%")
	assert_almost_eq(character.get_stat("Health").get_value(), expected_health, 0.01, "Current health should increase by 10%")
	
	# Remove buff
	character.buff_manager.remove_modifier("HealthBuff")
	
	# Check that values return to normal
	assert_eq(character.get_stat("Health").max_value, initial_max_health, "Max health should return to base value")
	assert_eq(character.get_stat("Health").get_value(), initial_health, "Health should return to base value")
	
	character.queue_free()

func test_buff_that_scales_with_level():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Add a "Level" stat
	character.stats["Level"] = Stat.new()
	character.stats["Level"].base_value = 5.0
	
	# Record initial strength
	var initial_strength = character.get_stat("Strength").get_value()
	var level = character.get_stat("Level").get_value()
	
	# Create a level-scaling strength buff (+2 strength per level)
	var strength_per_level = 2.0
	var scaling_buff = create_buff("ScalingStrengthBuff")
	scaling_buff.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, strength_per_level * level))
	
	# Apply buff
	character.buff_manager.apply_modifier(scaling_buff)
	
	# Check effects
	var expected_strength = initial_strength + (strength_per_level * level)
	assert_eq(character.get_stat("Strength").get_value(), expected_strength, "Strength should be increased based on level")
	
	# Remove buff
	character.buff_manager.remove_modifier("ScalingStrengthBuff")
	
	# Check that strength returns to normal
	assert_eq(character.get_stat("Strength").get_value(), initial_strength, "Strength should return to base value")
	
	character.queue_free()

# New test for interval-based effects
func test_interval_based_buff():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Record initial values
	var initial_health = character.get_stat("Health").get_value()
	
	# Create a healing buff that ticks every second for 5 seconds
	var healing_buff = StatModifierSetTimed.new(
		"HealingOverTime",  # modifier_name
		true,              # _process_every_frame
		"",                # group
		true,              # _apply_at_start
		1.0,               # _interval - tick every 1 second
		0.0,               # _minimum_interval
		3600.0,            # _maximum_interval
		5.0,               # _duration - total 5 seconds
		5,                 # _total_ticks - 5 ticks total
		StatModifierSetTimed.MergeType.ADD_DURATION | StatModifierSetTimed.MergeType.ADD_VALUE,  # _merge_type
		false,       # _remove_effect_on_finish
		Callable()
	)
	var mod = StatModifier.new("Health", StatModifier.StatModifierType.FLAT, 5.0)
	mod._apply_only_once = false
	healing_buff.add_modifier(mod)
	
	# Apply buff
	character.buff_manager.apply_modifier(healing_buff)
	
	# Initial application (due to apply_at_start)
	assert_eq(character.get_stat("Health").get_value(), initial_health + 5.0, "Health should increase on buff application")
	
	# Process for 1.5 seconds (should trigger first tick)
	character.buff_manager._process(1.5)
	
	# Check that health has increased again
	assert_eq(character.get_stat("Health").get_value(), initial_health + 10.0, "Health should increase after first interval tick")
	
	# Process for 4 more seconds (should trigger all remaining ticks)
	character.buff_manager._process(4.0)
	
	# Check that health has increased fully and buff is gone
	assert_eq(character.get_stat("Health").get_value(), initial_health + 25.0, "Health should be fully increased after all ticks")
	assert_false(character.buff_manager.has_modifier("HealingOverTime"), "Buff should be removed after duration")
	
	character.queue_free()

# New test for buff merging functionality
func test_buff_merging():
	var character = TestCharacter.new()
	add_child_autofree(character)
	
	# Create a timed strength buff (+5 strength for 3 seconds)
	var strength_buff1 = StatModifierSetTimed.new(
		"MergeableBuff",  # modifier_name
		true,             # _process_every_frame
		"",               # group
		true,             # _apply_at_start
		0.0,              # _interval
		0.0,              # _minimum_interval
		3600.0,           # _maximum_interval
		3.0,              # _duration - 3 seconds
		-1,               # _total_ticks - unlimited
		StatModifierSetTimed.MergeType.ADD_DURATION | StatModifierSetTimed.MergeType.ADD_VALUE,  # _merge_type
		true              # _remove_effect_on_finish
	)
	strength_buff1.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, 5.0))
	
	# Apply first buff
	character.buff_manager.apply_modifier(strength_buff1)
	
	# Record value after first buff
	var strength_after_buff1 = character.get_stat("Strength").get_value()
	assert_eq(strength_after_buff1, BASE_STRENGTH + 5.0, "Strength should be increased by 5")
	
	# Process for 1 second
	character.buff_manager._process(1.0)
	
	# Create a second similar buff that should merge
	var strength_buff2 = StatModifierSetTimed.new(
		"MergeableBuff",  # same name for merging
		true,             # _process_every_frame
		"",               # group
		true,             # _apply_at_start
		0.0,              # _interval
		0.0,              # _minimum_interval
		3600.0,           # _maximum_interval
		3.0,              # _duration - 3 more seconds
		-1,               # _total_ticks - unlimited
		StatModifierSetTimed.MergeType.ADD_DURATION | StatModifierSetTimed.MergeType.ADD_VALUE,  # _merge_type
		true              # _remove_effect_on_finish
	)
	strength_buff2.add_modifier(StatModifier.new("Strength", StatModifier.StatModifierType.FLAT, 3.0))
	
	# Apply second buff which should merge with the first
	character.buff_manager.apply_modifier(strength_buff2)
	
	# Check that strength value is increased due to ADD_VALUE merge
	var strength_after_merge = character.get_stat("Strength").get_value()
	assert_eq(strength_after_merge, BASE_STRENGTH + 8.0, "Strength should be increased to 8 after merge")
	
	# Process for 3 more seconds (past original duration)
	character.buff_manager._process(3.0)
	
	# Buff should still be active due to ADD_DURATION merge
	assert_true(character.buff_manager.has_modifier("MergeableBuff"), "Buff should still be active after original duration")
	
	# Process for 2 more seconds (past total merged duration)
	character.buff_manager._process(2.0)
	
	# Buff should be gone now
	assert_false(character.buff_manager.has_modifier("MergeableBuff"), "Buff should be removed after total merged duration")
	assert_eq(character.get_stat("Strength").get_value(), BASE_STRENGTH, "Strength should return to base value")
	
	character.queue_free()
