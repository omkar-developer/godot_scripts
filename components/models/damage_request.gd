class_name DamageRequest
extends RefCounted

var source: Node = null # Who/what caused damage (can be null)
var damage: float = 0.0 # Calculated final damage
var damage_type: int = 0 # Damage type
var crit_chance: float = 0.0 # For receiver to manipulate
var crit_damage: float = 1.5 # Multiplier if crit (1.5 = 150%)
var knockback: Vector2 = Vector2.ZERO # Optional knockback vector

func _init(_source: Node = null, _damage: float = 0.0, _type: int = 0, _crit_chance: float = 0.0, _crit_damage: float = 1.5, _knockback: Vector2 = Vector2.ZERO):
	source = _source
	damage = _damage
	damage_type = _type
	crit_chance = crit_chance
	crit_damage = crit_damage
	knockback = knockback