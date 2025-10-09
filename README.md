# Godot Game Modules Library

Reusable scripts and components for Godot 4.x, designed to speed up development of common game systems. Includes modular ECS-like components, stat/buff systems, inventory, flow field pathfinding, and more.

## Features

- Modular, reusable scripts for Godot 4.x
- ECS-inspired architecture (Entity-Component-System)
- Stat and buff system with modifiers and signals
- Inventory system with stackable items and modules
- Flow field pathfinding for group movement
- Central managers for bullets, entities, and more
- Unit tests using [GUT](https://github.com/bitwes/Gut)

## Folder Overview

- **`components/`** – Reusable Components.
    - Example: `HealthComponent`, `DamageComponent`, `MovementComponent`
- **`entities/`** – Entity templates/base classes (e.g., `enemy.gd`)
- **`flow_field/`** – Flow field pathfinding (e.g., `FlowFieldManager`)
- **`inventory/`** – Inventory system and modules
- **`managers/`** – Central managers (e.g., `BulletManager`)
- **`nodes/`** – Reusable scene nodes (e.g., `HealthNode`, `MovementNode`)
- **`stats/`** – Stat system, modifiers, buffs
- **`unit_tests/`** – GUT-based unit tests for all major systems

## Example Usage

### Health & Damage Components
```gdscript
var health = HealthComponent.new()
health.max_health = 100
health.take_damage(25)
if health.current_health <= 0:
    print("Entity died!")
```

### Inventory System
```gdscript
var inv = BaseInventory.new()
inv.add_material("gold", 10)
print(inv.get_material_quantity("gold")) # 10
```

### Flow Field Pathfinding
```gdscript
var ffm = FlowFieldManager.new(32, 64, 64, true)
# Use ffm.flow_vectors for movement directions
```

### Stat System
[Docs](./stats_system.md)
```gdscript
var stat = Stat.new()
stat.base_value = 10
stat.add_flat_modifier(5)
stat.add_percent_modifier(0.2)
print(stat.get_value()) # 18
```

### Upgrades System
[Docs](./upgrade.md)
A flexible and powerful **upgrade/progression system** for RPG-style stats, handling XP, levels, material requirements, and stat modifications via `StatModifierSet`s. Supports **manual or auto-upgrades**, **infinite levels**, and previewing effects before applying them.

## Godot Compatibility

- Designed for **Godot 4.x** (tested on 4.2+)
- Scripts use GDScript and Godot's class_name system

## Unit Tests

Unit tests are in the `unit_tests/` folder, using [GUT (Godot Unit Test)](https://github.com/bitwes/Gut).

> ⚠️ **GUT is NOT required** to use the scripts in your project. Only needed for running/modifying tests.

### How to Run Tests
1. Install [GUT](https://github.com/bitwes/Gut) via AssetLib or as an addon
2. Enable GUT in your Godot project
3. Open the GUT panel and run the tests

🔗 [GUT on Asset Library](https://godotengine.org/asset-library/asset/1466)
🔗 [GUT GitHub](https://github.com/bitwes/Gut)

## Contributing

Pull requests and suggestions are welcome! Please open an issue for bugs or feature requests.

## License

See `LICENSE` for details. Scripts are MIT licensed.