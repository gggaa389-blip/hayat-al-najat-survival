class_name Player
extends CharacterBody3D
## اللاعب: حركة، قفز، جلوس، نوم، سلاح، قيادة مركبات

enum Mode { ROAM, SIT, SLEEP, DRIVING }
enum WeaponState { HIDDEN, SHOWN }

@export var config: CharacterConfig

var mode: Mode = Mode.ROAM
var weapon_equipped := false
var vehicle = null
var weapon_state: WeaponState = WeaponState.HIDDEN
var camera_rig: PlayerCameraRig
var rig: CharacterRig
var detector: InteractionDetector
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _seat_node: Node3D = null
var _seat_pos := Vector3.ZERO
var _seat_yaw := 0.0
var jump_ready := true
var _jump_y0 := 0.0
var _footstep_timer := 0.0

signal mode_changed(mode: Mode)
signal weapon_changed(shown: bool)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 32
	if config == null:
		config = load("res://data/character_default.tres")
	rig = CharacterRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(config)
	camera_rig = PlayerCameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	detector = InteractionDetector.new()
	detector.name = "Detector"
	detector.player = self
	add_child(detector)
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if mode == Mode.DRIVING:
		_process_driving()
		return
	if mode != Mode.ROAM:
		_process_seated()
		return
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_forward", "move_back")
	var cam_yaw := camera_rig.get_yaw() if camera_rig else 0.0
	var dir := (global_transform.basis * Vector3(input.x, 0, input.y))
	dir = dir.rotated(Vector3.UP, cam_yaw).normalized() if dir.length() > 0.1 else Vector3.ZERO
	var running := Input.is_action_pressed("run")
	var speed := config.run_speed if running else config.move_speed
	if dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, dir.x * speed, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, speed * 8.0 * delta)
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
		if velocity.y > 1.0:
			if rig.current_clip() != config.anim_jump_start:
				rig.play_state("jump_start")
			else:
				rig.play_state("jump_loop")
		else:
			rig.play_state("jump_loop")
	else:
		if _jump_y0 > 0.0 and global_position.y < _jump_y0 + 0.5:
			if rig.current_clip() != config.anim_jump_land:
				rig.play_state("jump_land")
			_jump_y0 = 0.0
		elif dir.length() > 0.1:
			if weapon_equipped and weapon_state == WeaponState.SHOWN:
				rig.play_state("carry_run" if running else "carry_walk")
			else:
				rig.play_state("run" if running else "walk")
		else:
			if weapon_equipped and weapon_state == WeaponState.SHOWN:
				rig.play_state("carry_idle")
			else:
				rig.play_state("idle")
	# أصوات الخطوات
	_footstep_timer -= delta
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.2:
		if _footstep_timer <= 0.0:
			_play_footstep()
			_footstep_timer = 0.32 if running else 0.46
	move_and_slide()

func _process(delta: float) -> void:
	if camera_rig == null:
		return
	# سحب الكاميرا من الواجهة اللمسية
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var cd: Vector2 = hud.consume_camera_delta()
		if cd != Vector2.ZERO:
			camera_rig.add_yaw(cd.x * 2.2)
			camera_rig.add_pitch(-cd.y * 2.2)
		if mode == Mode.DRIVING and vehicle:
			hud.set_fuel_gauge(vehicle.fuel, vehicle.fuel_max)
	if mode != Mode.ROAM:
		return
	# مؤشر التصويب يحمر عند استهداف حيوان
	if hud and hud.has_method("set_reticle_red"):
		var cam := camera_rig.camera()
		if cam:
			var space := get_world_3d().direct_space_state
			var from: Vector3 = cam.global_position
			var to: Vector3 = from - cam.global_transform.basis.z * 60.0
			var q := PhysicsRayQueryParameters3D.create(from, to, 8)
			q.collide_with_areas = true
			var hit: Dictionary = space.intersect_ray(q)
			var is_animal := false
			if hit and hit.collider and hit.collider.has_method("is_animal"):
				is_animal = true
			hud.set_reticle_red(is_animal)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if mode == Mode.DRIVING:
			if vehicle != null and vehicle.has_method("exit"):
				vehicle.exit()
			else:
				exit_vehicle()
		elif mode != Mode.ROAM:
			_stand_up()
		elif detector.try_interact():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") and mode == Mode.ROAM and is_on_floor():
		velocity.y = config.jump_velocity
		_jump_y0 = global_position.y
		rig.play_state("jump_start")
	elif event.is_action_pressed("weapon_toggle") and mode == Mode.ROAM:
		set_weapon(not weapon_equipped)
	elif event.is_action_pressed("fire") and weapon_equipped and weapon_state == WeaponState.SHOWN:
		_fire()
	elif event.is_action_pressed("aim") and weapon_equipped:
		camera_rig.toggle_aim()

# ---------------------------------------------------------------- الجلوس والنوم
func sit_at(seat: Node3D, yaw: float) -> void:
	if mode != Mode.ROAM:
		return
	mode = Mode.SIT
	_seat_node = seat
	_seat_pos = seat.global_position
	_seat_yaw = yaw
	velocity = Vector3.ZERO
	collision_layer = 0
	mode_changed.emit(mode)
	rig.play_state("sit_down")
	await get_tree().create_timer(0.45).timeout
	if mode == Mode.SIT:
		rig.play_state("sit_idle")

func is_seated() -> bool:
	return mode == Mode.SIT or mode == Mode.SLEEP

func sit_down(seat: Node3D) -> void:
	sit_at(seat, seat.global_rotation.y)

func sleep_on(bed: Node3D) -> void:
	if mode != Mode.ROAM:
		return
	mode = Mode.SLEEP
	_seat_node = bed
	_seat_pos = bed.global_position
	_seat_yaw = bed.global_rotation.y
	velocity = Vector3.ZERO
	collision_layer = 0
	mode_changed.emit(mode)
	rig.play_state("sleep_down")
	await get_tree().create_timer(0.6).timeout
	if mode == Mode.SLEEP:
		rig.play_state("sleep_idle")
		while mode == Mode.SLEEP:
			await get_tree().create_timer(1.0).timeout
			var gs := get_node_or_null("/root/GameState")
			if gs:
				gs.sleep(4.0)

func _stand_up() -> void:
	if mode == Mode.SIT:
		rig.play_state("sit_up")
	elif mode == Mode.SLEEP:
		rig.play_state("sleep_up")
	else:
		return
	mode = Mode.ROAM
	_seat_node = null
	collision_layer = 2
	global_position = _seat_pos + Vector3(sin(_seat_yaw + PI) * 1.2, 0.1, cos(_seat_yaw + PI) * 1.2)
	mode_changed.emit(mode)

func _process_seated() -> void:
	var mi := Input.get_axis("move_back", "move_forward")
	var ms := Input.get_axis("move_left", "move_right")
	if absf(mi) > 0.15 or absf(ms) > 0.15:
		_stand_up()
		return
	velocity = Vector3.ZERO
	global_position = global_position.lerp(_seat_pos + Vector3(0, 0.35, 0), 0.25)
	rotation.y = lerp_angle(rotation.y, _seat_yaw, 0.25)
	if rig.current_clip() == "":
		rig.play_state("sit_idle" if mode == Mode.SIT else "sleep_idle")

# ---------------------------------------------------------------- القيادة
func enter_vehicle(v: Node) -> void:
	if mode != Mode.ROAM:
		return
	mode = Mode.DRIVING
	vehicle = v
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1 | 4 | 8
	camera_rig.set_follow_length(v.camera_length)
	camera_rig.snap_behind(v.global_rotation.y)
	rig.play_state("sit_idle")
	mode_changed.emit(mode)

func exit_vehicle() -> void:
	if mode != Mode.DRIVING or vehicle == null:
		return
	var v = vehicle
	vehicle = null
	mode = Mode.ROAM
	if v.get("driver") == self:
		v.driver = null
	var area = v.get("_enter_area")
	if area != null:
		area.enabled = true
	collision_layer = 2
	var side: Vector3 = v.global_transform.basis * Vector3(2.4, 0, 0)
	global_position = v.global_position + side + Vector3(0, 0.2, 0)
	camera_rig.restore_length()
	rig.play_state("idle")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_fuel_gauge"):
		hud.hide_fuel_gauge()
	mode_changed.emit(mode)

func _process_driving() -> void:
	if vehicle == null:
		mode = Mode.ROAM
		return
	var seat: Vector3 = vehicle.global_transform.basis * vehicle.seat_offset
	global_position = vehicle.global_position + seat
	rig.rotation.y = vehicle.global_rotation.y
	if rig.current_clip() != config.anim_sit_idle:
		rig.play_state("sit_idle")

# ---------------------------------------------------------------- السلاح
func set_weapon(v: bool) -> void:
	if mode == Mode.DRIVING:
		return
	weapon_equipped = v
	weapon_state = WeaponState.SHOWN if v else WeaponState.HIDDEN
	if v:
		rig.show_weapon()
	else:
		rig.hide_weapon()
	weapon_changed.emit(v)
	rig.play_state("carry_idle" if v else "idle")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_weapon_ui"):
		hud.set_weapon_ui(v)

func _play_footstep() -> void:
	var sfx := AudioStreamPlayer3D.new()
	var stream: AudioStreamWAV = load("res://assets/audio/footstep.wav")
	if stream:
		sfx.stream = stream
		sfx.global_position = global_position
		sfx.unit_size = 4.0
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

func _fire() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("spend_shell"):
		if not gs.spend_shell():
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_message"):
				hud.show_message("لا ذخيرة! اشترِ طلقات من متجر الحيوانات")
			return
	rig.play_state("shoot")
	var cam := camera_rig.camera()
	var space := get_world_3d().direct_space_state
	var from: Vector3 = cam.global_position
	var to: Vector3 = from - cam.global_transform.basis.z * 80.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 32)
	q.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(q)
	if hit and hit.collider and hit.collider.has_method("on_hit"):
		if hit.collider.has_method("is_remote_player") and hit.collider.is_remote_player():
			hit.collider.on_hit(34.0, self)
		else:
			hit.collider.on_hit(1, self)
	# ضجيج الطلق يخيف الحيوانات
	if gs and gs.has_method("emit_noise"):
		gs.emit_noise(global_position, 40.0)
	var sfx := AudioStreamPlayer3D.new()
	var stream: AudioStreamWAV = load("res://assets/audio/gunshot.wav")
	if stream:
		sfx.stream = stream
		sfx.global_position = global_position
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	mode = Mode.ROAM
	vehicle = null
	collision_layer = 2
	rig.play_state("idle")
	mode_changed.emit(mode)
