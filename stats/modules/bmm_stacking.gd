extends BMModule
class_name BMM_Stacking

## Stack behavior options
const STACK_BEHAVIOR_REFRESH = 0
const STACK_BEHAVIOR_ADD = 1
const STACK_BEHAVIOR_INDEPENDENT = 2

## Dictionary tracking modifier stacks
var _stacks: Dictionary = {}

## Array of stack configurations
@export var stack_configs: Array[StackConfig] = []

## Get current stack count
func get_stack_count(modifier_name: String) -> int:
    return _stacks.get(modifier_name, 0)

## Helper function to get stack config for a modifier
func _get_stack_config(modifier_name: String) -> StackConfig:
    for config in stack_configs:
        if config.modifier_name == modifier_name:
            return config
    return StackConfig.new(modifier_name) # Returns default config

func on_before_apply(modifier: StatModifierSet) -> bool:
    var modifier_name = modifier.modifier_name
    
    if not manager.has_modifier(modifier_name):
        _stacks[modifier_name] = 1
        return true
        
    # Get stack config
    var config = _get_stack_config(modifier_name)
    if _stacks[modifier_name] >= config.max_stacks:
        return false
        
    # Handle stacking behavior
    match config.stack_behavior:
        STACK_BEHAVIOR_REFRESH:
            var existing = manager.get_modifier(modifier_name)
            existing.merge_mod(modifier)
        STACK_BEHAVIOR_ADD:
            var existing = manager.get_modifier(modifier_name)
            if existing is StatModifierSetTimed and modifier is StatModifierSetTimed:
                existing.duration += modifier.duration
            existing.merge_mod(modifier)
        STACK_BEHAVIOR_INDEPENDENT:
            modifier.modifier_name = modifier_name + str(_stacks[modifier_name])
    
    _stacks[modifier_name] += 1
    return true

func on_after_remove(modifier: StatModifierSet) -> void:
    var base_name = modifier.modifier_name.replace(str(_stacks.get(modifier.modifier_name, 1)-1), "")
    _stacks.erase(base_name)

## Helper function to add a new stack config
func add_config(modifier_name: String, max_stacks: int = 1, behavior: int = 0) -> void:
    var config = StackConfig.new(modifier_name, max_stacks, behavior)
    stack_configs.append(config)