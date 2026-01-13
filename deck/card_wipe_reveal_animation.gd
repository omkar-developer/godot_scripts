## ============================================================================
## CENTER WIPE REVEAL (VBoxContainer-safe, UI-stable)
## ============================================================================
class_name CenterWipeRevealAnimation
extends CardRevealAnimation

@export var duration := 0.35
@export var min_scale_x := 0.05

func play_reveal(card: CardView) -> void:
	# Play sound (optional)
	var sound = get_reveal_sound(card)
	if sound and card.reveal_player:
		card.reveal_player.stream = sound
		card.reveal_player.play()

	if not card.card_front:
		animation_completed.emit()
		return

	# Assumes CardFront/VBoxContainer
	var content := card.card_front.get_node_or_null("VBoxContainer")
	if not content:
		animation_completed.emit()
		return

	# Initial visibility
	if card.card_back:
		card.card_back.visible = true

	card.card_front.visible = true

	# Wait one frame so container size is valid
	await card.get_tree().process_frame

	# Center pivot for proper wipe
	content.pivot_offset = content.size * 0.5
	content.scale = Vector2(min_scale_x, 1.0)

	var tween := card.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Wipe open
	tween.tween_property(
		content,
		"scale",
		Vector2.ONE,
		duration
	)

	# Cleanup
	tween.tween_callback(func():
		if card.card_back:
			card.card_back.visible = false
		animation_completed.emit()
	)
