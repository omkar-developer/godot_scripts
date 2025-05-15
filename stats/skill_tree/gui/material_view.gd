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

@export var material_amount: int = 0:
	set(v):
		material_amount = v
		if %Label: %Label.text = str(material_amount) + "/" + str(material_max_amount)

@export var material_max_amount: int = 3:
	set(v):
		material_max_amount = v
		if %Label: %Label.text = str(material_amount) + "/" + str(material_max_amount)

func _ready():
	if %Texture: %Texture.texture = material_icon
	if %Name: %Name.text = material_name
	if %Label: %Label.text = str(material_amount) + "/" + str(material_max_amount)

func set_data(data: Dictionary):
	material_icon = data.get("icon", null)
	material_name = data.get("name", "")
	material_amount = data.get("amount", 0)
	material_max_amount = data.get("max_amount", 3)