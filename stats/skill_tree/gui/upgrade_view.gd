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

func set_max_level_reached() -> void:
	if %UpgradeBtn:
		%UpgradeBtn.text = "MAX LEVEL"
		%UpgradeBtn.disabled = true
	
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
	
	if upgrade_cost_icon == null or upgrade_cost == 0:
		if %CostContainer: %CostContainer.visible = false
	else:
		if %CostContainer: %CostContainer.visible = true		

	if %Cost:
		if upgrade_cost == 0:
			%Cost.visible = false
		else:
			%Cost.visible = true
			%Cost.text = str(upgrade_cost)
	if %CostIcon: 
		if upgrade_cost_icon == null or upgrade_cost == 0:
			%CostIcon.visible = false
		else:
			%CostIcon.visible = true
			%CostIcon.texture = upgrade_cost_icon

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
	# Safely get base upgrade data
	upgrade_icon = data.get("icon", null)
	upgrade_name = data.get("name", "")
	upgrade_description = data.get("description", "")
	
	# Handle stat changes
	if changes_data:
		var changes = []
		for change in changes_data:
			# Safely get material icons dictionary
			var icon = null
			if material_icons.has(change):
				icon = material_icons[change].get("icon", null)
				
			# Safely get change values with defaults
			var change_dict = changes_data.get(change, {})
			var old_value = change_dict.get("old_value", 0.0)
			var value_diff = change_dict.get("value_diff", 0.0)
			
			var change_data = {
				"name": change,
				"icon": icon,
				"value": old_value,
				"change": old_value + value_diff
			}
			changes.append(change_data)
		stat_changes.assign(changes)
	else:
		stat_changes.assign(data.get("stat_changes", []))
	
	# Handle materials
	if materials_data:
		var materials = []
		for mat in materials_data:
			# Safely get material icons
			var icon = null
			if material_icons.has(mat):
				icon = material_icons[mat].get("icon", null)
			
			# Safely get inventory and material amounts
			var inv_amount = 0
			if inventory_data.has(mat):
				inv_amount = inventory_data[mat].get("amount", 0)
			
			var req_amount = 0
			if materials_data.has(mat):
				req_amount = materials_data[mat].get("amount", 0)
			
			var material_data = {
				"name": mat,
				"icon": icon,
				"amount": str(inv_amount) + "/" + str(req_amount)
			}
			materials.append(material_data)
		required_materials = materials
	else:
		required_materials.assign(data.get("required_materials", []))

	upgrade_cost = data.get("upgrade_cost", 0)
	upgrade_cost_icon = data.get("upgrade_cost_icon", null)
	update_data()

func replace_keys(text: String, with: String = "") -> String:
	var regex = RegEx.new()
	regex.compile("<[^<>]+>")
	return regex.sub(text, with, true)

func format_text(text: String, stats: Dictionary, remove_brackets:bool = true) -> String:
	var formatted = text
	
	# Max value format: [stat_name:max]
	var regex = RegEx.new()
	regex.compile("\\{(\\w+):max\\}")
	var results = regex.search_all(formatted)
	for result in results:
		var stat_name = result.get_string(1)
		if stats.has(stat_name):
			var value = stats[stat_name].get("old_max", 0) + stats[stat_name].get("max_diff", 0)
			formatted = formatted.replace("{" + stat_name + ":max}", str(value))
	
	# Current value format: [stat_name:current]
	regex.compile("\\{(\\w+):current\\}")
	results = regex.search_all(formatted)
	for result in results:
		var stat_name = result.get_string(1)
		if stats.has(stat_name):
			var value = stats[stat_name].get("old_value", 0)
			formatted = formatted.replace("{" + stat_name + ":current}", str(value))
	
	# Simple value format: [stat_name] (but not followed by :something)
	regex.compile("\\{(\\w+)(?!:)\\}")
	results = regex.search_all(formatted)
	for result in results:
		var stat_name = result.get_string(1)
		if stats.has(stat_name):
			var value = stats[stat_name].get("value_diff", 0)
			formatted = formatted.replace("{" + stat_name + "}", str(value))
	
	regex.compile("\\{([^{}]+)\\}")
	formatted = regex.sub(formatted, "", true)

	if remove_brackets:
		regex.compile("<([^<>]+)>")
		results = regex.search_all(formatted)
		for result in results:
			var stat_name = result.get_string(1)
			formatted = formatted.replace("<" + stat_name + ">", stat_name)
	return formatted

func set_data_from_upgrade(upgrade: Upgrade, _upgrade_name: String = "", _upgrade_description: String = "", _upgrade_icon: Texture2D = null, cost_icon = null, material_icons: Dictionary = {}) -> void:
	# Get config for current level
	var config: UpgradeLevelConfig = upgrade.get_current_level_config()
	
	var data = {}

	var changes_data = {
		"Level": {"old_value": upgrade.get_current_level(), "value_diff": 1}
	}

	if not config:
		data = {
		"name": replace_keys(format_text(_upgrade_name, changes_data, false)),
		"description": replace_keys(format_text(_upgrade_description, changes_data, false)),
		"icon": _upgrade_icon,
		"upgrade_cost": 0,
		"upgrade_cost_icon": cost_icon
		}
		set_data(data, {}, {}, material_icons, {})
		if upgrade.is_max_level():
			set_max_level_reached()
		return
	
	# Get stat changes by simulating next effect - this is cleaner as it handles all stat calculations	
	changes_data.merge(upgrade.simulate_next_effect())

	# Build base data dictionary with passed parameters
	data = {
		"name": format_text(_upgrade_name, changes_data),
		"description": format_text(_upgrade_description, changes_data),
		"icon": _upgrade_icon,
		"upgrade_cost": config.xp_required,
		"upgrade_cost_icon": cost_icon
	}
	
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
