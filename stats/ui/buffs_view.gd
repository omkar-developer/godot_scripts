class_name BuffUI
extends Container

@export var default_buff_icon_scene: PackedScene
@export var buff_icon_scenes: Dictionary = {}  # modifier_name -> PackedScene
@export var max_visible_buffs: int = 10
@export var overflow_icon_scene: PackedScene

var buff_icons: Dictionary[String, Node] = {}  # modifier_name -> BuffIcon node

var _manager: BuffManager

func _get_stack_count(mod_name: String) -> int:
	if _manager == null:
		return 0
	return _manager.get_effective_stack_count(mod_name)

func connect_to_manager(manager: BuffManager) -> void:
	_manager = manager
	manager.modifier_applied.connect(_on_applied)
	manager.modifier_removed.connect(_on_removed)

func _on_applied(mod_name: String, modifier: StatModifierSet) -> void:
	if buff_icons.has(mod_name):
		var buff_icon = buff_icons[mod_name]
		if buff_icon.has_method("update"):
			buff_icon.update(modifier, _get_stack_count(mod_name))
	if buff_icons.has("_overflow") and buff_icons["_overflow"].has_method("set_count"):
		buff_icons["_overflow"].set_count(buff_icons.size() - max_visible_buffs - 1)

	else:
		_add_icon(mod_name, modifier)

func _on_removed(mod_name: String, modifier: StatModifierSet) -> void:
	if buff_icons.has(mod_name):
		var buff_icon = buff_icons[mod_name]
		if buff_icon.has_method("update"):
			buff_icon.update(modifier, _get_stack_count(mod_name))
	if buff_icons.has("_overflow") and buff_icons["_overflow"].has_method("set_count"):
		buff_icons["_overflow"].set_count(buff_icons.size() - max_visible_buffs - 1)
	if not _manager.has_modifier(mod_name):
		_remove_icon(mod_name)


func _add_icon(mod_name: String, modifier: StatModifierSet) -> void:
	if buff_icons.size() >= max_visible_buffs:
		if overflow_icon_scene != null and not buff_icons.has("_overflow"):
			var overflow_icon = overflow_icon_scene.instantiate()
			add_child(overflow_icon)
			buff_icons["_overflow"] = overflow_icon
		return
	
	var scene_to_use = buff_icon_scenes.get(mod_name, default_buff_icon_scene)
	if scene_to_use == null:
		push_error("No buff icon scene available for modifier: " + mod_name)
		return
		
	var icon = scene_to_use.instantiate()
	if icon.has_method("setup"):
		icon.setup(modifier, _get_stack_count(mod_name))
	if icon.has_method("set_manager"):
		icon.set_manager(_manager)
	add_child(icon)
	buff_icons[mod_name] = icon

func _remove_icon(mod_name: String) -> void:
	if buff_icons.has(mod_name):
		buff_icons[mod_name].queue_free()
		buff_icons.erase(mod_name)
	if buff_icons.has("_overflow") and buff_icons.size() - 1 <= max_visible_buffs:
		buff_icons["_overflow"].queue_free()
		buff_icons.erase("_overflow")