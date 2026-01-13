class_name FlipRevealAnimation
extends CardRevealAnimation

@export var duration: float = 0.45
@export var bounce_scale: float = 1.06
@export var min_width_scale: float = 0.02

func play_reveal(card: CardView) -> void:
	# Play sound
	var sound = get_reveal_sound(card)
	if sound and card.reveal_player:
		card.reveal_player.stream = sound
		card.reveal_player.play()

	# Kill existing tweens
	if card.has_meta("reveal_tween"):
		card.get_meta("reveal_tween").kill()

	var tween := card.create_tween()
	card.set_meta("reveal_tween", tween)

	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Start from back
	if card.card_back:
		card.card_back.visible = true
	if card.card_front:
		card.card_front.visible = false

	# 1️⃣ Collapse to edge (fake Y-rotation)
	tween.tween_property(
		card,
		"scale",
		Vector2(min_width_scale, 1.0),
		duration * 0.45
	)

	# 2️⃣ Swap faces at edge
	tween.tween_callback(func():
		if card.card_back:
			card.card_back.visible = false
		if card.card_front:
			card.card_front.visible = true
	)

	# 3️⃣ Expand to full width
	tween.tween_property(
		card,
		"scale",
		Vector2.ONE * bounce_scale,
		duration * 0.35
	)

	# 4️⃣ Settle
	tween.tween_property(
		card,
		"scale",
		Vector2.ONE,
		duration * 0.20
	)

	tween.tween_callback(func():
		animation_completed.emit()
	)
