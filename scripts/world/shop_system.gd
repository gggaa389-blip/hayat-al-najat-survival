class_name ShopSystem
extends Node3D
## متاجر السوق: طعام/ماء/ترياق نوم/بيع أسماك/بيع حيوانات + ذخيرة

func setup(world: Node3D) -> void:
	var terrain := world.get_node_or_null("Terrain3D")
	var f := FileAccess.open("res://data/layout.json", FileAccess.READ)
	if f == null:
		push_error("ShopSystem: layout.json مفقود")
		return
	var layout: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	for shop in layout.get("market_shops", []):
		var kind := String(shop.get("kind", ""))
		var x := float(shop.get("x", 0))
		var z := float(shop.get("z", 0))
		var rot := deg_to_rad(float(shop.get("rot", 0)))
		var pos := Vector3(x, 0, z)
		# نقطة التفاعل أمام الباب
		var door := pos + Vector3(sin(rot) * 7.0, 0, cos(rot) * 7.0)
		if terrain and terrain.has_method("get_data"):
			var h: float = terrain.get_data().get_height(door)
			if h > -100.0:
				door.y = h + 1.2
		match kind:
			"food":
				_add(door, "شراء طعام (25)", _buy_food)
			"water":
				_add(door, "شراء ماء (15)", _buy_water)
			"sleep":
				_add(door, "شراء ترياق النوم (80)", _buy_potion)
			"fish":
				_add(door, "بيع كل الأسماك", _sell_fish)
			"animals":
				_add(door, "بيع حيوانات الشاحنة", _sell_animals)
				var door2 := door + Vector3(3.5, 0, 0)
				_add(door2, "شراء ذخيرة: 20 طلقة (100)", _buy_shells)

func _add(pos: Vector3, prompt: String, handler: Callable) -> void:
	var area := Interactable.new()
	area.name = "ShopInteractable"
	area.prompt = prompt
	area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	cs.shape = sphere
	area.add_child(cs)
	add_child(area)
	area.global_position = pos
	area.interacted.connect(func(_p): handler.call())

func _msg(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(text)

func _buy_food() -> void:
	var gs := get_node("/root/GameState")
	_msg("تم شراء الطعام ✓" if gs.buy_food() else "لا تملك مالاً كافياً")

func _buy_water() -> void:
	var gs := get_node("/root/GameState")
	_msg("تم شراء الماء ✓" if gs.buy_water() else "لا تملك مالاً كافياً")

func _buy_potion() -> void:
	var gs := get_node("/root/GameState")
	_msg("تم شراء ترياق النوم ✓ — نمت جيداً" if gs.buy_sleep_potion() else "لا تملك مالاً كافياً")

func _buy_shells() -> void:
	var gs := get_node("/root/GameState")
	_msg("20 طلقة جديدة ✓" if gs.buy_shells() else "لا تملك مالاً كافياً")

func _sell_fish() -> void:
	var gs := get_node("/root/GameState")
	var total: float = gs.sell_all_fish()
	_msg(("بعت الأسماك بـ %.0f" % total) if total > 0 else "لا أسماك معك")

func _sell_animals() -> void:
	var gs := get_node("/root/GameState")
	var vm := get_tree().get_first_node_in_group("vehicle_manager")
	if vm == null:
		_msg("لا توجد شاحنة")
		return
	var truck: Vehicle = vm.nearest_vehicle(global_position, 30.0)
	if truck == null or truck.cargo == null:
		_msg("لا توجد شاحنة قريبة")
		return
	var items: Array = truck.cargo.unload_all_animals()
	if items.is_empty():
		_msg("الشاحنة فارغة")
		return
	var total: float = gs.sell_animals(items)
	_msg("بعت %d حيوانات بـ %.0f" % [items.size(), total])
