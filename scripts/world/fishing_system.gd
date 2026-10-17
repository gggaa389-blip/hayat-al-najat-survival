class_name FishingSystem
extends Node3D

var _last_fish_count := 0
## الصيد بالصنارة عند منصة البحيرة: سمكة كل دقيقة، حد 10، يتوقف عند الامتلاء

func setup(world: Node3D) -> void:
	var terrain := world.get_node_or_null("Terrain3D")
	var pos := Vector3(1152.2, 0, 318.0)   # منصة الصيد (من layout)
	if terrain and terrain.has_method("get_data"):
		var h: float = terrain.get_data().get_height(pos)
		if h > -100.0:
			pos.y = h + 1.2
	var area := Interactable.new()
	area.name = "FishingInteractable"
	area.prompt = "الصيد بالصنارة"
	area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.2
	cs.shape = sphere
	cs.position = Vector3(0, 1.0, 0)
	area.add_child(cs)
	add_child(area)
	area.global_position = pos
	area.interacted.connect(_on_fishing)

func _process(_delta: float) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var n: int = gs.fish_inventory.size()
	if n > _last_fish_count:
		_play_splash()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			hud.show_message("اصطدت سمكة! (%d/%d)" % [n, gs.max_fish])
	_last_fish_count = n

func _play_splash() -> void:
	var sfx := AudioStreamPlayer3D.new()
	var stream: AudioStreamWAV = load("res://assets/audio/water_splash.wav")
	if stream:
		sfx.stream = stream
		sfx.global_position = global_position
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

func _on_fishing(_player: Node) -> void:
	var gs := get_node_or_null("/root/GameState")
	var hud := get_tree().get_first_node_in_group("hud")
	if gs == null:
		return
	if gs.fishing_active:
		gs.stop_fishing()
		if hud and hud.has_method("show_message"):
			hud.show_message("توقف الصيد — معك %d سمكة" % gs.fish_inventory.size())
	else:
		gs.start_fishing()
		if hud and hud.has_method("show_message"):
			hud.show_message("بدأ الصيد! سمكة كل دقيقة (الحد %d)" % gs.max_fish)
