extends AnimatableBody3D
## مركبة الصديق المزامَنة — نسخة صلبة (تصطدم فعلياً) بعجلات تتحرك مع الحالة

var vehicle_type := 1
var display_name := "صديق"
var occupant: Node = null
var _label: Label3D
var _wheels: Array = []
var _target_pos: Vector3
var _target_yaw: float
var _speed := 0.0
var _steer := 0.0
var _has_target := false
var _spin := 0.0
var _engine: AudioStreamPlayer3D = null

func setup(type: int, owner_name: String = "صديق") -> void:
	vehicle_type = type
	display_name = owner_name
	collision_layer = 8
	collision_mask = 1 | 8
	_build_body()
	_build_visual()
	_build_wheels()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 8
	_label.position = Vector3(0, 2.9 if vehicle_type == 2 else 2.2, 0)
	_label.text = owner_name + " 🚗"
	_label.modulate = Color(0.6, 0.95, 1.0)
	add_child(_label)

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if vehicle_type == 2:
		box.size = Vector3(2.5, 2.4, 6.8)
		shape.position = Vector3(0, 1.35, 0)
	else:
		box.size = Vector3(2.1, 1.5, 4.6)
		shape.position = Vector3(0, 0.85, 0)
	shape.shape = box
	add_child(shape)

func _build_visual() -> void:
	var path := "res://assets/models/vehicles/sedan.glb" if vehicle_type == 1 else "res://assets/models/vehicles/delivery.glb"
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var vis := ps.instantiate()
	vis.name = "Visual"
	vis.rotation.y = PI
	vis.scale = Vector3.ONE * (1.4 if vehicle_type == 1 else 1.45)
	add_child(vis)
	var eng := AudioStreamPlayer3D.new()
	eng.name = "EngineAudio"
	var s: AudioStreamWAV = load("res://assets/audio/engine_loop.wav")
	if s:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		eng.stream = s
		eng.unit_size = 6.0
		add_child(eng)
		_engine = eng

func _build_wheels() -> void:
	var offsets: Array
	if vehicle_type == 2:
		offsets = [Vector3(-1.15, 0.55, 2.1), Vector3(1.15, 0.55, 2.1), Vector3(-1.15, 0.55, -2.1), Vector3(1.15, 0.55, -2.1)]
	else:
		offsets = [Vector3(-0.95, 0.42, 1.45), Vector3(0.95, 0.42, 1.45), Vector3(-0.95, 0.42, -1.45), Vector3(0.95, 0.42, -1.45)]
	for i in offsets.size():
		var w := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42 if vehicle_type == 1 else 0.55
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.28
		w.mesh = cyl
		w.rotation.z = PI / 2.0
		w.position = offsets[i]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.12, 0.13)
		w.material_override = mat
		add_child(w)
		_wheels.append(w)

func is_remote_vehicle() -> bool:
	return true

func is_remote_player() -> bool:
	return occupant != null and is_instance_valid(occupant)

func on_hit(damage: float, from: Node = null) -> void:
	if occupant != null and is_instance_valid(occupant):
		occupant.on_hit(damage, from)

func apply_state(pos: Vector3, yaw: float, speed: float, steer: float) -> void:
	_speed = speed
	_steer = steer
	if not _has_target:
		global_position = pos
		rotation.y = yaw
		_has_target = true
		return
	_target_pos = pos
	_target_yaw = yaw
	if global_position.distance_to(pos) > 30.0:
		global_position = pos

func _physics_process(delta: float) -> void:
	if not _has_target:
		return
	var t := 1.0 - pow(0.002, delta)
	global_position = global_position.lerp(_target_pos, t)
	var diff := wrapf(_target_yaw - rotation.y, -PI, PI)
	rotation.y += diff * t
	_spin += _speed * delta * 2.2
	for i in _wheels.size():
		var w: MeshInstance3D = _wheels[i]
		w.rotation.x = _spin
		if i < 2:
			w.rotation.y = _steer * 0.55
	if _engine and _engine.stream:
		if _speed > 0.5:
			if not _engine.playing:
				_engine.play()
			_engine.pitch_scale = 0.75 + _speed * 0.045
		elif _engine.playing:
			_engine.pitch_scale = move_toward(_engine.pitch_scale, 0.6, delta)
			if _engine.pitch_scale <= 0.61:
				_engine.stop()
