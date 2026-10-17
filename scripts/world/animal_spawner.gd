class_name AnimalSpawner
extends Node3D
## يوزع الحيوانات في البراري والغابة وقرب البحيرات

const TYPES := ["cow", "pig", "deer", "bunny", "chick"]
const COUNT := 26

func setup(world: Node3D) -> void:
	var terrain := world.get_node_or_null("Terrain3D")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var zones := [
		Vector3(320, 0, 320),    # الغابة
		Vector3(430, 0, 430),
		Vector3(800, 0, 550),    # السهول
		Vector3(1000, 0, 650),
		Vector3(1100, 0, 420),   # قرب البحيرة الأولى
		Vector3(750, 0, 1050),
	]
	for i in COUNT:
		var zone: Vector3 = zones[i % zones.size()]
		var pos := zone + Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45))
		if terrain and terrain.has_method("get_data"):
			var h: float = terrain.get_data().get_height(pos)
			if h < -5.0:
				continue
			pos.y = h + 0.2
		var a := Animal.new()
		a.type_name = TYPES[i % TYPES.size()]
		match a.type_name:
			"cow": a.model_scale = 1.15
			"pig": a.model_scale = 1.0
			"deer": a.model_scale = 1.1
			"bunny": a.model_scale = 0.75
			"chick": a.model_scale = 0.6
		add_child(a)
		a.global_position = pos

func animal_count() -> int:
	return get_child_count()
