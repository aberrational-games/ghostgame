class_name MovementState
extends RefCounted

enum Mode {
	GROUNDED,
	AIRBORNE,
}

enum Grounded {
	IDLE,
	WALK,
	SPRINT,
	CROUCH,
}

enum Airborne {
	JUMP,
	FALL,
}
