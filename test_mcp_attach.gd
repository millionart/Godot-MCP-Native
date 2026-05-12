extends Node2D

var speed: float = 200.0

func _ready() -> void:
	print("MCPTestNode ready")

func get_speed() -> float:
	return speed