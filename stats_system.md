# Stat & Buff System Documentation

## Overview

A flexible stat and buff system for managing character attributes, modifiers, and status effects. Supports dynamic stat calculations, conditional effects, stacking behaviors, and timed buffs.

---

## Core Classes

### `Stat`

Represents a single stat (health, damage, speed, etc.) with base value and modifiers.

#### Key Properties

```gdscript
base_value: float              # Base stat value
min_value: float               # Minimum allowed value
max_value: float               # Maximum allowed value
base_value_clamped: bool       # Clamp base to min/max
final_value_clamped: bool      # Clamp final calculated value

flat_modifier: float           # Flat bonus/penalty
percent_modifier: float        # Percentage bonus (100 = +100%)
max_flat_modifier: float       # Flat bonus to max value
max_percent_modifier: float    # Percentage bonus to max value

stat_type: StatType            # FLOAT, INT, or BOOL
frozen: bool                   # Prevent value changes
```

#### Essential Methods

```gdscript
get_value() -> float           # Returns calculated value (base + modifiers)
get_max() -> float             # Returns calculated max value
get_min() -> float             # Returns minimum value
get_normalized_value() -> float # Returns 0.0-1.0 ratio (for health bars)

add_flat(amount: float)        # Add flat modifier
add_percent(amount: float)     # Add percent modifier (50 = +50%)
add_value(amount: float)       # Add to base value directly
add_max_flat(amount: float)    # Add flat to max value
add_max_percent(amount: float) # Add percent to max value

is_max() -> bool               # At maximum value?
is_min() -> bool               # At minimum value?

to_dict() -> Dictionary        # Serialize
from_dict(dict: Dictionary)    # Deserialize
```

#### Factory Methods

```gdscript
Stat.create_value(base)                    # Unclamped stat (damage, speed)
Stat.create_clamped(base, min, max)       # Clamped stat (general use)
Stat.create_full(max, min=0.0)            # Start at max (health, mana)
Stat.create_percentage(base=0.0, max=1.0) # 0-1 range (crit chance)
```

**Notes:**

- Percent modifiers are additive: +50% + +30% = +80% (not 1.5 × 1.3)
- Use `final_value_clamped` for resources (health), `base_value_clamped` for safety
- Signal `value_changed(new_value, new_max, old_value, old_max)` emitted on changes

---

### `StatModifier`

Single modification to one stat.

#### Constructor

```gdscript
StatModifier.new(stat_name: String, type: StatModifierType, value: float)
```

#### StatModifierType Enum

```gdscript
FLAT                # stat.add_flat()
PERCENT             # stat.add_percent()
MAX_FLAT            # stat.add_max_flat()
MAX_PERCENT         # stat.add_max_percent()
BASE_VALUE          # stat.add_value() - modifies base directly
MAX_VALUE           # stat.add_max_value()
MIN_VALUE           # stat.add_min_value()
```

#### Key Methods

```gdscript
init_stat(parent: Object) -> bool    # Connect to parent's stat
apply() -> float                     # Apply modifier, returns actual change
remove(remove_all: bool=true)        # Remove modifier
is_applied() -> bool                 # Is currently active?
simulate_effect() -> Dictionary      # Preview effect without applying
merge(other: StatModifier) -> bool   # Combine values with another modifier
```

**Notes:**

- `init_stat()` requires parent with `get_stat(stat_name: String)` method or Stat should be in parent as a member/property with same name.
- Names are auto-converted to snake_case (`"Health"` → `"health"`)
- Tracks `_applied_value` to handle partial removal
- For `_apply_only_once=true`, second `apply()` does nothing
- remove_all: bool=true removes all applied value instead of just used value to apply once.

---

### `StatModifierComposite`

Modifier based on other stats (e.g., "Add 10% of Strength to Damage").

#### Constructor

```gdscript
StatModifierComposite.new(stat_name, type, value)
# Then set:
_ref_stat_name: String           # Stat to reference
_ref_stat_type: RefStatType      # Which value to use
_snapshot_stats: bool            # true = capture once, false = dynamic
_math_expression: String         # For EXPRESSION type
```

#### RefStatType Enum

```gdscript
BASE_VALUE_MULTIPLY     # ref_stat.base_value × value
VALUE_MULTIPLY          # ref_stat.get_value() × value
BASE_MAX_VALUE_MULTIPLY # ref_stat.max_value × value
MAX_VALUE_MULTIPLY      # ref_stat.get_max() × value
PERCENT_BASE_VALUE      # ref_stat.base_value × value/100
PERCENT_VALUE           # ref_stat.get_value() × value/100
BASE_VALUE_ADD          # ref_stat.base_value + value
VALUE_ADD               # ref_stat.get_value() + value
DIMINISHING_RETURNS     # 1 - (1 / (1 + ref_stat × value × 0.01))
EXPRESSION              # Custom formula
```

#### Expression Syntax

```gdscript
_math_expression = "strength:value * 0.1 + intelligence:base * 0.05"
# Format: stat_name:type
# Types: base, value, bmax, max, min, normalized
```

**Notes:**

- `_snapshot_stats=false` automatically updates when reference stat changes
- Always multiplies expression result by `_value`

---

### `Condition`

Conditional logic for when to apply/remove effects.

#### Key Properties

```gdscript
_ref_stat1_name: String          # First stat to compare
_ref_stat2_name: String          # Second stat (optional)
_ref_stat1_type: RefStatType     # Which value from stat1
_ref_stat2_type: RefStatType     # Which value from stat2
_condition_type: ConditionType   # Comparison type
_negation: bool                  # Invert result
_value: float                    # Fallback value if no stat2
cooldown: float                  # Seconds between checks
_math_expression: String         # For MATH_EXPRESSION type
```

#### ConditionType Enum

```gdscript
EQUAL, GREATER_THAN, LESS_THAN
GREATER_THAN_EQUAL, LESS_THAN_EQUAL, NOT_EQUAL
MATH_EXPRESSION
```

#### Methods

```gdscript
init_stat(parent: Object)        # Connect to parent's stats
get_condition() -> bool          # Current state
```

#### Signal

```gdscript
condition_changed(result: bool)  # Emitted when condition state changes
```

**Notes:**

- At least one `_ref_stat` must be set
- If only one stat set, compares against `_value`
- Cooldown prevents rapid toggling
- Math expression uses same syntax as `StatModifierComposite`

---

### `StatModifierSet`

Container for multiple modifiers with lifecycle management.

#### Constructor

```gdscript
StatModifierSet.new(modifier_name: String, process: bool, group: String)
```

#### Key Properties

```gdscript
_modifier_name: String           # Unique identifier
_group: String                   # For bulk operations
merge_enabled: bool              # Allow merging with duplicates
process: bool                    # Update every frame
consumable: bool                 # Delete after single application

condition: Condition             # When to apply/remove
apply_on_condition_change: bool  # Apply when condition → true
remove_on_condition_change: bool # Remove when condition → false

stack_mode: StackMode            # How to handle duplicates
max_stacks: int                  # -1 = unlimited
stack_source_id: String          # For INDEPENDENT mode
stack_count: int                 # Current stacks (COUNT_STACKS mode)
```

#### StackMode Enum

```gdscript
MERGE_VALUES      # Combine values (default)
COUNT_STACKS      # Track application count, scale effects
INDEPENDENT       # Each application is separate instance
```

#### Essential Methods

```gdscript
init_modifiers(parent: Object, apply_effect: bool=true)  # Initialize
add_modifier(mod: StatModifier) -> StatModifier          # Add modifier to set
clear_modifiers()                                        # Remove all modifiers
simulate_effect() -> Dictionary                          # Preview effects

# Finding modifiers
find_mod_by_name_and_type(stat_name: String, type) -> StatModifier
find_mod_for_stat(stat_name: String) -> StatModifier

# Serialization
to_dict() -> Dictionary
from_dict(data: Dictionary, parent: Object)
```

**Notes:**

- Call `init_modifiers()` before use
- `_modifier_name` must be unique in BuffManager
- Condition signals auto-apply/remove effects
- For timed effects, use `StatModifierSetTimed` instead

---

### `StatModifierSetTimed`

Extends `StatModifierSet` with duration and intervals.

#### Additional Properties

```gdscript
interval: float          # Seconds between ticks (0 = one-shot)
duration: float          # Total lifetime (0 = infinite)
total_ticks: int         # Max applications (-1 = unlimited)
apply_at_start: bool     # Apply immediately on init
remove_effect_on_finish: bool # Clean up when done

# Timers (read-only)
timer: float             # Time alive
tick_timer: float        # Time since last tick
ticks: int               # Number of times applied
```

#### MergeType Flags (bitwise)

```gdscript
ADD_DURATION       # Add duration values
ADD_VALUE          # Add modifier values
ADD_INTERVAL       # Increase interval
REDUCE_INTERVAL    # Decrease interval
RESET_DURATION     # Reset duration timer
RESET_INTERVAL_TIMER  # Reset tick timer
DELETE             # Mark for deletion
```

**Notes:**

- Auto-deleted when duration expires or `total_ticks` reached
- Use `merge_type` flags in combination: `ADD_DURATION | RESET_INTERVAL_TIMER`
- For refresh-on-reapply: use `RESET_DURATION` flag + `MERGE_VALUES` stack mode

---

### `BuffManager`

Central manager for all active buffs/debuffs on an entity.

#### Key Properties

```gdscript
_parent: Object          # Entity owning the buffs
_modules: Array[BMModule] # Extension modules
```

#### Essential Methods

```gdscript
# Applying/Removing
apply_modifier(modifier: StatModifierSet, copy: bool=true) -> bool
remove_modifier(modifier_name: String, source_id: String="")
clear_all_modifiers()

# Querying
has_modifier(modifier_name: String) -> bool
get_modifier(modifier_name: String) -> StatModifierSet  # First instance
get_modifier_instances(modifier_name: String) -> Array  # All instances

# Groups
remove_group_modifiers(group: String)
get_group_modifiers(group: String) -> Array[StatModifierSet]
has_group_modifiers(group: String) -> bool

# Modules
add_module(module: BMModule)
remove_module(module: BMModule)

# Serialization
to_dict(modules: bool=false) -> Dictionary
from_dict(data: Dictionary, modules: bool=false)
```

#### Signals

```gdscript
modifier_applied(modifier_name: String, modifier: StatModifierSet)
modifier_removed(modifier_name: String, modifier: StatModifierSet)
```

**Notes:**

- `_parent` auto-set to parent node in scene tree
- Stack modes stored in dictionary as single value or Array
- `get_modifier()` returns first instance for INDEPENDENT mode
- `remove_modifier(name, source_id)` removes only matching source
- **Pitfall:** Modules modifying buffs during `_process()` can cause issues

---

## Modules (Extensions)

### `BMModule`

Base class for custom BuffManager extensions.

#### Override These

```gdscript
on_before_apply(modifier) -> bool  # Return false to block
on_after_apply(modifier)
on_before_remove(modifier)
on_after_remove(modifier)
process(delta: float)
```

### `BMMCategory`

Organize buffs by category (positive/negative/neutral).

```gdscript
set_category(modifier_name: String, category: Category)
remove_category(category: Category)  # Dispel all in category
```

### `BMMResistance`

Add immunities and resistances.

```gdscript
add_immunity(modifier_name: String, duration: float)
set_resistance(modifier_name: String, percent: float)  # 0-100
```

**Notes:**

- Resistance uses RNG check each application
- Immunity has time limit, resistance is permanent until changed

---

## Common Patterns

### Basic Buff

```gdscript
var buff = StatModifierSet.new("strength_potion", false, "buffs")
buff.add_modifier(StatModifier.new("strength", StatModifier.StatModifierType.FLAT, 10))
buff_manager.apply_modifier(buff)
```

### Timed DoT (Damage Over Time)

```gdscript
var poison = StatModifierSetTimed.new("poison", true, "debuffs")
poison.interval = 1.0     # Tick every second
poison.duration = 5.0     # Last 5 seconds
poison.add_modifier(StatModifier.new("health", StatModifier.StatModifierType.FLAT, -5))
buff_manager.apply_modifier(poison)
```

### Conditional Buff

```gdscript
var rage = StatModifierSet.new("rage", false, "buffs")
rage.add_modifier(StatModifier.new("damage", StatModifier.StatModifierType.PERCENT, 50))

# Only active when health < 30%
var condition = Condition.new()
condition._ref_stat1_name = "health"
condition._ref_stat1_type = Condition.RefStatType.PERCENT
condition._condition_type = Condition.ConditionType.LESS_THAN
condition._value = 30.0

rage.condition = condition
buff_manager.apply_modifier(rage)
```

### Stacking Poison (Multiple Sources)

```gdscript
# Each attacker applies independent poison
var poison = StatModifierSetTimed.new("poison", true, "debuffs")
poison.stack_mode = StatModifierSet.StackMode.INDEPENDENT
poison.stack_source_id = attacker.get_instance_id()
poison.max_stacks = 5  # Per source limit
poison.interval = 1.0
poison.duration = 10.0
poison.add_modifier(StatModifier.new("health", StatModifier.StatModifierType.FLAT, -3))
buff_manager.apply_modifier(poison)
```

### Stack Counter (Ramping Buff)

```gdscript
var fury = StatModifierSet.new("fury", false, "buffs")
fury.stack_mode = StatModifierSet.StackMode.COUNT_STACKS
fury.max_stacks = 10
fury.add_modifier(StatModifier.new("attack_speed", StatModifier.StatModifierType.PERCENT, 5))
# Each stack adds 5%, max 50% at 10 stacks
```

### Composite Modifier (Stat Scaling)

```gdscript
# Add 20% of Strength to Damage
var mod = StatModifierComposite.new("damage", StatModifier.StatModifierType.FLAT, 0.2)
mod._ref_stat_name = "strength"
mod._ref_stat_type = StatModifierComposite.RefStatType.PERCENT_VALUE
mod._snapshot_stats = false  # Update dynamically

var buff = StatModifierSet.new("strength_scaling")
buff.add_modifier(mod)
buff_manager.apply_modifier(buff)
```

---

## Initialization Requirements

1. **Entity must have stats:**

```gdscript
# Option 1: Properties
var health: Stat = Stat.create_full(100)
var damage: Stat = Stat.create_value(10)

# Option 2: get_stat() method
func get_stat(stat_name: String) -> Stat:
    return stats_dict.get(stat_name)
```

2. **BuffManager setup:**

```gdscript
# Auto-connects to parent node
var buff_manager = BuffManager.new()
add_child(buff_manager)

# Or manual:
buff_manager._parent = self
```

3. **Apply modifiers:**

```gdscript
var buff = StatModifierSet.new("my_buff")
buff.add_modifier(StatModifier.new("health", StatModifier.StatModifierType.FLAT, 50))
buff_manager.apply_modifier(buff)
```

---

## Serialization Example

```gdscript
# Save
var save_data = {
    "stats": {
        "health": health_stat.to_dict(),
        "damage": damage_stat.to_dict()
    },
    "buffs": buff_manager.to_dict()
}

# Load
health_stat.from_dict(save_data.stats.health)
damage_stat.from_dict(save_data.stats.damage)
buff_manager.from_dict(save_data.buffs)
```

---

## Performance Notes

- Disable `enable_signal` on Stat for batch updates
- Use groups for bulk removal instead of individual calls
- `process=false` on StatModifierSet unless needed
- INDEPENDENT mode creates more objects than other stack modes
- Condition cooldowns prevent expensive frequent checks