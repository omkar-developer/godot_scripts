extends Resource
class_name InventoryModule

@export var module_name: String = "InventoryModule"

var inventory: BaseInventory = null

func init_module(_inventory: BaseInventory = null) -> void:
	if inventory:
		push_warning("InventoryModule already has an inventory assigned.")
		return
	if _inventory:
		self.inventory = _inventory

func uninit_module() -> void:
	if not inventory:
		push_warning("InventoryModule does not have an inventory assigned.")
		return
	self.inventory = null

func before_add_material(_material_name: String, _qty: int) -> bool:
	return true

func after_add_material(_material_name: String, _qty: int) -> void:
	pass

func before_remove_material(_material_name: String, _qty: int) -> bool:
	return true
	
func after_remove_material(_material_name: String, _qty: int) -> void:
	pass
	
func on_attached_to_inventory() -> void:
	# Called when the module is attached to an inventory
	pass
	
func on_detached_from_inventory() -> void:
	# Called when the module is removed from an inventory
	pass
