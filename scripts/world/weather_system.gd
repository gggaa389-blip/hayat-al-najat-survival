class_name WeatherSystem
extends Node3D
## مطر دوري: جزيئات تتبع الكاميرا (خفيفة على الهواتف) + تعتيم خفيف

var raining := false
var _rain: GPUParticles3D = null
var _timer := 0.0
var _rain_audio: AudioStreamPlayer = null
var _next_change := 240.0
var day_night: DayNightSystem

func setup(dn: DayNightSystem) -> void:
	day_night = dn
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 420
	_rain.lifetime = 1.2
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 30, 50))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 3.0
	mat.gravity = Vector3(0, -22, 0)
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(24, 4, 24)
	_rain.process_material = mat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.42, 0.018)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.65, 0.72, 0.85, 0.55)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	_rain.draw_pass_1 = mesh
	add_child(_rain)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_change:
		_timer = 0.0
		_next_change = randf_range(180.0, 420.0)
		set_raining(not raining)
	# الجزيئات تتبع اللاعب (لا تكلفة تقريباً)
	if _rain:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			_rain.global_position = player.global_position + Vector3(0, 8, 0)

func set_raining(on: bool) -> void:
	raining = on
	if _rain:
		_rain.emitting = on
	if on and _rain_audio == null:
		_rain_audio = AudioStreamPlayer.new()
		var s: AudioStreamWAV = load("res://assets/audio/rain_loop.wav")
		if s:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
			_rain_audio.stream = s
			_rain_audio.volume_db = -6.0
			add_child(_rain_audio)
			_rain_audio.play()
	if _rain_audio:
		_rain_audio.stream_paused = not on
	if day_night and day_night.sun:
		day_night.sun.light_energy *= (0.62 if on else 1.0)

func is_raining() -> bool:
	return raining
