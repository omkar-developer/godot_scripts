extends RefCounted

class_name StatRef

@export var _stat_name : String
var _stat : Stat
var _connection : Callable

func init_stat(parent: Object, connection_function: Callable) -> void:
    if parent == null: return
    if _stat != null: return
    _stat = parent.get_stat(_stat_name)
    if connection_function != null and connection_function.is_valid() and _stat != null and not _stat.is_connected("value_changed", connection_function):
        _stat.connect("value_changed", connection_function)
        _connection = connection_function

func uninit_stat() -> void:
    if _stat == null: return
    if _connection != null and _connection.is_valid():
        _stat.disconnect("value_changed", _connection)
    _stat = null
    