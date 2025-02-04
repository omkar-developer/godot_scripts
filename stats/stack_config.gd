## Configuration for modifier stacking
class_name StackConfig
extends Resource

@export var max_stacks: int = 1
@export_enum("Refresh", "Add", "Independent") var stack_behavior: int = 0
@export var modifier_name: String = ""

func _init(_modifier_name: String = "", _max_stacks: int = 1, _stack_behavior: int = 0):
    modifier_name = _modifier_name
    max_stacks = _max_stacks
    stack_behavior = _stack_behavior