@tool
extends Control

@export var stat_name: String:
	set(v):
		stat_name = v
		if %Name: 
			if not stat_name.is_empty():
				%Name.visible = true
				%Name.text = stat_name
			else:
				%Name.visible = false

@export var icon: Texture2D:
	set(v):
		icon = v
		if %Icon: 
			if icon == null:
				%Icon.visible = false
			else:
				%Icon.visible = true
				%Icon.texture = icon

@export var stat_value: float:
	set(v):
		stat_value = v
		if %OldValue: %OldValue.text = str(stat_value)

@export var stat_change: float:
	set(v):
		stat_change = v
		if %NewValue:
			if stat_change == 0.0:
				%NewValue.visible = false
				%Arrows.visible = false
			else:
				%NewValue.visible = true
				%Arrows.visible = true
				%NewValue.text = str(stat_change)

func _ready():
	stat_name = stat_name
	icon = icon
	stat_value = stat_value
	stat_change = stat_change

func set_data(data: Dictionary):
	stat_name = data.get("name", "")
	icon = data.get("icon", null)
	stat_value = data.get("value", "")
	stat_change = data.get("change", "")
