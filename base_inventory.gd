extends Resource
class_name Inventory

@export var materials: Dictionary = {}  # Dictionary[String, int]

func get_material_quantity(material_name: String) -> int:
	if materials.has(material_name):
		return materials[material_name]
	return 0

func add_material(material_name: String, qty: int) -> void:
	materials[material_name] = get_material_quantity(material_name) + qty

func remove_material(material_name: String, qty: int) -> void:
	if get_material_quantity(material_name) >= qty:
		materials[material_name] -= qty
		# Optionally, remove the key if quantity falls to 0:
		if materials[material_name] <= 0:
			materials.erase(material_name)
