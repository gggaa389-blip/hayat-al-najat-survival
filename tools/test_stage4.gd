extends SceneTree
## اختبار المرحلة الرابعة: الحيوانات، الصيد، الاقتصاد، البقاء، اليوم/الليل، NPC
## كل خطوة مرتبط برقم إطار — لا awaits (توقيتات متزامنة)

var _frame := 0
var _step := 0
var fails := 0
var main: Node3D
var player
var gs: Node
var steps: Array = []
var _flee_d0 := 0.0
var _flee_animal: Node = null
var _n0 := Vector3.ZERO

func _init() -> void:
	steps = [
		[10, setup_check],
		[20, animal_spawn_check],
		[26, flee_start],
		[70, flee_verify],
		[76, hunting_check],
		[86, carcass_load_check],
		[92, fishing_start],
		[145, fishing_verify],
		[151, fishcap_start],
		[205, fishcap_verify],
		[211, economy_check],
		[217, needs_check],
		[223, death_start],
		[245, death_verify],
		[251, day_pay_check],
		[257, loan_check],
		[263, daynight_start],
		[285, daynight_verify],
		[291, weather_check],
		[297, npc_start],
		[325, npc_verify],
		[330, finish],
	]

func _process(_delta: float) -> bool:
	_frame += 1
	if _step == 0:
		print("== test_stage4: تحميل Main.tscn ==")
		var ps: PackedScene = load("res://scenes/main/Main.tscn")
		if ps == null:
			print("FAIL: لا يمكن تحميل Main.tscn"); quit(1); return true
		main = ps.instantiate()
		root.add_child(main)
		player = main.get_node("Player")
		gs = root.get_node("GameState")
		gs.set_needs_paused(true)
		_step = 1
		return false
	while _step <= steps.size() and _frame >= steps[_step - 1][0]:
		var fn: Callable = steps[_step - 1][1]
		_step += 1
		fn.call()
		if _step > steps.size():
			return true
	return false

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		fails += 1

func setup_check() -> void:
	print("-- الإعداد --")
	check(main.get_node_or_null("AnimalSpawner") != null, "مولّد الحيوانات موجود")
	check(main.get_node_or_null("FishingSystem") != null, "نظام الصيد موجود")
	check(main.get_node_or_null("ShopSystem") != null, "نظام المتاجر موجود")
	check(main.get_node_or_null("DayNight") != null, "دورة اليوم موجودة")
	check(main.get_node_or_null("Weather") != null, "نظام الطقس موجود")
	check(main.get_node_or_null("NPCSystem") != null, "نظام NPC موجود")

func animal_spawn_check() -> void:
	print("-- الحيوانات --")
	var spawner = main.get_node("AnimalSpawner")
	check(spawner.animal_count() >= 18, "الحيوانات موزعة (%d)" % spawner.animal_count())
	var types := {}
	for a in spawner.get_children():
		types[a.type_name] = true
	check(types.size() >= 4, "أنواع متعددة (%d)" % types.size())
	check(gs.ANIMAL_PRICES.has("cow") and gs.ANIMAL_PRICES["cow"] == 400.0, "أسعار كل نوع معرفة")

func flee_start() -> void:
	print("-- الهروب --")
	var spawner = main.get_node("AnimalSpawner")
	_flee_animal = spawner.get_child(0)
	player.global_position = _flee_animal.global_position + Vector3(4, 0.6, 4)
	_flee_d0 = _flee_animal.global_position.distance_to(player.global_position)
	# فعّل الهروب مباشرة (كما لو اقترب اللاعب)
	_flee_animal._start_flee(player.global_position)
	check(_flee_animal.state == 1, "الحالة: هروب (FLEE)")

func flee_verify() -> void:
	var d1: float = _flee_animal.global_position.distance_to(player.global_position)
	check(d1 > _flee_d0 + 1.2, "الحيوان يبتعد عن اللاعب (%.1f→%.1f م)" % [_flee_d0, d1])

func hunting_check() -> void:
	print("-- الصيد بالبندقية --")
	check(gs.shells > 0, "ذخيرة متوفرة (%d)" % gs.shells)
	var spawner = main.get_node("AnimalSpawner")
	var a = spawner.get_child(1)
	var shells0: int = gs.shells
	a.on_hit(1, player)
	a.on_hit(1, player)
	check(a.health == 1, "3 إصابات للقتل (متبقٍ %d)" % a.health)
	a.on_hit(1, player)
	check(a.state == 2, "الحيوان يموت بعد 3 إصابات")
	# الجثة قابلة للحمل
	check(a.get_node_or_null("LoadInteractable") != null, "الجثة لها تفاعل حمل")

func carcass_load_check() -> void:
	print("-- الحمولة والبيع --")
	var vm = main.get_node("VehicleManager")
	var truck = null
	for v in vm.vehicles:
		if v.name == "Truck":
			truck = v
	check(truck != null and truck.cargo != null, "الشاحنة بحمولة")
	var loaded := 0
	for i in 6:
		if truck.cargo.load_animal({"type": "cow", "price": 400.0}):
			loaded += 1
	check(loaded == 5, "سعة الحيوانات صارمة (حُمّل %d/5)" % loaded)
	truck.cargo.unload_all_animals()
	for i in 3:
		truck.cargo.load_animal({"type": "cow", "price": 400.0})
	truck.cargo.load_animal({"type": "bunny", "price": 120.0})
	var m0: float = gs.money
	var total: float = gs.sell_animals(truck.cargo.unload_all_animals())
	check(is_equal_approx(total, 1320.0), "بيع حسب النوع (3 بقرة + أرنب = %.0f)" % total)
	check(gs.money > m0, "المال يزيد بالبيع")

func fishing_start() -> void:
	print("-- الصيد بالصنارة --")
	gs.fish_inventory.clear()
	gs.start_fishing()
	check(gs.fishing_active, "الصيد بدأ")
	gs.fishing_timer = gs.FISH_INTERVAL - 0.25

func fishing_verify() -> void:
	check(gs.fish_inventory.size() >= 1, "سمكة بعد الدقيقة (%d)" % gs.fish_inventory.size())
	check(gs.fish_inventory.size() <= gs.max_fish, "الحد الأقصى مُحترم")

func fishcap_start() -> void:
	gs.fish_inventory.clear()
	for i in 12:
		gs.add_fish("fish", 20.0)
	check(gs.fish_inventory.size() == 10, "الحد 10 أسماك (%d)" % gs.fish_inventory.size())
	gs.fishing_timer = gs.FISH_INTERVAL - 0.2

func fishcap_verify() -> void:
	check(gs.fish_inventory.size() == 10, "الصيد يتوقف عند الامتلاء (%d)" % gs.fish_inventory.size())
	gs.stop_fishing()

func economy_check() -> void:
	print("-- الاقتصاد --")
	var m0: float = gs.money
	var total: float = gs.sell_all_fish()
	check(total > 0 and gs.money == m0 + total, "بيع الأسماك (%.0f)" % total)
	check(gs.buy_food(), "شراء الطعام يعمل")
	check(gs.buy_water(), "شراء الماء يعمل")
	check(gs.buy_sleep_potion(), "شراء ترياق النوم يعمل")
	check(gs.buy_shells(), "شراء الذخيرة يعمل")
	gs.money = 1.0
	check(not gs.buy_food(), "الشراء يُمنع بدون مال كافٍ")
	gs.money = 2000.0

func needs_check() -> void:
	print("-- الاحتياجات --")
	gs.food = 20.0
	gs.water = 20.0
	gs.sleep_level = 20.0
	gs.eat(35.0)
	gs.drink(40.0)
	gs.sleep(70.0)
	check(gs.food == 55.0 and gs.water == 60.0 and gs.sleep_level == 90.0,
		"الأكل/الشرب/النوم (%d/%d/%d)" % [int(gs.food), int(gs.water), int(gs.sleep_level)])

func death_start() -> void:
	print("-- الموت والإحياء --")
	gs.food = 0.0
	gs.health = 1.0
	gs.set_needs_paused(false)

func death_verify() -> void:
	gs.set_needs_paused(true)
	check(gs.food > 0, "الاحتياجات تُستعاد بعد الإحياء (%d)" % int(gs.food))
	check(player.global_position.distance_to(Vector3(702, player.global_position.y, 924)) < 6.0,
		"الإحياء عند المنزل")
	check(gs.health == 100.0, "الصحة تُستعاد")

func day_pay_check() -> void:
	print("-- راتب اليوم --")
	gs.house_visited_since_pay = false
	var m0: float = gs.money
	gs.on_new_day()
	check(gs.money == m0 - 500.0, "بدون زيارة: −500")
	gs.register_house_visit()
	var m1: float = gs.money
	gs.on_new_day()
	check(gs.money == m1 + 500.0, "مع زيارة: +500")

func loan_check() -> void:
	print("-- القرض --")
	var m0: float = gs.money
	gs.request_loan(700.0)
	check(gs.pending_loan_amount == 700.0, "طلب القرض مسجل")
	gs.friend_approves_loan()
	check(gs.money == m0 + 700.0, "موافقة الصديق تُحوّل المال")
	gs.request_loan(300.0)
	var m1: float = gs.money
	gs.friend_denies_loan()
	check(gs.money == m1, "رفض الصديق لا يُحوّل شيئاً")

func daynight_start() -> void:
	print("-- دورة اليوم/الليل --")
	var dn = main.get_node("DayNight")
	dn.set_hour(12.0)
	check(not dn.is_night(), "الظهيرة ليست ليلاً")
	check(dn.sun.light_energy > 0.5, "الشمس نهاراً قوية")
	dn.set_hour(23.0)
	check(dn.is_night(), "23:00 ليل")
	dn.set_hour(12.0)

func daynight_verify() -> void:
	var dn = main.get_node("DayNight")
	check(absf(dn.get_hour() - 12.0) > 0.001, "الوقت يتحرك (%.3f)" % dn.get_hour())

func weather_check() -> void:
	print("-- الطقس --")
	var w = main.get_node("Weather")
	w.set_raining(true)
	check(w.is_raining(), "المطر يعمل")
	check(w._rain.emitting, "الجسيمات تُطلق")
	w.set_raining(false)

func npc_start() -> void:
	print("-- NPC --")
	var npc = main.get_node("NPCSystem")
	check(npc.pedestrian_count() >= 6, "مشاة NPC (%d)" % npc.pedestrian_count())
	check(npc.traffic_count() >= 3, "مركبات مرور (%d)" % npc.traffic_count())
	_n0 = npc.pedestrians[0]["node"].global_position

func npc_verify() -> void:
	var npc = main.get_node("NPCSystem")
	var n1: Vector3 = npc.pedestrians[0]["node"].global_position
	check(_n0.distance_to(n1) > 0.15, "المشاة يتحركون (%.2f م)" % _n0.distance_to(n1))
	var t1: Vector3 = npc.traffic[0]["node"].global_position
	check(t1.distance_to(Vector3.ZERO) > 1.0, "مركبات المرور في مواضعها")

func finish() -> void:
	print("")
	if fails == 0:
		print("== test_stage4: كل الفحوصات نجحت ✓ ==")
	else:
		print("== test_stage4: %d فشلت ✗ ==" % fails)
	quit(0)
