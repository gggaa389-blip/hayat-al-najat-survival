class_name DayNightSystem
extends Node3D
## دورة اليوم/الليل: 24 ساعة لعبة في 10 دقائق حقيقية، شروق/غروب، راتب اليوم

const DAY_REAL_SECONDS := 600.0

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var hour := 8.0
var _last_day_wrap := 0

func setup(world: Node3D) -> void:
	sun = world.get_node_or_null("Sun")
	world_env = world.get_node_or_null("WorldEnvironment")

func _process(delta: float) -> void:
	if sun == null:
		return
	var prev := hour
	hour = fmod(hour + delta * (24.0 / DAY_REAL_SECONDS), 24.0)
	if hour < prev:
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("on_new_day"):
			gs.on_new_day()
	# زاوية الشمس: 6 صباحاً شروق، 12 ظهراً أعلى نقطة، 18 غروب
	var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	var elev := deg_to_rad(12.0 + daylight * 68.0)
	var azim := deg_to_rad(-90.0 + (hour / 24.0) * 360.0)
	sun.rotation = Vector3(-elev, azim, 0)
	sun.light_energy = 0.12 + daylight * 1.15
	# لون دافئ عند الشروق/الغروب
	var warm := clampf(1.0 - absf(daylight - 0.25) * 4.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.35), warm)
	if world_env and world_env.environment:
		var env := world_env.environment
		env.ambient_light_energy = 0.25 + daylight * 0.9

func get_hour() -> float:
	return hour

func is_night() -> bool:
	return hour < 5.5 or hour > 19.5

## للتجارب: قفز الوقت
func set_hour(h: float) -> void:
	hour = fmod(h, 24.0)
