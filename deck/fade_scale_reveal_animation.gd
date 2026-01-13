## ============================================================================
## FADE SCALE ANIMATION (Clean reveal with subtle scale pop)
## ============================================================================
class_name FadeScaleRevealAnimation
extends CardRevealAnimation

@export var duration: float = 0.45
@export var scale_amount: float = 1.08

func play_reveal(card: CardView) -> void:
	# Sound
	var sound = get_reveal_sound(card)
	if sound and card.reveal_player:
		card.reveal_player.stream = sound
		card.reveal_player.play()

	# Kill previous tween if any
	if card.has_meta("reveal_tween"):
		card.get_meta("reveal_tween").kill()

	var tween := card.create_tween()
	card.set_meta("reveal_tween", tween)

	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# Initial state
	card.scale = Vector2.ONE

	if card.card_back:
		card.card_back.visible = true
		card.card_back.modulate.a = 1.0

	if card.card_front:
		card.card_front.visible = true
		card.card_front.modulate.a = 0.0

	# 1️⃣ Subtle scale up
	tween.tween_property(
		card,
		"scale",
		Vector2.ONE * scale_amount,
		duration * 0.35
	)

	# 2️⃣ Fade out back
	if card.card_back:
		tween.parallel().tween_property(
			card.card_back,
			"modulate:a",
			0.0,
			duration * 0.35
		)

	# 3️⃣ Fade in front slightly after back starts fading
	if card.card_front:
		tween.parallel().tween_property(
			card.card_front,
			"modulate:a",
			1.0,
			duration * 0.30
		).set_delay(duration * 0.15)

	# 4️⃣ Settle scale
	tween.tween_property(
		card,
		"scale",
		Vector2.ONE,
		duration * 0.30
	)

	# 5️⃣ Cleanup
	tween.tween_callback(func():
		if card.card_back:
			card.card_back.visible = false
	)

	tween.tween_callback(func():
		animation_completed.emit()
	)
