class_name HealthComponent
extends RefCounted

var max_health: int = 100
var current_health: int = 100

signal died

func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		current_health = 0
		emit_signal("died")
