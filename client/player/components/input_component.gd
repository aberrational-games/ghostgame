class_name InputComponent
extends Node


var _jump_latched: bool = false
var _sequence_number: int = 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not event.is_echo():
		_jump_latched = true

func sample_input_frame() -> PlayerInputFrame:
	var frame := PlayerInputFrame.new()

	frame.move_direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	frame.sprint_pressed = Input.is_action_pressed("sprint")
	frame.crouch_pressed = Input.is_action_pressed("crouch")

	frame.jump_pressed = _jump_latched
	_jump_latched = false

	_sequence_number += 1
	frame.sequence_number = _sequence_number

	return frame
