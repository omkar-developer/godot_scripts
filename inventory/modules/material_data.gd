extends Resource
class_name MaterialData

@export var name: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var max_stack_size: int = 99
@export var weight: float = 1.0
@export var value: int = 0
@export var category: String = "misc"
@export var tags: Array[String] = []

func _init(_name: String = "", _icon: Texture2D = null, _display_name: String = "") -> void:
    name = _name
    display_name = _display_name if _display_name else _name
    icon = _icon