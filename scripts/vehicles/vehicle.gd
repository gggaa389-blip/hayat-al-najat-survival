class_name Vehicle
extends VehicleBody3D
## مركبة قابلة للقيادة: وقود، صوت محرك، ركوب/نزول، مقعد سائق، حمولة (اختياري)

signal entered(player: Node)
signal exited(player: Node)
signal fuel_changed(fuel: float)

@export var vehicle_name := "مركبة"
@export var visual_path := ""
@export var visual_scale := 1.4
@export var body_size := Vector3(2.1, 1.5, 3.7)
@export var body_offset := Vector3(0, 0.85, 0)
@export var engine_power := 2300.0
@export var brake_power := 40.0
@export var max_steer := 0.42
@export var wheel_radius := 0.42
@export var wheel_positions: Array[Vector3] = []
@export var front_wheel_indices: Array[int] = []
@export var fuel_max := 100.0
@export var fuel := 100.0
@export var fuel_consumption := 1.1
@export var seat_offset := Vector3(0.5, 0.95, -0.2)
@export var camera_length := 5.4
@export var has_cargo := false
@export var cargo_animal_capacity := 5
@export var cargo_fish_capacity := 10

var driver: Node = null
var cargo: VehicleCargo = null
var engine_on := false
var _engine_audio: AudioStreamPlayer3D = null
var _enter_area: Interactable = null
var _visual_yaw := PI   # نماذج Kenney تواجه +Z والمركبة تقود نحو -Z

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4 | 8
	_build_body()
	_build_wheels()
	_build_visual()
	_build_audio()
	_build_enter_area()
	if has_cargo:
		cargo = VehicleCargo.new()
		cargo.animal_capacity = cargo_animal_capacity
		cargo.fish_capacity = cargo_fish_capacity

func _build_body() -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(body_size.x, body_size.y * 0.82, body_size.z)
	cs.shape = box
	cs.position = body_offset + Vector3(0, body_size.y * 0.14, 0)
	add_child(cs)

func _build_wheels() -> void:
	for i in wheel_positions.size():
		var w := VehicleWheel3D.new()
		w.name = "Wheel%d" % i
		w.position = wheel_positions[i]
		w.wheel_radius = wheel_radius
		w.wheel_rest_length = 0.18
		w.suspension_travel = 1.1          # ضروري — بدونه لا تحمل العجلات السيارة
		w.suspension_stiffness = 13.0
		w.damping_compression = 2.8
		w.damping_relaxation = 3.2
		w.wheel_friction_slip = 1.3
		w.wheel_roll_influence = 0.35
		w.use_as_traction = not front_wheel_indices.has(i)
		w.use_as_steering = front_wheel_indices.has(i)
		add_child(w)

func _build_visual() -> void:
	if visual_path == "":
		return
	var ps: PackedScene = load(visual_path)
	if ps == null:
		push_warning("Vehicle: نموذج مفقود " + visual_path)
		return
	var vis := ps.instantiate()
	vis.name = "Visual"
	vis.rotation.y = _visual_yaw
	vis.scale = Vector3.ONE * visual_scale
	add_child(vis)

func _build_audio() -> void:
	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.name = "EngineAudio"
	var s: AudioStreamWAV = load("res://assets/audio/engine_loop.wav")
	if s:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		_engine_audio.stream = s
		_engine_audio.unit_size = 6.0
	add_child(_engine_audio)

func _build_enter_area() -> void:
	_enter_area = Interactable.new()
	_enter_area.name = "EnterInteractable"
	_enter_area.prompt = "ركوب " + vehicle_name
	_enter_area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	cs.shape = sphere
	cs.position = Vector3(0, 1.2, 0)
	_enter_area.add_child(cs)
	add_child(_enter_area)
	_enter_area.interacted.connect(_on_enter_pressed)

func _on_enter_pressed(player: Node) -> void:
	enter(player)

func enter(player: Node) -> void:
	if driver != null:
		return
	driver = player
	engine_on = true
	_enter_area.enabled = false
	if player.has_method("enter_vehicle"):
		player.enter_vehicle(self)
	entered.emit(player)

func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	engine_on = false
	engine_force = 0.0
	brake = brake_power
	if _enter_area:
		_enter_area.enabled = true
	if p.has_method("exit_vehicle"):
		p.exit_vehicle()
	exited.emit(p)

func _physics_process(delta: float) -> void:
	if driver != null and engine_on:
		var throttle := Input.get_axis("move_back", "move_forward")
		var steer := Input.get_axis("move_right", "move_left")
		var speed := linear_velocity.length()
		if fuel > 0.0:
			engine_force = throttle * engine_power
			fuel = maxf(0.0, fuel - fuel_consumption * absf(throttle) * (1.0 + speed * 0.03) * delta)
			fuel_changed.emit(fuel)
			if fuel <= 0.0:
				engine_force = 0.0
		else:
			engine_force = 0.0
		if throttle == 0.0:
			brake = brake_power * 0.35
		else:
			brake = 0.0
		if Input.is_action_pressed("jump"):
			brake = brake_power
		steering = steer * max_steer * (1.0 - clampf(speed / 40.0, 0.0, 0.55))
		if _engine_audio and _engine_audio.stream:
			if not _engine_audio.playing:
				_engine_audio.play()
			_engine_audio.pitch_scale = 0.75 + speed * 0.035 + absf(throttle) * 0.25
	else:
		engine_force = 0.0
		brake = brake_power * 0.25
		if _engine_audio and _engine_audio.playing:
			_engine_audio.pitch_scale = move_toward(_engine_audio.pitch_scale, 0.6, delta)
			if _engine_audio.pitch_scale <= 0.61:
				_engine_audio.stop()
	_physics_process_net()

func speed_kmh() -> float:
	return linear_velocity.length() * 3.6

func _physics_process_net() -> void:
	var net := get_tree().get_first_node_in_group("network") if get_tree() else null
	if net and net.has_method("check_run_over"):
		net.check_run_over(global_position, speed_kmh(), 1.8)

func refuel_full() -> void:
	fuel = fuel_max
	fuel_changed.emit(fuel)

func on_hit(_damage: float, _from: Node = null) -> void:
	pass
