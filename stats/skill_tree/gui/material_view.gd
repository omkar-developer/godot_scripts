@tool
extends Control

@export var material_icon: Texture2D:
	set(v):
		material_icon = v
		if %Texture: %Texture.texture = material_icon

@export var material_name: String:
	set(v):
		material_name = v
		if %Name: %Name.text = material_name

@export var material_amount_text: String:
	set(v):
		material_amount_text = v
		if %Label: %Label.text = material_amount_text

func _ready():
	material_icon = material_icon
	material_name = material_name
	material_amount_text = material_amount_text

func set_data(data: Dictionary):
	material_icon = data.get("icon", null)
	material_name = data.get("name", "")
	material_amount_text = data.get("amount", "")
