extends Control
class_name CardListView

## Pure card listing UI with selection management and reveal animations
## Supports list view, grid view, horizontal scroll
## No confirm/cancel - just displays cards and tracks selection
## Keyboard/Controller support included

signal selection_changed(selected_indices: PackedInt32Array)
signal all_cards_revealed()  ## Emitted when all cards finish revealing
signal max_reveals_reached()

## View mode
enum ViewMode {
	HORIZONTAL_LIST,  ## Single row, horizontal scroll
	VERTICAL_LIST,    ## Single column, vertical scroll
	GRID,             ## Multiple rows/columns
	HAND_ARC          ## Arc formation like card games (poker, TCG)
}

## Input mode tracking
enum InputMode {
	MOUSE,
	KEYBOARD_CONTROLLER
}

## Card display
@export var card_scene: PackedScene  ## CardView scene
@export var view_mode: ViewMode = ViewMode.HORIZONTAL_LIST
@export var grid_columns: int = 3  ## Number of columns for GRID view mode
@export_flags("Title", "Icon", "Description", "Category", "Rarity")
var card_display_flags: int = (
	CardView.DisplayFlags.TITLE
	| CardView.DisplayFlags.ICON
)

## Feature toggles
@export_group("Features")
@export var enable_selection: bool = true  ## Allow selecting cards
@export var enable_hover_effects: bool = true  ## Visual hover feedback on cards
@export var enable_click: bool = true  ## Allow clicking cards
@export var enable_keyboard_navigation: bool = true  ## Arrow key navigation
@export var enable_hover_sound: bool = true  ## Play hover sounds
@export var enable_select_sound: bool = true  ## Play selection sounds

## Selection rules
@export_group("Selection Rules")
@export var allow_multi_select: bool = false
@export var min_selection: int = 0  ## 0 = optional selection
@export var max_selection: int = 1
@export var clear_selection_on_refresh: bool = false  ## Clear selection when refreshing cards

## Card sizing
@export_group("Card Sizing")
@export var auto_size_cards: bool = true  ## Enable automatic card sizing based on layout
@export var card_aspect_ratio: float = 1.4  ## Width/Height ratio for cards
@export var min_card_width: float = 80.0  ## Minimum card width (grid mode uses this)
@export var min_card_height: float = 120.0  ## Minimum card height (grid mode uses this)
@export var fixed_size_cards: bool = false
@export var fixed_card_size: Vector2 = Vector2(200, 400)

## Hand arc settings (only used when view_mode = HAND_ARC)
@export_group("Hand Arc Settings")
@export var arc_radius: float = 800.0  ## How curved the arc is
@export var arc_spread_degrees: float = 60.0  ## Total angle spread
@export var hand_card_tilt: bool = true  ## Rotate cards to follow arc
@export var hand_elevation: float = -100.0  ## Y offset from bottom
@export var hand_spacing: float = 0.0  ## Additional spacing between cards
@export var enable_hover_elevation: bool = true  ## Lift card on hover
@export var hover_elevation_amount: float = 50.0  ## How much to lift
@export var enable_neighbor_spread: bool = true  ## Spread neighbors when hovering
@export var neighbor_spread_distance: float = 30.0  ## Spread amount

## Reveal animation settings
@export_group("Hidden Cards")
@export var cards_start_hidden: bool = false  ## Cards start face-down
@export var reveal_delay_between_cards: float = 0.15  ## Stagger reveal animations
@export var auto_reveal_on_spawn: bool = true  ## Automatically reveal cards when spawned
@export var reveal_on_click: bool = true
@export var max_reveals: int = -1  # -1 = unlimited


var revealed_count := 0

## Container references (auto-created based on view mode)
var scroll_container: ScrollContainer
var card_container: Control  ## Can be HBox, VBox, Grid, or HandArcContainer

## State
var card_data_list: Array[CardData] = []
var spawned_cards: Array[CardView] = []
var selected_indices: PackedInt32Array = []
var focused_index: int = -1  ## Currently focused card for keyboard nav
var input_mode: InputMode = InputMode.MOUSE  ## Track last input type
var cards_revealed: int = 0  ## Track how many cards have been revealed


func _ready() -> void:
	_setup_containers()
	
	# Enable unhandled input processing for keyboard/controller
	set_process_unhandled_input(true)
	focus_mode = Control.FOCUS_ALL


## -----------------------------
## Public API
## -----------------------------

## Set the list of cards to display
func set_cards(cards: Array[CardData]) -> void:
	card_data_list = cards
	refresh()


## Get currently selected card indices
func get_selected_indices() -> PackedInt32Array:
	return selected_indices


## Get selected CardData objects
func get_selected_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for idx in selected_indices:
		if idx >= 0 and idx < card_data_list.size():
			result.append(card_data_list[idx])
	return result


## Clear all selections
func clear_selection() -> void:
	selected_indices.clear()
	_update_all_card_visuals()
	selection_changed.emit(selected_indices)


## Programmatically select by index
func select_index(idx: int, add_to_selection: bool = false) -> void:
	if idx < 0 or idx >= card_data_list.size():
		return
	
	if not add_to_selection or not allow_multi_select:
		selected_indices.clear()
	
	if not selected_indices.has(idx):
		if selected_indices.size() < max_selection:
			selected_indices.append(idx)
	
	_update_all_card_visuals()
	selection_changed.emit(selected_indices)


## Rebuild the entire card display
func refresh() -> void:
	if clear_selection_on_refresh:
		selected_indices.clear()
	_clear_cards()
	_spawn_cards()


## Check if selection meets minimum requirement
func is_valid_selection() -> bool:
	return selected_indices.size() >= min_selection


## -----------------------------
## Reveal System
## -----------------------------

## Reveal all cards with staggered animation
func reveal_all_cards() -> void:
	cards_revealed = 0
	
	for i in range(spawned_cards.size()):
		var card = spawned_cards[i]
		var delay = i * reveal_delay_between_cards
		
		# Create delayed reveal
		get_tree().create_timer(delay).timeout.connect(func():
			card.reveal()
		)
		
		# Connect to last card's reveal completion
		if i == spawned_cards.size() - 1:
			card.reveal_completed.connect(_on_last_card_revealed)


func _on_last_card_revealed() -> void:
	all_cards_revealed.emit()


## Reveal a specific card by index
func reveal_card(idx: int) -> void:
	if max_reveals == -1 or revealed_count < max_reveals:
		if idx >= 0 and idx < spawned_cards.size():
			if spawned_cards[idx].reveal():
				revealed_count += 1
				if revealed_count == max_reveals:
					max_reveals_reached.emit()


## Check if all cards are revealed
func are_all_cards_revealed() -> bool:
	for card in spawned_cards:
		if not card.is_revealed:
			return false
	return true


## -----------------------------
## Input Handling
## -----------------------------

func _gui_input(event: InputEvent) -> void:
	if not enable_keyboard_navigation or not has_focus() or spawned_cards.is_empty():
		return

	if event is InputEventMouse or event is InputEventMouseButton or event is InputEventMouseMotion:
		return
	
	# Keyboard/Controller input - switch mode if needed
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if input_mode != InputMode.KEYBOARD_CONTROLLER:
			input_mode = InputMode.KEYBOARD_CONTROLLER
	
	var old_focus = focused_index
	
	# Navigation
	if event.is_action_pressed("ui_left"):
		_navigate_left()
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_navigate_right()
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_navigate_up()
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_navigate_down()
		accept_event()
	# Selection
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if enable_selection and enable_click:
			_ensure_focus_initialized()
			if focused_index >= 0 and focused_index < spawned_cards.size():
				_on_card_clicked(focused_index)
		accept_event()
	
	# Update focus visual if changed
	if old_focus != focused_index:
		_update_card_focus()
		_scroll_to_focused_card()


func _ensure_focus_initialized() -> void:
	if focused_index < 0:
		focused_index = 0
		_update_card_focus()


func _navigate_left() -> void:
	_ensure_focus_initialized()
	if view_mode == ViewMode.HORIZONTAL_LIST or view_mode == ViewMode.GRID:
		focused_index = max(0, focused_index - 1)


func _navigate_right() -> void:
	_ensure_focus_initialized()
	if view_mode == ViewMode.HORIZONTAL_LIST or view_mode == ViewMode.GRID:
		focused_index = min(spawned_cards.size() - 1, focused_index + 1)


func _navigate_up() -> void:
	_ensure_focus_initialized()
	if view_mode == ViewMode.VERTICAL_LIST:
		focused_index = max(0, focused_index - 1)
	elif view_mode == ViewMode.GRID:
		var grid = card_container as GridContainer
		focused_index = max(0, focused_index - grid.columns)


func _navigate_down() -> void:
	_ensure_focus_initialized()
	if view_mode == ViewMode.VERTICAL_LIST:
		focused_index = min(spawned_cards.size() - 1, focused_index + 1)
	elif view_mode == ViewMode.GRID:
		var grid = card_container as GridContainer
		focused_index = min(spawned_cards.size() - 1, focused_index + grid.columns)


func _update_card_focus() -> void:
	# Visual feedback for focused card using custom focus property
	for i in range(spawned_cards.size()):
		var card = spawned_cards[i]
		
		# Only show focus visuals in keyboard/controller mode
		if input_mode != InputMode.KEYBOARD_CONTROLLER:
			# No focus visuals in mouse mode - restore original colors
			if card.has_method("set") and "focus" in card:
				card.focus = false
			continue
		
		# Keyboard/controller focus visuals
		var is_focused = (i == focused_index)
		
		# Use CardView's focus property if it has one
		if card.has_method("set") and "focus" in card:
			card.focus = is_focused
		else:
			# Fallback to modulate if no focus property
			if is_focused:
				card.modulate = Color(1.2, 1.2, 1.2)
			else:
				card.modulate = Color.WHITE


func _scroll_to_focused_card() -> void:
	# Only scroll in keyboard/controller mode
	if input_mode != InputMode.KEYBOARD_CONTROLLER:
		return
	
	if focused_index < 0 or focused_index >= spawned_cards.size():
		return
	
	var focused_card = spawned_cards[focused_index]
	
	# Ensure focused card is visible in scroll container
	await get_tree().process_frame  # Wait for layout update
	
	match view_mode:
		ViewMode.HORIZONTAL_LIST:
			var target_x = focused_card.position.x - scroll_container.size.x / 2 + focused_card.size.x / 2
			var h_scroll_bar = scroll_container.get_h_scroll_bar()
			scroll_container.scroll_horizontal = clamp(
				int(target_x),
				0,
				int(h_scroll_bar.max_value) if h_scroll_bar else 0
			)
		
		ViewMode.VERTICAL_LIST, ViewMode.GRID:
			var target_y = focused_card.position.y - scroll_container.size.y / 2 + focused_card.size.y / 2
			var v_scroll_bar = scroll_container.get_v_scroll_bar()
			scroll_container.scroll_vertical = clamp(
				int(target_y),
				0,
				int(v_scroll_bar.max_value) if v_scroll_bar else 0
			)


## -----------------------------
## Internal Setup
## -----------------------------

func _setup_containers() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Hand arc mode doesn't use scroll container
	if view_mode == ViewMode.HAND_ARC:
		_setup_hand_arc_container()
		return
	
	# Create scroll container for other modes
	scroll_container = ScrollContainer.new()
	add_child(scroll_container)
	scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create margin container for padding
	var margin = MarginContainer.new()
	scroll_container.add_child(margin)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	# Create card container based on view mode
	match view_mode:
		ViewMode.HORIZONTAL_LIST:
			scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			card_container = HBoxContainer.new()
			card_container.add_theme_constant_override("separation", 20)
		
		ViewMode.VERTICAL_LIST:
			scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			card_container = VBoxContainer.new()
			card_container.add_theme_constant_override("separation", 20)
		
		ViewMode.GRID:
			scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			card_container = GridContainer.new()
			card_container.columns = grid_columns
			card_container.add_theme_constant_override("h_separation", 20)
			card_container.add_theme_constant_override("v_separation", 20)
	
	margin.add_child(card_container)


func _setup_hand_arc_container() -> void:
	var hand_container = HandArcContainer.new()
	add_child(hand_container)
	hand_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Configure hand arc settings
	hand_container.arc_radius = arc_radius
	hand_container.arc_spread_degrees = arc_spread_degrees
	hand_container.hand_card_tilt = hand_card_tilt
	hand_container.hand_elevation = hand_elevation
	hand_container.card_spacing = hand_spacing
	hand_container.enable_hover_elevation = enable_hover_elevation
	hand_container.hover_elevation_amount = hover_elevation_amount
	hand_container.enable_neighbor_spread = enable_neighbor_spread
	hand_container.neighbor_spread_distance = neighbor_spread_distance
	
	card_container = hand_container


## Calculate card size based on layout mode
func _calculate_card_size() -> Vector2:
	if fixed_size_cards:
		return fixed_card_size
		
	if not auto_size_cards:
		return Vector2.ZERO  # use default size

	match view_mode:
		ViewMode.HORIZONTAL_LIST:
			# Height drives width
			var card_height = maxf(size.y - 40.0, min_card_height)
			var card_width = card_height * card_aspect_ratio
			return Vector2(card_width, card_height)

		ViewMode.VERTICAL_LIST:
			# Width drives height
			var card_width = maxf(size.x - 40.0, min_card_width)
			var card_height = card_width / card_aspect_ratio
			return Vector2(card_width, card_height)

		ViewMode.GRID:
			# Grid should be fixed/min size
			return Vector2(min_card_width, min_card_height)

	return Vector2.ZERO


## Apply sizing to a card
func _apply_card_size(card: CardView) -> void:
	if not auto_size_cards:
		return
	
	var card_size = _calculate_card_size()
	if card_size != Vector2.ZERO:
		card.custom_minimum_size = card_size


## -----------------------------
## Card Spawning
## -----------------------------

func _spawn_cards() -> void:
	if not card_scene:
		push_error("CardListView: card_scene not assigned!")
		return
	
	for i in range(card_data_list.size()):
		var card_data = card_data_list[i]
		var card_view = card_scene.instantiate() as CardView
		
		if not card_view:
			push_error("CardListView: card_scene must instantiate a CardView!")
			continue
		
		# Add card to container (HandArcContainer has special add method)
		if view_mode == ViewMode.HAND_ARC:
			(card_container as HandArcContainer).add_card(card_view)
		else:
			card_container.add_child(card_view)
		
		spawned_cards.append(card_view)
		
		# Setup card
		card_view.display_flags = card_display_flags
		card_view.setup(card_data)
		card_view.apply_display_flags()
		card_view.card_clicked.connect(_on_card_clicked.bind(i))
		
		# Apply feature toggles to each card
		card_view.enable_selection = enable_selection
		card_view.enable_hover_effects = enable_hover_effects
		card_view.enable_click = enable_click
		card_view.enable_hover_sound = enable_hover_sound
		card_view.enable_select_sound = enable_select_sound
		
		# Apply sizing based on layout mode (not for hand arc)
		if view_mode != ViewMode.HAND_ARC:
			_apply_card_size(card_view)
		
		# Disable individual card focus (we handle it at list level)
		card_view.focus_mode = Control.FOCUS_NONE
		
		# Set initial selection state
		card_view.set_selected(selected_indices.has(i))
		
		# Initialize as hidden if needed
		if cards_start_hidden:
			card_view.set_hidden(true)
	
	# Auto-reveal if enabled
	if cards_start_hidden and auto_reveal_on_spawn:
		# Wait a frame for layout
		await get_tree().process_frame
		reveal_all_cards()


func _clear_cards() -> void:
	# Special handling for hand arc container
	if view_mode == ViewMode.HAND_ARC and card_container is HandArcContainer:
		(card_container as HandArcContainer).clear_cards()
	else:
		for card in spawned_cards:
			card.queue_free()
	
	spawned_cards.clear()
	focused_index = -1
	cards_revealed = 0


## -----------------------------
## Selection Logic
## -----------------------------

func _on_card_clicked(card_index: int) -> void:
	if reveal_on_click:
		reveal_card(card_index)
		
	if not enable_selection or not enable_click:
		return
		
	# Mouse click - switch to mouse mode
	input_mode = InputMode.MOUSE
	_update_card_focus()  # Clear focus visuals immediately
	
	if allow_multi_select:
		_handle_multi_select(card_index)
	else:
		_handle_single_select(card_index)
	
	_update_all_card_visuals()
	selection_changed.emit(selected_indices)


func _handle_single_select(card_index: int) -> void:
	# Toggle if clicking same card
	if selected_indices.size() == 1 and selected_indices[0] == card_index:
		if min_selection == 0:  ## Optional selection
			selected_indices.clear()
	else:
		selected_indices.clear()
		selected_indices.append(card_index)


func _handle_multi_select(card_index: int) -> void:
	var idx_pos = selected_indices.find(card_index)
	
	if idx_pos >= 0:
		# Already selected - deselect if allowed
		if selected_indices.size() > min_selection:
			selected_indices.remove_at(idx_pos)
	else:
		# Not selected - select if allowed
		if selected_indices.size() < max_selection:
			selected_indices.append(card_index)


func _update_all_card_visuals() -> void:
	for i in range(spawned_cards.size()):
		var card = spawned_cards[i]
		card.set_selected(selected_indices.has(i))
