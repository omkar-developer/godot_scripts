extends Control

@export var icon_texture: Texture
@export var duration_bar: TextureProgressBar
@export var stack_label: Label

var modifier: StatModifierSet
var stack_count: int = 1
var _manager: BuffManager

func setup(modifier_ref: StatModifierSet, initial_stack_count: int = 1) -> void:
	modifier = modifier_ref
	stack_count = initial_stack_count
	_update_ui()

func update(modifier_ref: StatModifierSet, new_stack_count: int) -> void:
	modifier = modifier_ref
	stack_count = new_stack_count
	_update_ui()

func set_stack_count(count: int) -> void:
	stack_count = count
	_update_ui()

func _update_ui() -> void:
	if stack_label != null:
		stack_label.text = str(stack_count)

	if modifier is StatModifierSetTimed and duration_bar != null:
		duration_bar.value = modifier.get_remaining_fraction() * duration_bar.max_value

func set_manager(manager: BuffManager) -> void:
	_manager = manager