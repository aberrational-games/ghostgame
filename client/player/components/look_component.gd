class_name LookComponent
extends Node

@export var mouse_sensitivity: float = 0.002
@export var minimum_pitch: float = -89.0
@export var maximum_pitch: float = 89.0

var _body: CharacterBody3D
var _camera_pivot: Node3D

func initialize(
	body: CharacterBody3D,
	camera_pivot: Node3D
) -> void:
	_body = body
	_camera_pivot = camera_pivot

	_camera_pivot.physics_interpolation_mode = (
		Node.PHYSICS_INTERPOLATION_MODE_OFF
	)

func _ready() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pass

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var mouse_motion := event as InputEventMouseMotion

	var yaw_delta := mouse_motion.screen_relative.x
	var pitch_delta := mouse_motion.screen_relative.y

	_body.rotate_y(-yaw_delta * mouse_sensitivity)

	var pitch := _camera_pivot.rotation.x
	pitch -= pitch_delta * mouse_sensitivity

	_camera_pivot.rotation.x = clampf(
		pitch,
		deg_to_rad(minimum_pitch),
		deg_to_rad(maximum_pitch)
	)
