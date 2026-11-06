class_name MovementComponent
extends Node

@export var config: MovementConfig

var _body: CharacterBody3D
var _collision_shape: CollisionShape3D
var _camera_pivot: Node3D

var _capsule: CapsuleShape3D
var _standing_capsule: CapsuleShape3D

var _is_crouched: bool = false

func initialize(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	camera_pivot: Node3D
) -> void:
	_body = body
	_collision_shape = collision_shape
	_camera_pivot = camera_pivot

	assert(config != null, "MovementConfig is missing.")
	assert(
		_collision_shape.shape is CapsuleShape3D,
		"Player requires a CapsuleShape3D."
	)

	_capsule = _collision_shape.shape.duplicate() as CapsuleShape3D
	_standing_capsule = _capsule.duplicate() as CapsuleShape3D

	_collision_shape.shape = _capsule

	_standing_capsule.height = config.standing_height
	_standing_capsule.radius = _capsule.radius

	_apply_collider_height(config.standing_height)
	_camera_pivot.position.y = config.standing_eye_height

func jump() -> void:
	assert(_body.is_on_floor(), "Cannot jump while airborne.")

	_body.velocity.y = config.jump_velocity

func set_crouched(value: bool) -> bool:
	if _is_crouched == value:
		return true

	if not value and not _can_stand():
		return false

	_is_crouched = value

	var target_height := (
		config.crouching_height
		if _is_crouched
		else config.standing_height
	)

	var target_eye_height := (
		config.crouching_eye_height
		if _is_crouched
		else config.standing_eye_height
	)

	_apply_collider_height(target_height)
	_camera_pivot.position.y = target_eye_height

	return true

func physics_tick(
	move_direction: Vector2,
	target_speed: float,
	delta: float,
	air_control: float
) -> void:
	var input_direction := Vector3(
		move_direction.x,
		0.0,
		move_direction.y
	)

	var world_direction := (
		_body.global_basis * input_direction
	).normalized()

	var control_factor := (
		1.0
		if _body.is_on_floor()
		else air_control
	)

	var target_velocity := world_direction * target_speed

	var acceleration_value := (
		config.acceleration
		if world_direction.length_squared() > 0.0
		else config.ground_deceleration
	)

	if not _body.is_on_floor():
		acceleration_value = config.air_acceleration

	_body.velocity.x = move_toward(
		_body.velocity.x,
		target_velocity.x,
		acceleration_value * control_factor * delta
	)

	_body.velocity.z = move_toward(
		_body.velocity.z,
		target_velocity.z,
		acceleration_value * control_factor * delta
	)

	if not _body.is_on_floor():
		_body.velocity.y -= config.gravity * delta
	elif _body.velocity.y < 0.0:
		_body.velocity.y = 0.0

	_body.move_and_slide()

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()

	query.shape = _standing_capsule
	query.transform = (
		_body.global_transform
		* Transform3D(
			Basis.IDENTITY,
			Vector3(
				0.0,
				config.standing_height * 0.5 + 0.03,
				0.0
			)
		)
	)

	query.collision_mask = _body.collision_mask
	query.exclude = [_body.get_rid()]
	query.margin = 0.02

	var space_state := _body.get_world_3d().direct_space_state

	return space_state.intersect_shape(query, 1).is_empty()

func _apply_collider_height(height: float) -> void:
	_capsule.height = height

	_collision_shape.position.y = height * 0.5
