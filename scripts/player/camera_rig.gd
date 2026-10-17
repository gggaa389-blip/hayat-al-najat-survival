class_name PlayerCameraRig
extends Node3D
## كاميرا الشخص الثالث مع سحب اللمس، ووضع التصويب (أمام اللاعب بيمين قليلاً)

@export var min_pitch := -1.1
@export var max_pitch := 0.55
@export var sensitivity := 0.0045
@export var normal_length := 4.3
@export var aim_length := 1.8

var _pivot: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var aiming := false
var _default_length := 4.3
var yaw := 0.0
var pitch := -0.28

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.name = "Arm"
	_arm.spring_length = normal_length
	_arm.collision_mask = 1 | 4 | 8
	_arm.margin = 0.25
	_pivot.add_child(_arm)
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.current = true
	_cam.fov = 72.0
	_arm.add_child(_cam)
	_apply_rotation()

func camera() -> Camera3D:
	return _cam

func set_aim(on: bool) -> void:
	aiming = on
	_arm.spring_length = aim_length if on else normal_length

func toggle_aim() -> void:
	set_aim(not aiming)

func set_follow_length(length: float) -> void:
	normal_length = length
	if not aiming:
		_arm.spring_length = length

func restore_length() -> void:
	set_follow_length(_default_length)

func snap_behind(vehicle_yaw: float) -> void:
	yaw = vehicle_yaw
	pitch = -0.12
	_apply_rotation()

func add_yaw(d: float) -> void:
	yaw -= d * sensitivity
	_apply_rotation()

func add_pitch(d: float) -> void:
	pitch = clampf(pitch - d * sensitivity, min_pitch, max_pitch)
	_apply_rotation()

func get_yaw() -> float:
	return yaw

func _apply_rotation() -> void:
	_pivot.rotation = Vector3(pitch, yaw, 0)

func get_aim_origin(player_pos: Vector3) -> Dictionary:
	var fwd: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var origin: Vector3 = player_pos + Vector3(0, 1.45, 0) + right * 0.35 + fwd * 0.4
	return {"origin": origin, "forward": fwd, "right": right}
