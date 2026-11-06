class_name MovementConfig
extends Resource

@export_group("Movement Speeds")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.5

@export_group("Movement Physics")
@export var acceleration: float = 18.0
@export var ground_deceleration: float = 22.0
@export var air_acceleration: float = 18.0
@export var gravity: float = 24.0
@export var jump_velocity: float = 7.0

@export_group("Crouching")
@export var standing_height: float = 1.8
@export var crouching_height: float = 1.1
@export var standing_eye_height: float = 1.65
@export var crouching_eye_height: float = 1.0

@export_group("Air Control")
@export_range(0.0, 1.0) var air_control: float = 1.0
