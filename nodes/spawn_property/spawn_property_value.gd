@abstract
class_name SpawnPropertyValue
extends Resource

## Abstract base class for spawn property values with various generation modes.

## Context value sources for X input
enum ContextSource {
	SPAWN_INDEX,      ## Total spawns in lifetime (0, 1, 2, ...)
	SPAWN_PROGRESS,   ## Normalized spawn progress (0.0 to 1.0 based on max_spawns)
	ALIVE_COUNT,      ## Current number of alive entities
	TIME_ELAPSED,     ## Time since spawning started (seconds)
	WAVE_NUMBER,      ## Current wave number (WAVE mode only)
	RANDOM            ## Random value (0.0 to 1.0)
}

## Context source to use as X value for get_value()
@export var context_source: ContextSource = ContextSource.SPAWN_INDEX


## Get the final value for this property.[br]
## [param x_value]: Context value based on context_source.[br]
## [return]: Generated value (type depends on implementation).
@abstract
func get_value(x_value: float) -> Variant
