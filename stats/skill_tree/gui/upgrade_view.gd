extends Control

signal upgrade_pressed

@export var upgrade_icon: Texture2D
@export var upgrade_name: String
@export var upgrade_description: String
@export var stat_changes:Array[Dictionary] = []
@export var required_materials:Array[Dictionary] = []
@export var upgrade_cost: int
@export var upgrade_cost_icon: Texture2D
@export var changes_view = preload("stat_change_view.tscn")
@export var materials_view = preload("material_view.tscn")

func _ready():
	upgrade_icon = upgrade_icon
	
func update_data():
	if %Icon: %Icon.texture = upgrade_icon
	if %Title: %Title.text = upgrade_name
	if %Description: %Description.text = upgrade_description
	
	# Update stat changes
	if %Changes:
		# Clear existing views
		for child in %Changes.get_children():
			child.queue_free()
		# Add new stat change views
		for change in stat_changes:
			var change_instance = changes_view.instantiate()
			%Changes.add_child(change_instance)
			change_instance.set_data(change)
	
	# Update material requirements
	if %Materials:
		# Clear existing views
		for child in %Materials.get_children():
			child.queue_free()
		# Add new material views
		for mat in required_materials:
			var material_instance = materials_view.instantiate()
			%Materials.add_child(material_instance)
			material_instance.set_data(mat)
	
	if %Cost: %Cost.text = str(upgrade_cost)
	if %CostIcon: %CostIcon.texture = upgrade_cost_icon

# data is a dictionary containing material information in the following format:
# {
#   "icon": <path_to_icon>,          # Optional: String path to icon image. Defaults to null if not provided.
#   "name": <material_name>,         # Required: String name of the material.
#   "amount": <amount_string>        # Optional: String representing amount (e.g., "10"). Can be empty string.
# }
# data is a dictionary containing statistic information in the following format:
# {
#   "name": <stat_name>,            # Required: String name of the stat.
#   "icon": <path_to_icon>,         # Optional: String path to icon image. Defaults to null if not provided.
#   "value": <stat_value>,          # Required: String value (or numerical) representation of stat.
#   "change": <change_string>       # Optional: String representing change (e.g., "+5" or "-3"). Can be empty string.
# }
func set_data(data: Dictionary, changes_data:Dictionary = {}, materials_data:Dictionary = {}, material_icons:Dictionary = {}, inventory_data:Dictionary = {}):
	upgrade_icon = data.get("icon", null)
	upgrade_name = data.get("name", "")
	upgrade_description = data.get("description", "")
	
	if changes_data:
		var changes = []
		for change in changes_data:
			var change_data = {
				"name": change,
				"icon": material_icons[change].get("icon", null),             
				"value": changes_data[change].get("old_value", 0.0),
				"change": changes_data[change].get("old_value", 0.0) + changes_data[change].get("value_diff", 0.0)
			}
			changes.append(change_data)
		stat_changes = changes
	else:
		stat_changes = data.get("stat_changes", [])
	
	if materials_data:
		var materials = []
		for mat in materials_data:
			var material_data = {
				"name": mat,
				"icon": material_icons[mat].get("icon", null),
				"amount": str(inventory_data[mat].get("amount", 0)) + "/" + str(materials_data[mat].get("amount", 0))
			}
			materials.append(material_data)
		required_materials = materials
	else:
		required_materials = data.get("required_materials", [])

	stat_changes = data.get("stat_changes", [])
	required_materials = data.get("required_materials", [])
	upgrade_cost = data.get("upgrade_cost", 0)
	upgrade_cost_icon = data.get("upgrade_cost_icon", null)
	update_data()

func set_data_from_upgrade(upgrade: Upgrade, _upgrade_name: String = "", _upgrade_description: String = "", _upgrade_icon: Texture2D = null, cost_icon = null, material_icons: Dictionary = {}) -> void:
	# Get config for current level
	var config: UpgradeLevelConfig = upgrade.get_current_level_config()
	
	if not config:
		return
	
	# Build base data dictionary with passed parameters
	var data = {
		"name": _upgrade_name,
		"description": _upgrade_description,
		"icon": _upgrade_icon,
		"upgrade_cost": config.xp_required,
		"upgrade_cost_icon": cost_icon
	}
	
	# Get stat changes by simulating next effect - this is cleaner as it handles all stat calculations
	var changes_data = upgrade.simulate_next_effect()
	
	# Get material requirements from config
	var materials_data = config.required_materials
	
	# Get current inventory data if inventory is available
	var inventory_data = {}
	if upgrade._inventory:
		for mat in materials_data.keys():
			var amount = upgrade._inventory.get_material_quantity(mat) if upgrade._inventory.has_method("get_material_quantity") else 0
			inventory_data[mat] = {"amount": amount}
	
	set_data(data, changes_data, materials_data, material_icons, inventory_data)


func _on_button_pressed() -> void:
	upgrade_pressed.emit()
