class_name VehiclePrototype
extends Node3D

## Это учебное кинематическое движение, а не финальная физика автомобиля.
## Числа экспортированы, чтобы их можно было менять в Inspector и наблюдать результат.
@export var input_path: NodePath
@export var acceleration: float = 8.0
@export var braking: float = 14.0
@export var rolling_resistance: float = 3.0
@export var maximum_speed: float = 18.0
@export var steering_speed: float = 1.4

@onready var driver_input: KeyboardInput = get_node(input_path) as KeyboardInput

var speed: float = 0.0


func _physics_process(delta: float) -> void:
	_update_speed(delta)
	_update_steering(delta)

	# В Godot направление вперёд для Node3D — отрицательная локальная ось Z.
	global_position += -global_basis.z * speed * delta


func _update_speed(delta: float) -> void:
	if driver_input.throttle > 0.0:
		speed += driver_input.throttle * acceleration * delta
	elif driver_input.brake > 0.0:
		speed -= driver_input.brake * braking * delta
	else:
		speed = move_toward(speed, 0.0, rolling_resistance * delta)

	speed = clampf(speed, 0.0, maximum_speed)


func _update_steering(delta: float) -> void:
	if is_zero_approx(speed):
		return

	var speed_ratio: float = speed / maximum_speed
	rotate_y(-driver_input.steering * steering_speed * speed_ratio * delta)
