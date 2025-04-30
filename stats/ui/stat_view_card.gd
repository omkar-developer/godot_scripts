extends PanelContainer

@export var stat_name := "Title" :
	set(value):
		if value == stat_name:
			return
		stat_name = value
		update_ui()
@export var stat : Stat :
	set(value):
		if stat != null and stat.value_changed.is_connected(_on_value_changed):
			stat.value_changed.disconnect(_on_value_changed)
		if value == null or value == stat:
			return
		stat = value
		stat.value_changed.connect(_on_value_changed)
		update_ui()

@onready var _title = %Title
@onready var _text = %Text
@onready var _content = %Content

func _on_value_changed(_new_value, _new_max, _old_value, _old_max) -> void:
	update_ui()

func _ready():
	update_ui()

func _format_title() -> String:
	return "  %s: %.2f (%.2f %.2f)" % [stat_name, stat.get_value(), stat.base_value, stat.get_difference()]

func _format_text() -> String:
	var txt = ""
	txt += "Base Value      : %.2f\n" % stat.base_value
	txt += "Current Value   : %.2f\n" % stat.get_value()
	txt += "Min Value       : %.2f\n" % stat.min_value
	txt += "Max Value       : %.2f\n" % stat.get_max()
	txt += "Flat Modifier   : %.2f\n" % stat.flat_modifier
	txt += "Percent Modifier: %.2f%%\n" % stat.percent_modifier
	txt += "Max Flat Mod    : %.2f\n" % stat.max_flat_modifier
	txt += "Max Percent Mod : %.2f%%\n" % stat.max_percent_modifier
	txt += "Normalized      : %.2f\n" % stat.get_normalized_value()
	return txt

func update_ui():
	if stat == null or not is_inside_tree():
		return
	_title.text = _format_title()
	if _content.visible:
		_text.text = _format_text()

func _on_title_pressed() -> void:
	_content.visible = _title.button_pressed
	update_ui()
