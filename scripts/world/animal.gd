class_name Animal
extends CharacterBody3D
## حيوان: تجول، هروب من اللاعب والطلقات، 3 إصابات للقتل، جثة تُحمَّل في الشاحنة

enum State { WANDER, FLEE, DEAD }

@export var type_name := "cow"
@export var model_scale := 1.0

var state: State = State.WANDER
var health := 3
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var flee_dir := Vector3.ZERO
var flee_timer := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _visual: Node3D = null
var _load_area: Interactable = null

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 4
	add_to_group("animals")
	home = global_position
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.2
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	var path := "res://assets/models/animals/animal-%s.glb" % type_name
	var ps: PackedScene = load(path)
	if ps:
		_visual = ps.instantiate()
		_visual.scale = Vector3.ONE * model_scale
		add_child(_visual)
	_pick_wander()

func is_animal() -> bool:
	return true

func _pick_wander() -> void:
	wander_target = home + Vector3(randf_range(-16, 16), 0, randf_range(-16, 16))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	var dir := Vector3.ZERO
	match state:
		State.WANDER:
			dir = wander_target - global_position
			dir.y = 0
			if dir.length() < 1.5:
				_pick_wander()
				dir = Vector3.ZERO
			dir = dir.normalized() * 1.4
			# الهروب عند اقتراب اللاعب
			var player := get_tree().get_first_node_in_group("player")
			if player and global_position.distance_to(player.global_position) < 11.0:
				_start_flee(player.global_position)
		State.FLEE:
			dir = flee_dir * 6.2
			flee_timer -= delta
			if flee_timer <= 0.0:
				state = State.WANDER
	velocity.x = dir.x
	velocity.z = dir.z
	if dir.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	move_and_slide()
	_check_run_over()

func _start_flee(from: Vector3) -> void:
	if state != State.FLEE:
		_play_cry()
	state = State.FLEE
	flee_timer = 6.0
	flee_dir = (global_position - from)
	flee_dir.y = 0
	if flee_dir.length() < 0.1:
		flee_dir = Vector3.RIGHT
	flee_dir = flee_dir.normalized()

func _play_cry() -> void:
	var sfx := AudioStreamPlayer3D.new()
	var stream: AudioStreamWAV = load("res://assets/audio/animal_cry.wav")
	if stream:
		sfx.stream = stream
		sfx.global_position = global_position
		sfx.unit_size = 8.0
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

func on_hit(damage: float, _from: Node = null) -> void:
	if state == State.DEAD:
		return
	health -= damage
	var player := get_tree().get_first_node_in_group("player")
	_start_flee(player.global_position if player else global_position + Vector3.ONE)
	if health <= 0:
		_die()

func _check_run_over() -> void:
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v is Vehicle and v.speed_kmh() > 7.0 and v.global_position.distance_to(global_position) < 2.6:
			_die()
			return

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	if _visual:
		_visual.rotation.x = PI * 0.45   # استلقاء الجثة
	# تفاعل: حمل في أقرب شاحنة
	_load_area = Interactable.new()
	_load_area.name = "LoadInteractable"
	_load_area.prompt = "حمل %s إلى الشاحنة" % type_name
	_load_area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	cs.shape = sphere
	cs.position = Vector3(0, 0.8, 0)
	_load_area.add_child(cs)
	add_child(_load_area)
	_load_area.interacted.connect(_on_load)

func _on_load(player: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var vm := get_tree().get_first_node_in_group("vehicle_manager")
	var truck: Vehicle = null
	if vm and vm.has_method("nearest_vehicle"):
		truck = vm.nearest_vehicle(player.global_position, 18.0)
	if truck == null or truck.cargo == null:
		if hud and hud.has_method("show_message"):
			hud.show_message("لا توجد شاحنة قريبة")
		return
	var item := {"type": type_name, "price": _price()}
	if truck.cargo.load_animal(item):
		if hud and hud.has_method("show_message"):
			hud.show_message("حُمّل %s (%d/5)" % [type_name, truck.cargo.animal_count()])
		queue_free()
	else:
		if hud and hud.has_method("show_message"):
			hud.show_message("الشاحنة ممتلئة (5 حيوانات كحد أقصى)")

## إرسال للشاحنة (ضغطة مطولة 2 ثانية من الواجهة) — يعمل حتى لو كانت الشاحنة بعيدة قليلاً
func send_to_truck(player: Node) -> bool:
	if state != State.DEAD:
		return false
	var vm := get_tree().get_first_node_in_group("vehicle_manager")
	var truck: Vehicle = null
	if vm and vm.has_method("nearest_vehicle"):
		truck = vm.nearest_vehicle(player.global_position, 40.0)
	if truck == null or truck.cargo == null:
		return false
	if truck.cargo.load_animal({"type": type_name, "price": _price()}):
		queue_free()
		return true
	return false

func _price() -> float:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		return float(gs.ANIMAL_PRICES.get(type_name, 50.0))
	return 50.0
