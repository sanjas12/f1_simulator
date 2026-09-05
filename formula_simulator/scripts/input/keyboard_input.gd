class_name KeyboardInput
extends Node

## Нормализованные команды водителя. Другие устройства позже смогут
## выдавать те же значения, не меняя код, который управляет машиной.
var steering: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0


func _process(_delta: float) -> void:
	steering = Input.get_axis("steer_left", "steer_right")
	throttle = Input.get_action_strength("throttle")
	brake = Input.get_action_strength("brake")
