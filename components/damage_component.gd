class_name DamageComponent
extends RefCounted

var damage: int = 10

func apply(target_health: HealthComponent):
	if target_health:
		target_health.take_damage(damage)
