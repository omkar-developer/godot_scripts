extends BMModule
class_name BMMResistance

## Dictionary of modifier immunities and their durations
var _immunities: Dictionary = {}
## Dictionary of modifier resistances (0-100%)
var _resistances: Dictionary = {}

## Add temporary immunity
func add_immunity(modifier_name: String, duration: float) -> void:
	_immunities[modifier_name] = duration

## Set resistance percentage
func set_resistance(modifier_name: String, resistance: float) -> void:
	_resistances[modifier_name] = clamp(resistance, 0.0, 100.0)

func on_before_apply(modifier: StatModifierSet) -> bool:
	var modifier_name = modifier._modifier_name
	
	# Check immunity
	if _immunities.has(modifier_name):
		return false
	
	# Check resistance
	if _resistances.has(modifier_name):
		var resistance = _resistances[modifier_name]
		if randf() * 100.0 <= resistance:
			return false
	
	return true

func process(delta: float) -> void:
	var to_remove: Array = []
	
	# Update immunities
	for modifier_name in _immunities:
		_immunities[modifier_name] -= delta
		if _immunities[modifier_name] <= 0:
			to_remove.append(modifier_name)
	
	for modifier_name in to_remove:
		_immunities.erase(modifier_name)
