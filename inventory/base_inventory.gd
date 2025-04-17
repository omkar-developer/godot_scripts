extends Node
class_name BaseInventory

@export var materials: Dictionary[String, int] = {}  # Dictionary[String, int]
@export var remove_key_when_zero: bool = false
@export var modules: Array[InventoryModule] = []

signal on_changed(material_name: String, old_qty: int, new_qty: int)
signal on_material_added(material_name: String, qty: int)
signal on_material_removed(material_name: String, qty: int)

func _enter_tree() -> void:
	for module in modules:
		module.init_module(self)
		module.on_attached_to_inventory()

func _exit_tree() -> void:
	_uninit_modules()

func get_material_quantity(material_name: String) -> int:
	return materials.get(material_name, 0)

# Method for modules to safely modify quantities after operations
func _modify_material_quantity(material_name: String, new_qty: int) -> void:
	var old_qty = get_material_quantity(material_name)
	
	if old_qty == new_qty:
		return
		
	materials[material_name] = new_qty
	
	if remove_key_when_zero and materials[material_name] <= 0:
		materials.erase(material_name)
		
	emit_signal("on_changed", material_name, old_qty, get_material_quantity(material_name))

# Updated add_material function
func add_material(material_name: String, qty: int) -> int:
	if qty <= 0:
		return 0
	
	# Run module pre-add checks
	for module in modules:
		var _old_qty = get_material_quantity(material_name)
		var res = module.before_add_material(material_name, qty)
		if _old_qty != get_material_quantity(material_name):
			return get_material_quantity(material_name) - _old_qty
		if not res:
			return 0
	
	var old_qty = get_material_quantity(material_name)
	_modify_material_quantity(material_name, old_qty + qty)

	emit_signal("on_material_added", material_name, qty)
	
	# Run module post-add actions
	for module in modules:
		module.after_add_material(material_name, qty)
	
	return get_material_quantity(material_name) - old_qty

func remove_material(material_name: String, qty: int = -1) -> int:
	if qty == -1:
		qty = get_material_quantity(material_name)
	if qty <= 0 or get_material_quantity(material_name) < qty:
		return 0
	
	# Run module pre-remove checks
	for module in modules:
		if not module.before_remove_material(material_name, qty):
			return 0
	
	var old_qty = get_material_quantity(material_name)
	_modify_material_quantity(material_name, old_qty  - qty)

	emit_signal("on_material_removed", material_name, qty)
	
	# Run module post-remove actions
	for module in modules:
		module.after_remove_material(material_name, qty)
	
	return (get_material_quantity(material_name) - old_qty) * -1

func add_module(module: InventoryModule) -> void:
	if not module:
		return
	
	if module not in modules:
		modules.append(module)
		module.init_module(self)
		module.on_attached_to_inventory()

func remove_module(module: InventoryModule) -> void:
	if module in modules:
		module.uninit_module()
		module.on_detached_from_inventory()
		modules.erase(module)

func get_module(type: Variant) -> InventoryModule:
	if not is_instance_of(type, InventoryModule):
		return null
	for module in modules:
		if is_instance_of(module, type):
			return module
	return null

func get_module_by_name(module_name: StringName) -> InventoryModule:
	for module in modules:
		if module.module_name == module_name:
			return module
	return null

func get_modules(type: Variant) -> Array:
	if not is_instance_of(type, InventoryModule):
		return []
	var result = []
	for module in modules:
		if is_instance_of(module, type):
			result.append(module)
	return result

func has_enough_material(material_name: String, qty: int) -> bool:
	return get_material_quantity(material_name) >= qty

func has_materials(required_materials: Dictionary) -> bool:
	for material_name in required_materials:
		if has_enough_material(material_name, required_materials[material_name]) == false:
			return false
	return true

func consume_material(material_name: String, qty: int) -> bool:
	var removed = remove_material(material_name, qty)
	if removed < qty:
		var old_qty = get_material_quantity(material_name)
		materials[material_name] += removed
		emit_signal("on_changed", material_name, old_qty, get_material_quantity(material_name))
		return false
	return true

func consume_materials(required_materials: Dictionary) -> bool:
	var removed_log := {}

	for material_name in required_materials:
		var amount = required_materials[material_name]
		if not consume_material(material_name, amount):
			# Rollback previously removed materials
			for mat in removed_log.keys():
				materials[mat] += removed_log[mat]
				emit_signal("on_changed", mat, get_material_quantity(mat) - removed_log[mat], get_material_quantity(mat))
			return false
		else:
			removed_log[material_name] = amount

	return true

func store_materials(_materials: Dictionary) -> void:
	for material_name in _materials:
		add_material(material_name, _materials[material_name])

func transfer_to(target_inventory: BaseInventory, material_name: String, qty: int) -> int:
	var removed = remove_material(material_name, qty)
	if removed:
		var added = target_inventory.add_material(material_name, removed)
		var change = removed - added
		if change != 0:
			var old_qty = get_material_quantity(material_name)
			materials[material_name] += change
			emit_signal("on_changed", material_name, old_qty, get_material_quantity(material_name))
		return added
	return 0

func _uninit_modules() -> void:
	for module in modules:
		module.uninit_module()
		module.on_detached_from_inventory()
