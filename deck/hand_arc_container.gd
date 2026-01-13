class_name HandArcContainer
extends Control

## Custom container that arranges cards in an arc (like a hand of cards)
## Used by CardListView when view_mode = HAND_ARC

signal card_hovered(card_index: int)
signal card_unhovered()

## Arc shape settings
var arc_radius: float = 800.0
var arc_spread_degrees: float = 60.0
var hand_card_tilt: bool = true
var hand_elevation: float = -100.0
var card_spacing: float = 0.0  ## Additional spacing between cards

## Hover behavior
var enable_hover_elevation: bool = true
var hover_elevation_amount: float = 50.0
var enable_neighbor_spread: bool = true
var neighbor_spread_distance: float = 30.0

## Internal state
var cards: Array[Control] = []
var hovered_card_index: int = -1
var base_positions: Array[Vector2] = []
var base_rotations: Array[float] = []


func _ready() -> void:
	resized.connect(_on_resized)


## Add a card to the hand
func add_card(card: Control) -> void:
	cards.append(card)
	add_child(card)
	
	# Connect hover signals if card has them
	if card.has_signal("mouse_entered"):
		card.mouse_entered.connect(_on_card_hovered.bind(cards.size() - 1))
	if card.has_signal("mouse_exited"):
		card.mouse_exited.connect(_on_card_unhovered)
	
	_update_hand_layout()


## Remove a card from the hand
func remove_card(card: Control) -> void:
	var idx = cards.find(card)
	if idx >= 0:
		cards.remove_at(idx)
		card.queue_free()
		_update_hand_layout()


## Clear all cards
func clear_cards() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()
	base_positions.clear()
	base_rotations.clear()


## Recalculate and update card positions
func _update_hand_layout() -> void:
	if cards.is_empty():
		return

	var total_cards := cards.size()
	base_positions.resize(total_cards)
	base_rotations.resize(total_cards)

	# Center point (bottom of container)
	var center_x := size.x * 0.5
	var center_y := size.y + hand_elevation

	# Used for z-ordering
	var center_index := (total_cards - 1) * 0.5

	for i in range(total_cards):
		var offset := i - center_index

		# Angle per card
		var angle_step = (
			arc_spread_degrees / max(1.0, total_cards - 1.0)
		)
		var angle = offset * angle_step
		var rad := deg_to_rad(angle)

		# Position on arc (correct hand curve)
		var x := center_x + sin(rad) * arc_radius
		var y := center_y - cos(rad) * arc_radius * 0.35

		# Rotation follows arc
		var rotation_rad := deg_to_rad(angle) if hand_card_tilt else 0.0

		var card := cards[i]

		# IMPORTANT: set pivot before rotation
		card.pivot_offset = card.size * 0.5

		# Apply transform
		card.position = Vector2(x, y)
		card.rotation = rotation_rad

		# Store base state
		base_positions[i] = card.position
		base_rotations[i] = rotation_rad

		# Z-order: center card on top
		card.z_index = int(1000 - abs(offset))


## Calculate transform for a card at given index
func _calculate_card_transform(
	card_index: int,
	total_cards: int,
	center_x: float,
	center_y: float
) -> Transform2D:
	var center_index := (total_cards - 1) * 0.5
	var offset := card_index - center_index
	
	# Angle per card
	var angle_step = (
		arc_spread_degrees / max(1.0, total_cards - 1.0)
	)
	var angle = offset * angle_step
	var rad := deg_to_rad(angle)

	# HAND ARC POSITION (correct curve)
	var x := center_x + sin(rad) * arc_radius
	var y := center_y - cos(rad) * arc_radius * 0.35  # <— key fix

	# Rotation follows arc
	var rotation_rad := deg_to_rad(angle) if hand_card_tilt else 0.0

	return Transform2D(rotation_rad, Vector2(x, y))


## Handle card hover - elevate and spread neighbors
func _on_card_hovered(card_index: int) -> void:
	if card_index == hovered_card_index:
		return
	
	hovered_card_index = card_index
	card_hovered.emit(card_index)
	
	var hovered_card = cards[card_index]
	
	# Elevate hovered card
	if enable_hover_elevation:
		var target_pos = base_positions[card_index] - Vector2(0, hover_elevation_amount)
		_animate_card_position(hovered_card, target_pos, base_rotations[card_index])
		hovered_card.z_index = 1000  # Bring to front
	
	# Spread neighbors
	if enable_neighbor_spread:
		_apply_neighbor_spread(card_index)


## Handle card unhover - return to base positions
func _on_card_unhovered() -> void:
	if hovered_card_index < 0:
		return
	
	var _prev_hovered = hovered_card_index
	hovered_card_index = -1
	card_unhovered.emit()
	
	# Return all cards to base positions
	for i in range(cards.size()):
		var card = cards[i]
		_animate_card_position(card, base_positions[i], base_rotations[i])
		card.z_index = i


## Spread cards away from hovered card
func _apply_neighbor_spread(center_index: int) -> void:
	for i in range(cards.size()):
		if i == center_index:
			continue
		
		var distance = i - center_index
		var spread_direction = sign(distance)
		var spread_amount = neighbor_spread_distance * spread_direction
		
		# Only spread immediate neighbors
		if abs(distance) <= 2:
			var spread_factor = 1.0 - (abs(distance) - 1) * 0.5  # Falloff
			var offset = Vector2(spread_amount * spread_factor, 0)
			var target_pos = base_positions[i] + offset
			_animate_card_position(cards[i], target_pos, base_rotations[i])


## Animate card to target position
func _animate_card_position(card: Control, target_pos: Vector2, target_rotation: float) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(card, "position", target_pos - card.size / 2.0, 0.2)
	tween.tween_property(card, "rotation", target_rotation, 0.2)


func _on_resized() -> void:
	_update_hand_layout()
