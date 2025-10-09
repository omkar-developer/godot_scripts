# Upgrade System for Godot

A flexible and powerful **upgrade/progression system** for RPG-style stats, handling XP, levels, material requirements, and stat modifications via `StatModifierSet`s. Supports **manual or auto-upgrades**, **infinite levels**, and previewing effects before applying them.

---

## Features

* Tracks **current XP** (`current_xp`) and **level** (`current_level`) per upgrade track.
* Supports **auto-upgrades** when requirements are met (`auto_upgrade`).
* Applies **stat modifiers** for each level using `StatModifierSet` (`UpgradeLevelConfig.modifiers`).
* Handles **material requirements** per level and optional consumption (`consume_materials_on_upgrade`).
* Supports **step-levels** with signals when hitting defined milestones (`step_levels`).
* Infinite level support with configurable **growth patterns**:

  * Linear, Exponential, Polynomial, Logarithmic, or Custom formulas.
* **Preview system** to simulate the next level's effect without applying it.
* Fully **serializable** via `to_dict()` / `from_dict()` for saving/loading.

---

## Signals

| Signal              | Description                                         | Parameters                                                 |
| ------------------- | --------------------------------------------------- | ---------------------------------------------------------- |
| `upgrade_applied`   | Emitted when a level is successfully applied        | `new_level: int`, `applied_config: UpgradeLevelConfig`     |
| `upgrade_removed`   | Emitted when previous level's modifiers are removed | `removed_level: int`, `removed_config: UpgradeLevelConfig` |
| `step_reached`      | Emitted when a predefined step-level is reached     | `step_level: int`                                          |
| `max_level_reached` | Emitted when the max level is reached               | None                                                       |
| `refund_applied`    | Emitted when XP/materials are refunded              | `xp: int`, `materials: Dictionary`                         |

---

## Setup

```gdscript
var upgrade = Upgrade.new()
upgrade.init_upgrade(player_stats, player_inventory)
```

* `player_stats` must provide `get_stat(stat_name)` returning `Stat` instances or having named stats as properties.
* `player_inventory` must implement:

  * `has_materials(materials: Dictionary) -> bool`
  * `consume_materials(materials: Dictionary) -> bool`
  * (optional) `store_materials(materials: Dictionary) -> void` for refunds.

---

## Adding XP and Upgrading

### Auto-upgrade

```gdscript
upgrade.auto_upgrade = true
upgrade.add_xp(150) # Will automatically apply upgrades if requirements are met
```

### Manual upgrade

```gdscript
if upgrade.can_upgrade():
    upgrade.do_upgrade()
```

### Level up helper

```gdscript
upgrade.level_up()  # Adds required XP and upgrades automatically
```

---

## Preview Next Upgrade

Check and simulate next level without applying:

```gdscript
if upgrade.has_preview():
    var simulated_effect = upgrade.simulate_next_effect()
    for stat_name in simulated_effect:
        print(stat_name, simulated_effect[stat_name])
```

---

## Refund XP and Materials

```gdscript
var refunded_xp = upgrade.do_refund()
print("XP refunded:", refunded_xp)
```

---

## Infinite Levels

Enable infinite progression with configurable growth:

```gdscript
upgrade.enable_infinite_levels = true
upgrade.infinite_xp_pattern = Upgrade.GrowthPattern.EXPONENTIAL
upgrade.infinite_modifier_pattern = Upgrade.GrowthPattern.LINEAR
upgrade.infinite_material_pattern = Upgrade.GrowthPattern.CUSTOM

# Example of custom formula
upgrade.infinite_xp_formula = "base * pow(1.2, level - last_level)"
```

---

## Serialization

Save/load the state:

```gdscript
var data = upgrade.to_dict()
upgrade.from_dict(data)
```

Includes level, XP, applied modifiers, and infinite-level settings.

---

## Creating Level Configs

`UpgradeLevelConfig` defines each upgrade step:

```gdscript
var level1 = UpgradeLevelConfig.new()
level1.xp_required = 100
level1.modifiers = my_stat_modifier_set
level1.required_materials = {"iron": 10, "gold": 2}
```

For auto-generated levels, use `_generate_level_configs()` with first/last level and curves.

---

## Recommended Use

* Ideal for RPGs, character progression, item upgrades.
* Works with **any stats system** that supports `Stat` and `StatModifierSet`.
* Fully testable with GUT or other unit test frameworks.

---

