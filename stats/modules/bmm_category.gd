extends BMModule
class_name BMMCategory

## Categories for organization
enum Category {
	POSITIVE,
	NEGATIVE,
	NEUTRAL
}

## Dictionary mapping modifiers to categories
var _categories: Dictionary = {}

## Set category for a modifier
func set_category(modifier_name: String, category: Category) -> void:
	_categories[modifier_name] = category

## Get category for a modifier
func get_category(modifier_name: String) -> Category:
	return _categories.get(modifier_name, Category.NEUTRAL)

## Remove all modifiers of a specific category
func remove_category(category: Category) -> void:
	var to_remove: Array = []
	
	for modifier_name in _categories:
		if _categories[modifier_name] == category:
			to_remove.append(modifier_name)
	
	for modifier_name in to_remove:
		manager.remove_modifier(modifier_name)
		_categories.erase(modifier_name)

func on_after_remove(modifier: StatModifierSet) -> void:
	_categories.erase(modifier._modifier_name)
