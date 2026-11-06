class_name PlayerController
extends CharacterBody3D

signal movement_state_changed(mode: int, state: int)

const FIRST_PERSON_RIG = preload(
	"res://client/player/presentation/first_person_rig.tscn"
)

@export var local_presentation: bool = true
@export var movement_config: MovementConfig

var _mode: int = MovementState.Mode.GROUNDED
var _grounded_state: int = MovementState.Grounded.IDLE
var _airborne_state: int = MovementState.Airborne.FALL

@onready var _input_component: InputComponent = $InputComponent
@onready var _movement_component: MovementComponent = $MovementComponent
@onready var _look_component: LookComponent = $LookComponent
@onready var _camera_pivot: Node3D = $LookPivot
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	assert(movement_config != null, "Player MovementConfig is missing.")

	_movement_component.config = movement_config

	_movement_component.initialize(
		self,
		_collision_shape,
		_camera_pivot
	)

	_look_component.initialize(self, _camera_pivot)

	if local_presentation and not OS.has_feature("dedicated_server"):
		_camera_pivot.add_child(FIRST_PERSON_RIG.instantiate())
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input_frame := _input_component.sample_input_frame()

	var previous_mode := _mode
	var previous_grounded := _grounded_state
	var previous_airborne := _airborne_state

	var target_speed := _resolve_movement_state(input_frame)

	if _mode == MovementState.Mode.GROUNDED:
		var wants_crouch := (
			_grounded_state == MovementState.Grounded.CROUCH
		)

		var crouch_applied := (
			_movement_component.set_crouched(wants_crouch)
		)

		if not crouch_applied:
			_grounded_state = MovementState.Grounded.CROUCH
			target_speed = movement_config.crouch_speed

	_movement_component.physics_tick(
		input_frame.move_direction,
		target_speed,
		delta,
		movement_config.air_control
	)

	if (
		previous_mode != _mode
		or previous_grounded != _grounded_state
		or previous_airborne != _airborne_state
	):
		movement_state_changed.emit(_mode, _get_active_substate())

func _resolve_movement_state(frame: PlayerInputFrame) -> float:
	if not is_on_floor():
		_mode = MovementState.Mode.AIRBORNE

		_airborne_state = (
			MovementState.Airborne.JUMP
			if velocity.y > 0.0
			else MovementState.Airborne.FALL
		)

		return movement_config.walk_speed

	if (
		frame.jump_pressed
		and _grounded_state != MovementState.Grounded.CROUCH
	):
		_mode = MovementState.Mode.AIRBORNE
		_airborne_state = MovementState.Airborne.JUMP

		_movement_component.jump()

		return movement_config.walk_speed

	_mode = MovementState.Mode.GROUNDED

	if frame.crouch_pressed:
		_grounded_state = MovementState.Grounded.CROUCH
		return movement_config.crouch_speed

	if (
		frame.sprint_pressed
		and frame.move_direction.length_squared() > 0.0
	):
		_grounded_state = MovementState.Grounded.SPRINT
		return movement_config.sprint_speed

	if frame.move_direction.length_squared() > 0.0:
		_grounded_state = MovementState.Grounded.WALK
		return movement_config.walk_speed

	_grounded_state = MovementState.Grounded.IDLE
	return 0.0

func _get_active_substate() -> int:
	if _mode == MovementState.Mode.GROUNDED:
		return _grounded_state

	return _airborne_state

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
