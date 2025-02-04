extends Resource
class_name BMModule

var manager: BuffManager

func init(_manager: BuffManager) -> void:
    manager = _manager

func uninit() -> void:
    manager = null

## Called before a modifier is applied
## Return false to prevent application
func on_before_apply(_modifier: StatModifierSet) -> bool:
    return true

## Called after a modifier is applied
func on_after_apply(_modifier: StatModifierSet) -> void:
    pass

## Called before a modifier is removed
func on_before_remove(_modifier: StatModifierSet) -> void:
    pass

## Called after a modifier is removed
func on_after_remove(_modifier: StatModifierSet) -> void:
    pass

## Called every frame
func process(_delta: float) -> void:
    pass