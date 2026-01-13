extends PanelContainer
class_name CardView

## Individual card UI component with audio and reveal animations

enum DisplayFlags {
	TITLE       = 1 << 0,
	ICON        = 1 << 1,
	DESCRIPTION = 1 << 2,
	CATEGORY    = 1 << 3,
	RARITY      = 1 << 4
}

signal card_clicked()
signal reveal_completed()  ## Emitted when reveal animation finishes

var card_data: CardData
var is_selected := false
var is_hovered := false
var is_revealed := false  ## Track if card has been revealed

## Node refs
@onready var title_label: Label = %Title
@onready var description_label: RichTextLabel = %Description
@onready var icon_rect: TextureRect = %Icon
@onready var selection_indicator: Control = %SelectionIndicator
@onready var category: Label = %Category
@onready var card_back: Control = %CardBack  ## Hidden card back design
@onready var card_front: Control = %CardFront  ## Actual card content

## Audio players (created dynamically)
var hover_player: AudioStreamPlayer
var select_player: AudioStreamPlayer
var reveal_player: AudioStreamPlayer

## Feature toggles
@export_group("Features")
@export var enable_selection: bool = true  ## Allow card to be selected
@export var enable_hover_effects: bool = true  ## Visual hover feedback
@export var enable_click: bool = true  ## Allow clicking the card
@export var enable_hover_sound: bool = true  ## Play sound on hover
@export var enable_select_sound: bool = true  ## Play sound on selection

## Visual tuning
@export_group("Visual Settings")
@export var hover_scale := 1.05
@export var selected_scale := 1.08
@export var animation_duration := 0.2

## Reveal animation settings
@export_group("Reveal Animation")
@export var reveal_animation: CardRevealAnimation  ## Custom animation (uses default flip if null)
@export var block_interaction_during_reveal: bool = true  ## Disable interaction while animating
@export var reveal_duration := 0.8
@export var reveal_rotation_degrees := 180.0
@export var reveal_bounce_scale := 1.15

## Default sounds (can be overridden per card)
@export_group("Audio")
@export var default_hover_sound: AudioStream
@export var default_select_sound: AudioStream
@export var default_reveal_sound: AudioStream

## Optional: Sound overrides per rarity
@export_subgroup("Rarity Sounds")
@export var common_reveal_sound: AudioStream
@export var uncommon_reveal_sound: AudioStream
@export var rare_reveal_sound: AudioStream
@export var epic_reveal_sound: AudioStream
@export var legendary_reveal_sound: AudioStream

@export var focus: bool = false:
	set(value):
		focus = value
		if has_node("%FocusIndicator"):
			%FocusIndicator.visible = value

@export_flags("Title", "Icon", "Description", "Category", "Rarity")
var display_flags: int = (
	DisplayFlags.TITLE
	| DisplayFlags.ICON
	| DisplayFlags.DESCRIPTION
	| DisplayFlags.CATEGORY
	| DisplayFlags.RARITY
)

## Tweens
var scale_tween: Tween
var reveal_tween: Tween
var indicator_tween: Tween

## Cached visual target
var target_scale := Vector2.ONE


func _ready() -> void:
	_update_pivot()
	_setup_audio_players()

	if selection_indicator:
		selection_indicator.hide()

	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


## -----------------------------
## Audio Setup
## -----------------------------
func _setup_audio_players() -> void:
	# Create audio stream players
	hover_player = AudioStreamPlayer.new()
	hover_player.bus = "SFX"
	add_child(hover_player)
	
	select_player = AudioStreamPlayer.new()
	select_player.bus = "SFX"
	add_child(select_player)
	
	reveal_player = AudioStreamPlayer.new()
	reveal_player.bus = "SFX"
	add_child(reveal_player)


func _play_sound(player: AudioStreamPlayer, sound: AudioStream) -> void:
	if not player or not sound:
		return
	
	player.stream = sound
	player.play()


## Get the appropriate sound based on card rarity
func _get_reveal_sound_for_rarity() -> AudioStream:
	if not card_data:
		return default_reveal_sound
	
	match card_data.rarity:
		CardData.CardRarity.LEGENDARY:
			return legendary_reveal_sound if legendary_reveal_sound else default_reveal_sound
		CardData.CardRarity.EPIC:
			return epic_reveal_sound if epic_reveal_sound else default_reveal_sound
		CardData.CardRarity.RARE:
			return rare_reveal_sound if rare_reveal_sound else default_reveal_sound
		CardData.CardRarity.UNCOMMON:
			return uncommon_reveal_sound if uncommon_reveal_sound else default_reveal_sound
		CardData.CardRarity.COMMON:
			return common_reveal_sound if common_reveal_sound else default_reveal_sound
		_:
			return default_reveal_sound


## -----------------------------
## Data
## -----------------------------
func setup(data: CardData) -> void:
	card_data = data

	if title_label:
		title_label.text = data.title

	if description_label:
		description_label.text = data.description

	if icon_rect:
		icon_rect.texture = data.icon

	if data.rarity != null:
		_apply_rarity(data.rarity)
	
	if category:
		category.text = data.category


func apply_display_flags() -> void:
	if title_label:
		title_label.visible = display_flags & DisplayFlags.TITLE
	if icon_rect:
		icon_rect.visible = display_flags & DisplayFlags.ICON
	if description_label:
		description_label.visible = display_flags & DisplayFlags.DESCRIPTION
	if category:
		category.visible = display_flags & DisplayFlags.CATEGORY


func _apply_rarity(rarity: CardData.CardRarity) -> void:
	var panel_style = %FrontPanel.get_theme_stylebox("panel").duplicate()
	if rarity == CardData.CardRarity.COMMON:
		panel_style.modulate_color = Color.DARK_GRAY
	elif rarity == CardData.CardRarity.UNCOMMON:
		panel_style.modulate_color = Color.LIGHT_BLUE
	elif rarity == CardData.CardRarity.RARE:
		panel_style.modulate_color = Color.LIGHT_GREEN
	elif rarity == CardData.CardRarity.EPIC:
		panel_style.modulate_color = Color.PURPLE
	elif rarity == CardData.CardRarity.LEGENDARY:
		panel_style.modulate_color = Color.ORANGE
	%FrontPanel.add_theme_stylebox_override("panel", panel_style)


## -----------------------------
## Hidden Card / Reveal
## -----------------------------

## Initialize card as hidden (call this before showing cards)
func set_hidden(p_hidden: bool) -> void:
	is_revealed = not p_hidden
	
	if card_back and card_front:
		card_back.visible = p_hidden
		card_front.visible = not p_hidden
	
	if p_hidden:
		# Reset rotation when hiding
		rotation_degrees = 0


## Play reveal animation - flips card to show contents
func reveal() -> bool:
	if is_revealed:
		return false
	
	is_revealed = true
	
	# Block interaction during animation if enabled
	if block_interaction_during_reveal:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Use custom animation if provided, otherwise use default flip
	if reveal_animation:
		reveal_animation.animation_completed.connect(_on_reveal_animation_completed, CONNECT_ONE_SHOT)
		reveal_animation.play_reveal(self)
	else:
		_default_flip_reveal()		
	return true


## Default flip animation (fallback)
func _default_flip_reveal() -> void:
	# Play reveal sound based on rarity
	var sound = _get_reveal_sound_for_rarity()
	_play_sound(reveal_player, sound)
	
	# Create flip animation
	if reveal_tween:
		reveal_tween.kill()
	
	reveal_tween = create_tween()
	reveal_tween.set_parallel(false)
	reveal_tween.set_ease(Tween.EASE_IN_OUT)
	reveal_tween.set_trans(Tween.TRANS_CUBIC)
	
	# First half: rotate to 90 degrees (edge-on)
	reveal_tween.tween_property(self, "rotation_degrees", reveal_rotation_degrees / 2, reveal_duration / 2)
	
	# At halfway point, swap card back to front
	reveal_tween.tween_callback(_swap_to_front)
	
	# Second half: complete rotation with bounce
	reveal_tween.tween_property(self, "rotation_degrees", reveal_rotation_degrees, reveal_duration / 2)
	
	# Add bounce effect
	reveal_tween.parallel().tween_property(self, "scale", Vector2.ONE * reveal_bounce_scale, reveal_duration / 4)
	reveal_tween.tween_property(self, "scale", Vector2.ONE, reveal_duration / 4)
	
	# Reset rotation at the end
	reveal_tween.tween_property(self, "rotation_degrees", 0, 0.2)
	
	# Emit completion signal
	reveal_tween.tween_callback(_on_reveal_animation_completed)


func _on_reveal_animation_completed() -> void:
	# Re-enable interaction after animation
	if block_interaction_during_reveal:
		mouse_filter = Control.MOUSE_FILTER_STOP
	
	reveal_completed.emit()


func _swap_to_front() -> void:
	if card_back:
		card_back.visible = false
	if card_front:
		card_front.visible = true


## -----------------------------
## State
## -----------------------------
func set_selected(selected: bool) -> void:
	if not enable_selection:
		return
		
	is_selected = selected

	if selection_indicator:
		selection_indicator.visible = selected

	_update_visual_state()
	
	# Play select sound
	if selected and enable_select_sound:
		_play_sound(select_player, default_select_sound)


## -----------------------------
## Input
## -----------------------------
func _gui_input(event: InputEvent) -> void:
	if not enable_click:
		return
		
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		card_clicked.emit()
		_play_click_animation()
		
		# Play select sound
		if enable_select_sound:
			_play_sound(select_player, default_select_sound)


func _on_mouse_entered() -> void:
	if not enable_hover_effects:
		return
		
	is_hovered = true
	_update_visual_state()
	
	# Play hover sound
	if is_revealed and enable_hover_sound:
		_play_sound(hover_player, default_hover_sound)


func _on_mouse_exited() -> void:
	if not enable_hover_effects:
		return
		
	is_hovered = false
	_update_visual_state()


## -----------------------------
## Visuals
## -----------------------------
func _update_visual_state() -> void:
	if not enable_hover_effects and not enable_selection:
		return
		
	if scale_tween:
		scale_tween.kill()

	target_scale = Vector2.ONE

	if enable_selection and is_selected:
		target_scale *= selected_scale
	elif enable_hover_effects and is_hovered:
		target_scale *= hover_scale

	scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(self, "scale", target_scale, animation_duration)


func _play_click_animation() -> void:
	if not enable_click:
		return
		
	if scale_tween:
		scale_tween.kill()

	scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", target_scale * 0.95, 0.08)
	scale_tween.tween_property(self, "scale", target_scale, 0.08)


func _animate_selection_indicator() -> void:
	if indicator_tween:
		indicator_tween.kill()

	if not selection_indicator or not is_selected:
		return

	indicator_tween = create_tween()
	indicator_tween.set_loops()
	indicator_tween.tween_property(selection_indicator, "modulate:a", 0.5, 0.6)
	indicator_tween.tween_property(selection_indicator, "modulate:a", 1.0, 0.6)
