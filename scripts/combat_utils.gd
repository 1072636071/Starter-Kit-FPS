extends Node
## Combat utility functions shared across player and enemies.

## Apply enemy spread with distance scaling to a shoot direction.
## Spread scales linearly with distance: clamped to [0.5x, 2x] at reference distance of 10m.
## Vertical spread is dampened to 0.6x to keep horizontal feel dominant.
static func apply_enemy_spread(direction: Vector3, spread: float, distance: float) -> Vector3:
	var distance_factor := clampf(distance / 10.0, 0.5, 2.0)
	var amount := spread * distance_factor
	var offset := Vector3(
		randf_range(-amount, amount),
		randf_range(-amount * 0.6, amount * 0.6),
		randf_range(-amount, amount)
	)
	return (direction + offset).normalized()
