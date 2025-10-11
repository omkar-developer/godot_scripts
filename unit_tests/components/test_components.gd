extends GutTest

## Component System Test Suite
## Tests critical damage/health components and their interactions

# Test doubles
var mock_player: Node
var mock_enemy: Node

## Setup mock entities with stats
func before_each():
	# Create mock player
	mock_player = Node.new()
	mock_player.name = "TestPlayer"
	mock_player.set_script(load("res://addons/gut/test_player_script.gd"))
	add_child_autofree(mock_player)
	
	# Create mock enemy
	mock_enemy = Node.new()
	mock_enemy.name = "TestEnemy"
	mock_enemy.set_script(load("res://addons/gut/test_enemy_script.gd"))
	add_child_autofree(mock_enemy)

## Cleanup
func after_each():
	mock_player = null
	mock_enemy = null


# ============================================================================
# DamageRequest Tests (WeakRef Safety)
# ============================================================================

func test_damage_request_stores_source():
	var request = DamageRequest.new(mock_player, 50.0, 0)
	
	assert_eq(request.source, mock_player, "Should store direct reference")
	assert_true(request.is_source_valid(), "Source should be valid")

func test_damage_request_weakref_detects_freed_source():
	var temp_node = Node.new()
	add_child(temp_node)
	
	var request = DamageRequest.new(temp_node, 50.0, 0)
	assert_true(request.is_source_valid(), "Source should be valid initially")
	
	# Free the source
	temp_node.queue_free()
	await wait_frames(2)  # Wait for cleanup
	
	assert_false(request.is_source_valid(), "Source should be invalid after free")
	assert_null(request.get_source(), "get_source() should return null")

func test_damage_request_properties():
	var request = DamageRequest.new(mock_player, 75.0, 1)
	request.crit_chance = 0.25
	request.crit_damage = 2.0
	request.knockback = Vector2(10, 0)
	
	assert_eq(request.damage, 75.0, "Damage should match")
	assert_eq(request.damage_type, 1, "Type should match")
	assert_eq(request.crit_chance, 0.25, "Crit chance should match")
	assert_eq(request.crit_damage, 2.0, "Crit damage should match")
	assert_eq(request.knockback, Vector2(10, 0), "Knockback should match")


# ============================================================================
# DamageResult Tests
# ============================================================================

func test_damage_result_initialization():
	var request = DamageRequest.new(mock_player, 50.0, 0)
	var result = DamageResult.new(request)
	
	assert_eq(result.request, request, "Should store request")
	assert_eq(result.actual_damage, 0.0, "Actual damage starts at 0")
	assert_eq(result.shield_damaged, 0.0, "Shield damage starts at 0")
	assert_false(result.was_critical, "Not crit by default")
	assert_false(result.was_blocked, "Not blocked by default")

func test_damage_result_get_total_damage():
	var request = DamageRequest.new(mock_player, 100.0, 0)
	var result = DamageResult.new(request)
	
	result.shield_damaged = 30.0
	result.actual_damage = 70.0
	
	assert_eq(result.get_total_damage(), 100.0, "Total should be shield + health")
	assert_true(result.dealt_damage(), "Should report damage dealt")

func test_damage_result_was_fatal():
	var request = DamageRequest.new(mock_player, 150.0, 0)
	var result = DamageResult.new(request)
	
	result.overkill = 50.0
	assert_true(result.was_fatal(), "Should be fatal with overkill")
	
	result.overkill = 0.0
	assert_false(result.was_fatal(), "Should not be fatal without overkill")


# ============================================================================
# DamageComponent Tests
# ============================================================================

func test_damage_component_create_request():
	var damage_comp = DamageComponent.new(mock_player)
	damage_comp.damage = 100.0
	damage_comp.damage_type = 1
	damage_comp.crit_chance = 0.3
	
	var request = damage_comp.create_request()
	
	assert_eq(request.damage, 100.0, "Request should have component damage")
	assert_eq(request.damage_type, 1, "Request should have component type")
	assert_eq(request.crit_chance, 0.3, "Request should have component crit")
	assert_eq(request.source, mock_player, "Request should reference owner")

func test_damage_component_copy_from():
	var comp1 = DamageComponent.new(mock_player)
	comp1.damage = 150.0
	comp1.damage_type = 2
	comp1.crit_chance = 0.5
	comp1.knockback = Vector2(20, 0)
	
	var comp2 = DamageComponent.new(null)
	comp2.copy_from(comp1, true)
	
	assert_eq(comp2.damage, 150.0, "Should copy damage")
	assert_eq(comp2.damage_type, 2, "Should copy type")
	assert_eq(comp2.crit_chance, 0.5, "Should copy crit chance")
	assert_eq(comp2.knockback, Vector2(20, 0), "Should copy knockback")
	assert_eq(comp2.owner, mock_player, "Should copy owner")

func test_damage_component_copy_from_without_owner():
	var comp1 = DamageComponent.new(mock_player)
	comp1.damage = 150.0
	
	var comp2 = DamageComponent.new(mock_enemy)
	comp2.copy_from(comp1, false)
	
	assert_eq(comp2.damage, 150.0, "Should copy damage")
	assert_eq(comp2.owner, mock_enemy, "Should keep original owner")


# ============================================================================
# StatDamageComponent Tests
# ============================================================================

func test_stat_based_damage_calculation():
	# Create player with stats
	var player = _create_player_with_stats(50.0, 0.2, 0.25, 0.5)
	
	var damage_comp = StatDamageComponent.new(player, 10.0, 0.8)
	var request = damage_comp.create_request()
	
	# Expected: base=10 + (attack=50 * scale=0.8) = 50
	#           50 * (1 + attack_percent=0.2) = 60
	assert_almost_eq(request.damage, 60.0, 0.01, "Damage formula incorrect")
	assert_almost_eq(request.crit_chance, 0.25, 0.01, "Should use owner crit chance")
	assert_almost_eq(request.crit_damage, 1.5, 0.01, "Should convert crit damage (1.0 + 0.5)")

func test_stat_based_damage_recalculates_on_stat_change():
	var player = _create_player_with_stats(50.0, 0.0, 0.0, 0.0)
	var damage_comp = StatDamageComponent.new(player, 10.0, 0.8)
	
	var request1 = damage_comp.create_request()
	assert_almost_eq(request1.damage, 50.0, 0.01, "Initial damage: 10 + (50*0.8)")
	
	# Buff adds +20 attack (use Stat's add_flat method)
	player.attack.add_flat(20.0)
	
	var request2 = damage_comp.create_request()
	assert_almost_eq(request2.damage, 66.0, 0.01, "New damage: 10 + (70*0.8)")

func test_stat_based_damage_without_stats():
	var player = Node.new()
	add_child_autofree(player)
	
	var damage_comp = StatDamageComponent.new(player, 25.0, 0.8)
	var request = damage_comp.create_request()
	
	# Without stats, should just use base damage
	assert_eq(request.damage, 25.0, "Should use base damage when no stats")


# ============================================================================
# HealthComponent Tests
# ============================================================================

func test_health_component_takes_damage():
	var enemy = _create_enemy_with_health(100.0)
	var health_comp = StatHealthComponent.new(enemy)
	
	var request = DamageRequest.new(mock_player, 30.0, 0)
	var result = health_comp.process_damage(request)
	
	assert_eq(result.actual_damage, 30.0, "Should deal full damage")
	assert_eq(enemy.health.get_value(), 70.0, "Health should decrease")
	assert_false(result.was_blocked, "Should not be blocked")

func test_health_component_death_detection():
	var enemy = _create_enemy_with_health(50.0)
	var health_comp = StatHealthComponent.new(enemy)
	
	var died_signal = watch_signals(health_comp)
	
	var request = DamageRequest.new(mock_player, 60.0, 0)
	var result = health_comp.process_damage(request)
	
	assert_true(health_comp.is_dead, "Should be dead")
	assert_signal_emitted(health_comp, "died", "Should emit died signal")
	assert_eq(result.overkill, 10.0, "Should calculate overkill")

func test_health_component_iframes():
	var enemy = _create_enemy_with_health(100.0)
	var health_comp = StatHealthComponent.new(enemy, 0.5)  # 0.5s iframes
	
	# First hit
	var request1 = DamageRequest.new(mock_player, 30.0, 0)
	var result1 = health_comp.process_damage(request1)
	assert_eq(result1.actual_damage, 30.0, "First hit should work")
	
	# Second hit during iframes
	var request2 = DamageRequest.new(mock_player, 30.0, 0)
	var result2 = health_comp.process_damage(request2)
	assert_true(result2.was_blocked, "Second hit should be blocked")
	assert_eq(enemy.health.get_value(), 70.0, "Health unchanged during iframes")

func test_health_component_resistance():
	var enemy = _create_enemy_with_resistance(100.0, 0.5)  # 50% fire resist
	var health_comp = StatHealthComponent.new(enemy)
	
	var request = DamageRequest.new(mock_player, 100.0, 1)  # Fire damage
	var result = health_comp.process_damage(request)
	
	assert_almost_eq(result.actual_damage, 50.0, 0.01, "Should apply 50% resistance")
	assert_almost_eq(enemy.health.get_value(), 50.0, 0.01, "Health after resistance")

func test_health_component_shield():
	var enemy = _create_enemy_with_shield(100.0, 30.0)
	var health_comp = StatHealthComponent.new(enemy, 0.0, true)  # Shield enabled
	
	var request = DamageRequest.new(mock_player, 50.0, 0)
	var result = health_comp.process_damage(request)
	
	assert_eq(result.shield_damaged, 30.0, "Shield should absorb 30")
	assert_eq(result.actual_damage, 20.0, "Remaining 20 to health")
	assert_eq(enemy.health.get_value(), 80.0, "Health reduced by 20")
	assert_eq(enemy.shield.get_value(), 0.0, "Shield depleted")

func test_health_component_death_prevention():
	var enemy = _create_enemy_with_health(10.0)
	var health_comp = StatHealthComponent.new(enemy, 0.0, false, "health", "shield", 0.0, true)
	
	var death_prevented_signal = watch_signals(health_comp)
	
	var request = DamageRequest.new(mock_player, 50.0, 0)
	var result = health_comp.process_damage(request)
	
	assert_signal_emitted(health_comp, "death_prevented", "Should emit death prevented")
	assert_eq(enemy.health.get_value(), 1.0, "Should survive with 1 HP")
	assert_false(health_comp.is_dead, "Should not be dead")

func test_health_component_damage_type_immunity():
	var enemy = _create_enemy_with_health(100.0)
	var health_comp = StatHealthComponent.new(enemy, 0.0, false, "health", "shield", 0.0, false, [1, 3])
	
	# Immune damage type
	var request1 = DamageRequest.new(mock_player, 50.0, 1)
	var result1 = health_comp.process_damage(request1)
	assert_true(result1.was_blocked, "Should block immune type")
	assert_eq(enemy.health.get_value(), 100.0, "Health unchanged")
	
	# Non-immune damage type
	var request2 = DamageRequest.new(mock_player, 50.0, 0)
	var result2 = health_comp.process_damage(request2)
	assert_false(result2.was_blocked, "Should not block non-immune type")
	assert_eq(enemy.health.get_value(), 50.0, "Health reduced")


# ============================================================================
# Integration Tests
# ============================================================================

func test_full_damage_flow():
	# Player with damage component
	var player = _create_player_with_stats(50.0, 0.0, 0.3, 0.5)
	var player_damage = StatDamageComponent.new(player, 20.0, 0.8)
	
	# Enemy with health component
	var enemy = _create_enemy_with_health(100.0)
	var enemy_health = StatHealthComponent.new(enemy)
	
	# Player attacks
	var result = player_damage.apply_to(enemy_health)
	
	assert_not_null(result, "Should return result")
	# Expected: 20 + (50*0.8) = 60 damage
	assert_almost_eq(result.actual_damage, 60.0, 0.01, "Damage calculation")
	assert_almost_eq(enemy.health.get_value(), 40.0, 0.01, "Enemy health reduced")

func test_bullet_with_request_pattern():
	# Player creates request
	var player = _create_player_with_stats(40.0, 0.0, 0.0, 0.0)
	var player_damage = StatDamageComponent.new(player, 10.0, 1.0)
	var request = player_damage.create_request()
	
	# Bullet carries request (simulate)
	var bullet_request = request
	
	# Player dies
	player.free()
	await wait_frames(2)
	
	# Bullet hits enemy
	var enemy = _create_enemy_with_health(100.0)
	var enemy_health = StatHealthComponent.new(enemy)
	var result = enemy_health.process_damage(bullet_request)
	
	# Damage still works
	assert_eq(result.actual_damage, 50.0, "Damage should work despite source freed")
	assert_false(result.is_source_valid(), "Source should be invalid")


# ============================================================================
# Helper Functions
# ============================================================================

func _create_player_with_stats(attack: float, attack_percent: float, crit_chance: float, crit_damage: float) -> Node:
	var player = Node.new()
	add_child_autofree(player)
	
	# Create a script dynamically with stat properties
	var script = GDScript.new()
	script.source_code = """
extends Node

var attack: Stat
var attack_percent: Stat
var crit_chance: Stat
var crit_damage: Stat

func initialize_stats(atk: float, atk_pct: float, crit_ch: float, crit_dmg: float):
	attack = Stat.create_value(atk)
	attack_percent = Stat.create_percentage(atk_pct)
	crit_chance = Stat.create_percentage(crit_ch)
	crit_damage = Stat.create_percentage(crit_dmg)
"""
	script.reload()
	player.set_script(script)
	player.initialize_stats(attack, attack_percent, crit_chance, crit_damage)
	
	return player

func _create_enemy_with_health(health_value: float) -> Node:
	var enemy = Node.new()
	add_child_autofree(enemy)
	
	# Create a script with health stat
	var script = GDScript.new()
	script.source_code = """
extends Node

var health: Stat

func initialize_health(value: float):
	health = Stat.create_clamped(value, 0.0, value)
"""
	script.reload()
	enemy.set_script(script)
	enemy.initialize_health(health_value)
	
	return enemy

func _create_enemy_with_resistance(health_value: float, resistance: float) -> Node:
	var enemy = Node.new()
	add_child_autofree(enemy)
	
	# Create a script with health and resistance
	var script = GDScript.new()
	script.source_code = """
extends Node

var health: Stat
var resist_1: Stat

func initialize(hp: float, res: float):
	health = Stat.create_clamped(hp, 0.0, hp)
	resist_1 = Stat.create_percentage(res)
"""
	script.reload()
	enemy.set_script(script)
	enemy.initialize(health_value, resistance)
	
	return enemy

func _create_enemy_with_shield(health_value: float, shield_value: float) -> Node:
	var enemy = Node.new()
	add_child_autofree(enemy)
	
	# Create a script with health and shield
	var script = GDScript.new()
	script.source_code = """
extends Node

var health: Stat
var shield: Stat

func initialize(hp: float, sh: float):
	health = Stat.create_clamped(hp, 0.0, hp)
	shield = Stat.create_clamped(sh, 0.0, sh)
"""
	script.reload()
	enemy.set_script(script)
	enemy.initialize(health_value, shield_value)
	
	return enemy
