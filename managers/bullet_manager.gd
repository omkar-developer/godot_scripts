extends Node

var bullets: Array[RefCounted] = []

func _process(delta):
	for bullet in bullets:
		bullet.update(delta)

func add_bullet(bullet: RefCounted) -> void:
	bullets.append(bullet)

func remove_bullet(bullet: RefCounted) -> void:
	bullets.erase(bullet)

func clear_bullets() -> void:
	bullets.clear()
