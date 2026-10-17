extends CharacterBody3D
## اللاعب البعيد (الصديق) — يظهر ويتحرك ويُقاتل مع مزامنة سلسة

var peer_id: int = 0
var display_name: String = "صديق"
var _label: Label3D
var _rig = null
var _fallback_mesh: MeshInstance3D
var _in_vehicle: Node = null
var _target_pos: Vector3
var _target_yaw: float
var _has_target := false
var _speed := 0.0

func _ready() -> void:
	collision_layer = 32
	collision_mask = 1 | 4 | 8
	add_to_group("remote_players")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	_build_visual()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.outline_size = 8
	_label.position = Vector3(0, 2.15, 0)
	_label.text = display_name
	_label.modulate = Color(1.0, 0.92, 0.4)
	add_child(_label)

func _build_visual() -> void:
	var rig_script: Script = load("res://scripts/player/character_rig.gd")
	var cfg = load("res://data/character_default.tres")
	if rig_script and cfg:
		_rig = rig_script.new()
		_rig.name = "Rig"
		add_child(_rig)
		if _rig.has_method("build"):
			_rig.build(cfg)
		_rig.rotation.y = PI
		return
	_fallback_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	_fallback_mesh.mesh = cap
	_fallback_mesh.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 1.0)
	_fallback_mesh.material_override = mat
	add_child(_fallback_mesh)

func set_display_name(nm: String) -> void:
	display_name = nm
	if _label:
		_label.text = nm

func is_remote_player() -> bool:
	return true

func peer() -> int:
	return peer_id

func is_in_vehicle() -> Node:
	return _in_vehicle

func set_in_vehicle(vehicle: Node) -> void:
	_in_vehicle = vehicle
	var in_v := vehicle != null and is_instance_valid(vehicle)
	visible = not in_v
	collision_layer = 0 if in_v else 32
	if _label:
		_label.visible = not in_v

func apply_state(pos: Vector3, yaw: float, anim: String = "idle") -> void:
	if not _has_target:
		global_position = pos
		rotation.y = yaw
		_has_target = true
	else:
		_target_pos = pos
		_target_yaw = yaw
		if global_position.distance_to(pos) > 25.0:
			global_position = pos
	_speed = 0.0
	if _rig and _rig.has_method("play_state"):
		_rig.play_state(anim)

func _physics_process(delta: float) -> void:
	if not _has_target or _in_vehicle != null:
		return
	var t := 1.0 - pow(0.0015, delta)
	var before := global_position
	global_position = global_position.lerp(_target_pos, t)
	_speed = before.distance_to(global_position) / maxf(delta, 0.001)
	var diff := wrapf(_target_yaw - rotation.y, -PI, PI)
	rotation.y += diff * t

func on_hit(damage: float, _from: Node = null) -> void:
	var net := get_tree().get_first_node_in_group("network") if get_tree() else null
	if net and net.has_method("report_attack") and peer_id > 0:
		net.report_attack(peer_id, damage, false)
