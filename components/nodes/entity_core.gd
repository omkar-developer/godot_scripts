class_name EntityCore
extends Node

# Identity
@export var entity_id: int = -1
@export var entity_name: String = ""
@export var faction: String = "neutral"

# Signals helpful for systems (optional to emit in subclasses)
signal died
signal damaged(amount: float)
signal healed(amount: float)

# --- Core lifecycle ---
func is_alive() -> bool:
	# Default: not alive. Override in subclass.
	push_warning("BaseEntity.is_alive() not implemented for %s" % [name])
	return false

func kill() -> void:
	# Default: emit died and queue_free as a safe fallback (no assumption).
	push_warning("BaseEntity.kill() not implemented for %s" % [name])
	emit_signal("died")
	# don't queue_free by default — let subclass decide
	return

func revive() -> void:
	push_warning("BaseEntity.revive() not implemented for %s" % [name])
	return

# --- Health & damage ---
func get_health() -> float:
	push_warning("BaseEntity.get_health() not implemented for %s" % [name])
	return 0.0

func get_max_health() -> float:
	push_warning("BaseEntity.get_max_health() not implemented for %s" % [name])
	return 0.0

func get_health_percent() -> float:
	var max_h = get_max_health()
	if max_h <= 0.0:
		return 0.0
	return clamp(get_health() / max_h, 0.0, 1.0)

# DamageRequest / DamageResult are user types. We return null by default.
func apply_damage(damage_request) -> Object:
	# damage_request : DamageRequest (or plain Dictionary)
	push_warning("BaseEntity.apply_damage() not implemented for %s" % [name])
	# returning null is safe for reference-typed results (DamageResult or null)
	return null

func heal(amount: float) -> float:
	push_warning("BaseEntity.heal() not implemented for %s" % [name])
	# Return amount actually healed (0.0 by default)
	return 0.0

func set_invulnerable(enabled: bool) -> void:
	push_warning("BaseEntity.set_invulnerable() not implemented for %s" % [name])
	return

func is_invulnerable() -> bool:
	push_warning("BaseEntity.is_invulnerable() not implemented for %s" % [name])
	return false

# --- Combat & targeting ---
func attack(target: BaseEntity) -> Object:
	push_warning("BaseEntity.attack() not implemented for %s" % [name])
	return null

func set_target(target: BaseEntity) -> void:
	push_warning("BaseEntity.set_target() not implemented for %s" % [name])
	return

func get_target() -> BaseEntity:
	push_warning("BaseEntity.get_target() not implemented for %s" % [name])
	return null

func has_target() -> bool:
	return get_target() != null

# --- Position & movement ---
func get_position() -> Vector2:
	push_warning("BaseEntity.get_position() not implemented for %s" % [name])
	return Vector2.ZERO

func set_position(pos: Vector2) -> void:
	push_warning("BaseEntity.set_position() not implemented for %s" % [name])
	return

func get_velocity() -> Vector2:
	push_warning("BaseEntity.get_velocity() not implemented for %s" % [name])
	return Vector2.ZERO

func set_velocity(vel: Vector2) -> void:
	push_warning("BaseEntity.set_velocity() not implemented for %s" % [name])
	return

func get_direction() -> Vector2:
	push_warning("BaseEntity.get_direction() not implemented for %s" % [name])
	return Vector2.ZERO

# --- Status & relations ---
func is_friendly_to(other: BaseEntity) -> bool:
	push_warning("BaseEntity.is_friendly_to() not implemented for %s" % [name])
	return false

func is_enemy_to(other: BaseEntity) -> bool:
	push_warning("BaseEntity.is_enemy_to() not implemented for %s" % [name])
	return not is_friendly_to(other)

func can_take_damage() -> bool:
	push_warning("BaseEntity.can_take_damage() not implemented for %s" % [name])
	return true

func can_deal_damage() -> bool:
	push_warning("BaseEntity.can_deal_damage() not implemented for %s" % [name])
	return true

# --- Generic stats access (optional) ---
func get_stat(stat_name: String) -> float:
	push_warning("BaseEntity.get_stat() not implemented for %s" % [name])
	return 0.0

func set_stat(stat_name: String, value: float) -> void:
	push_warning("BaseEntity.set_stat() not implemented for %s" % [name])
	return

func get_stats() -> Dictionary:
	push_warning("BaseEntity.get_stats() not implemented for %s" % [name])
	return {}

# --- Helper: runtime interface check ---
static func interface_check(node: Object) -> bool:
	# Returns true if node exposes the minimal methods we expect.
	if not node:
		return false
	var required = [
		"is_alive", "get_health", "get_max_health", "apply_damage",
		"heal", "attack", "get_position", "set_position"
	]
	for m in required:
		if not node.has_method(m):
			return false
	return true
