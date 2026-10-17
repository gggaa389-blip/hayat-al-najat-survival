extends SceneTree
## اختبار المرحلة الأولى: تحميل المشهد والتحقق من الأنظمة الأساسية
var _done := false
var _frame := 0
var _world: Node3D
var fails := 0

func _process(_delta: float) -> bool:
	_frame += 1
	if not _done:
		_done = true
		print("== test_world: تحميل المشهد ==")
		var ps: PackedScene = load("res://scenes/world/World.tscn")
		if ps == null:
			print("FAIL: لا يمكن تحميل World.tscn"); quit(1); return true
		_world = ps.instantiate()
		root.add_child(_world)
		return false
	if _frame < 3:
		return false   # ننتظر عدة إطارات لتهيئة الفيزياء والتضاريس
	_run_checks()
	quit(0)
	return true

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		fails += 1

func _run_checks() -> void:
	print("-- التضاريس --")
	var terrain := _world.get_node_or_null("Terrain3D")
	check(terrain != null, "عقدة Terrain3D موجودة")
	if terrain:
		var h_town: float = terrain.get_data().get_height(Vector3(500, 0, 800))
		var h_lake: float = terrain.get_data().get_height(Vector3(1150, 0, 300))
		var h_forest: float = terrain.get_data().get_height(Vector3(320, 0, 320))
		check(h_town > 2.0 and h_town < 8.0, "ارتفاع البلدة مسطح (%.2f)" % h_town)
		check(h_lake < 0.0, "قاع البحيرة غارق (%.2f)" % h_lake)
		check(h_forest > 3.0, "ارتفاع الغابة (%.2f)" % h_forest)

	print("-- المناطق --")
	var town := _world.get_node_or_null("Town")
	var market := _world.get_node_or_null("Market")
	var gas := _world.get_node_or_null("GasStations")
	var signs := _world.get_node_or_null("Signs")
	var water := _world.get_node_or_null("Water")
	var roads := _world.get_node_or_null("Roads")
	var foliage := _world.get_node_or_null("Foliage")
	var phouse := _world.get_node_or_null("PlayerHouse")
	check(town != null and town.get_child_count() >= 8, "البلدة (%d عنصر)" % (town.get_child_count() if town else 0))
	check(market != null and market.get_child_count() >= 15, "السوق (%d عنصر)" % (market.get_child_count() if market else 0))
	check(gas != null and gas.get_child_count() == 3, "3 محطات وقود")
	check(signs != null and signs.get_child_count() >= 6, "اللوحات (%d)" % (signs.get_child_count() if signs else 0))
	check(water != null and water.get_child_count() == 2, "بحيرتان")
	check(roads != null and roads.get_child_count() > 100, "الطرق (%d عنصر)" % (roads.get_child_count() if roads else 0))
	check(foliage != null, "عقدة النباتات")

	print("-- الغابة --")
	if foliage:
		var total := 0
		for c in foliage.get_children():
			if c is MultiMeshInstance3D:
				total += c.multimesh.instance_count
		check(total > 1500, "الأشجار/النباتات (%d نسخة)" % total)

	print("-- منزل اللاعب --")
	if phouse:
		check(phouse.get_node_or_null("House") != null, "المنزل موجود")
		check(phouse.get_node_or_null("House/Roof") != null, "السقف القابل للإخفاء موجود")
		check(phouse.get_node_or_null("Gate") != null, "البوابة موجودة")
		check(phouse.get_node_or_null("Gate/Keypad") != null, "لوحة الرمز موجودة")
		check(phouse.get_node_or_null("Barn") != null, "الحظيرة موجودة")
		check(phouse.get_node_or_null("Car") != null, "السيارة موجودة")
		check(phouse.get_node_or_null("Truck") != null, "الشاحنة موجودة")

	print("-- الفيزياء --")
	var space := root.get_world_3d().direct_space_state
	var from := Vector3(500, 80, 800)
	var to := Vector3(500, -20, 800)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(q)
	check(hit.size() > 0, "شعاع يصطدم بالأرض/الطريق عند البلدة")
	if hit.size() > 0:
		print("    نقطة الاصطدام: %s" % str(hit.position))

	print("")
	if fails == 0:
		print("== test_world: كل الفحوصات نجحت ✓ ==")
	else:
		print("== test_world: %d فشلت ✗ ==" % fails)
