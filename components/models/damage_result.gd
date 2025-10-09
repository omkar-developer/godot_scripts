class_name DamageResult
extends RefCounted

var request: DamageRequest           # Original request
var actual_damage: float = 0.0       # Final damage after all processing
var was_critical: bool = false       # Did it crit?
var was_blocked: bool = false        # Invulnerable/dodged?
var overkill: float = 0.0            # Damage beyond 0 HP

func _init(_request: DamageRequest, _actual_damage: float = 0.0, _was_critical: bool = false, _was_blocked: bool = false, _overkill: float = 0.0):
	request = _request
	actual_damage = _actual_damage
	was_critical = _was_critical
	was_blocked = _was_blocked
	overkill = _overkill