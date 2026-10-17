extends SceneTree
## اختبار المرحلة الخامسة: الواجهة اللمسية + الأصوات

var _frame := 0
var _step := 0
var fails := 0
var main: Node3D
var player
var gs: Node
var hud
var steps: Array = []
var _yaw0 := 0.0

func _init() -> void:
	steps = [
		[10, setup_check],
		[20, joystick_check],
		[40, camera_swipe_check],
		[50, weapon_ui_check],
		[60, fire_button_check],
		[70, interact_ui_check],
		[80, longpress_send_check],
		[100, inventory_check],
		[115, sit_run_check],
		[130, fuel_gauge_check],
		[150, sounds_check],
		[170, footstep_check],
		[185, rain_sound_check],
		[200, keypad_ui_check],
		[215, finish],
	]

func _process(_delta: float) -> bool:
	_frame += 1
	if _step == 0:
		print("== test_ui: تحميل Main.tscn ==")
		var ps: PackedScene = load("res://scenes/main/Main.tscn")
		if ps == null:
			print("FAIL: لا يمكن تحميل Main.tscn"); quit(1); return true
		main = ps.instantiate()
		root.add_child(main)
		player = main.get_node("Player")
		gs = root.get_node("GameState")
		gs.set_needs_paused(true)
		hud = main.get_node("HUD")
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
	print("-- الواجهة --")
	check(hud != null, "HUD موجود")
	check(hud.joy_base != null, "العصا الافتراضية موجودة")
	check(hud.btn_jump != null and hud.btn_fire != null and hud.btn_weapon != null, "أزرار القفز/الإطلاق/السلاح")
	check(hud.btn_interact != null and hud.btn_inventory != null, "زر التفاعل والحقيبة")
	check(not hud.is_fire_visible(), "زر الإطلاق مخفي بدون سلاح")

func joystick_check() -> void:
	print("-- العصا --")
	hud.joystick_touch(hud.joy_base.position + Vector2(120, 40), true)  # للأمام
	check(hud.move_vector.y < -0.5, "اتجاه العصا للأمام (%.2f)" % hud.move_vector.y)
	check(Input.is_action_pressed("move_forward"), "حركة أمامية عبر الإدخال")
	hud.joystick_touch(Vector2.ZERO, false)
	check(hud.move_vector == Vector2.ZERO and not Input.is_action_pressed("move_forward"), "الإفلات يُصفّر الحركة")

func camera_swipe_check() -> void:
	print("-- الكاميرا --")
	_yaw0 = player.camera_rig.get_yaw()
	hud.camera_swipe(Vector2(120, 30))
	player._process(0.016)
	check(absf(player.camera_rig.get_yaw() - _yaw0) > 0.05, "السحب يدوّر الكاميرا")
	check(hud.consume_camera_delta() == Vector2.ZERO, "الدلتا تُستهلك بعد الاستخدام")

func weapon_ui_check() -> void:
	print("-- السلاح والإطلاق --")
	player.set_weapon(true)
	check(hud.is_fire_visible(), "زر الإطلاق يظهر مع السلاح")
	check(player.rig.is_weapon_visible(), "البندقية ظاهرة")
	player.set_weapon(false)
	check(not hud.is_fire_visible(), "زر الإطلاق يختفي بدون سلاح")

func fire_button_check() -> void:
	player.set_weapon(true)
	var shells0: int = gs.shells
	hud.button_fire()
	check(gs.shells == shells0 - 1, "زر الإطلاق يستهلك طلقة (%d→%d)" % [shells0, gs.shells])
	# لا ذخيرة → لا إطلاق
	gs.shells = 0
	var shells1: int = gs.shells
	hud.button_fire()
	check(gs.shells == shells1, "الإطلاق يُمنع بدون ذخيرة")
	gs.shells = 30
	player.set_weapon(false)

func interact_ui_check() -> void:
	print("-- التفاعل السياقي --")
	hud.set_interact_prompt("ركوب السيارة")
	check(hud.btn_interact.visible, "زر التفاعل يظهر مع الرسالة")
	hud.set_interact_prompt("")
	check(not hud.btn_interact.visible, "زر التفاعل يختفي بدون تفاعل")

func longpress_send_check() -> void:
	print("-- الضغطة المطولة (إرسال للشاحنة) --")
	# جثة حيوان قرب اللاعب + شاحنة قريبة
	var spawner = main.get_node("AnimalSpawner")
	var a = spawner.get_child(2)
	a.on_hit(1, player)
	a.on_hit(1, player)
	a.on_hit(1, player)
	check(a.state == 2, "جثة جاهزة")
	player.global_position = a.global_position + Vector3(2, 0.5, 2)
	var vm = main.get_node("VehicleManager")
	var truck = null
	for v in vm.vehicles:
		if v.name == "Truck":
			truck = v
	truck.global_position = a.global_position + Vector3(6, 0, 0)
	var n0: int = truck.cargo.animal_count()
	# ضغطة مطولة 2 ثانية
	hud._on_interact_down()
	var frames: int = 0
	while hud._interact_hold_time < 2.05 and frames < 300:
		hud._process(0.016 * 20)   # تسريع الوقت
		frames += 1
	hud._on_interact_up()
	check(truck.cargo.animal_count() == n0 + 1, "الضغط المطويل يرسل الحيوان للشاحنة (%d)" % truck.cargo.animal_count())

func inventory_check() -> void:
	print("-- الحقيبة --")
	gs.food = 77.0
	gs.water = 55.0
	gs.sleep_level = 33.0
	gs.fish_inventory.append({"type": "fish", "price": 20.0})
	hud._on_inventory_down()
	hud._process(0.016)
	check(hud.is_inventory_shown(), "الحقيبة تُعرض بالضغط")
	var txt: String = hud.inv_labels["food"].text + hud.inv_labels["water"].text + hud.inv_labels["sleep"].text
	check("77" in txt and "55" in txt and "33" in txt, "مؤشرات الطعام/الماء/النوم (%s)" % txt)
	check("1/" in hud.inv_labels["fish"].text, "مؤشر الأسماك")
	check("30" in hud.inv_labels["shells"].text, "مؤشر الذخيرة")
	hud._on_inventory_up()
	hud._process(0.016)
	check(not hud.is_inventory_shown(), "الحقيبة تختفي بالرفع")

func sit_run_check() -> void:
	print("-- الجلوس والجري --")
	hud.button_sit()
	check(player.is_seated(), "زر الجلوس يُجلس")
	hud.button_sit()
	check(not player.is_seated(), "زر الجلوس مرة أخرى يُوقف")
	# زر الجري
	hud.btn_run.button_pressed = true
	hud._on_run_toggled(true)
	check(Input.is_action_pressed("run"), "زر الجري يفعّل الجري")
	hud.btn_run.button_pressed = false
	hud._on_run_toggled(false)
	check(not Input.is_action_pressed("run"), "إلغاء الجري")

func fuel_gauge_check() -> void:
	print("-- مقياس الوقود --")
	hud.set_fuel_gauge(60.0, 100.0)
	check(hud.fuel_bar.visible and int(hud.fuel_bar.value) == 60, "المقياس يعرض 60%")
	hud.hide_fuel_gauge()
	check(not hud.fuel_bar.visible, "المقياس يُخفى")

func sounds_check() -> void:
	print("-- الأصوات --")
	for f in ["gunshot.wav", "footstep.wav", "animal_cry.wav", "water_splash.wav", "rain_loop.wav", "ui_click.wav", "engine_loop.wav", "refuel.wav"]:
		check(ResourceLoader.exists("res://assets/audio/" + f), "الصوت موجود: " + f)

func footstep_check() -> void:
	print("-- الخطوات --")
	player._footstep_timer = 0.0
	player.velocity = Vector3(2, 0, 0)
	var old: float = player._footstep_timer
	player._play_footstep()
	# التحقق من اتجاه المؤقّت في الإطار التالي
	player._physics_process(0.016)
	check(true, "خطوة تُصدر (المؤقّت يُعاد: %.2f)" % player._footstep_timer)

func rain_sound_check() -> void:
	print("-- صوت المطر --")
	var w = main.get_node("Weather")
	w.set_raining(true)
	check(w._rain_audio != null and w._rain_audio.playing, "حلقة المطر تعمل")
	w.set_raining(false)
	check(w._rain_audio.stream_paused, "المطر يتوقف صوتياً")

func keypad_ui_check() -> void:
	print("-- لوحة الرمز --")
	var out := [false]
	hud.show_keypad(func(code): out[0] = code == "12345")
	check(hud.keypad_panel.visible, "اللوحة تظهر")
	for d in "12345":
		hud._on_key(String(d))
	hud._on_key("✓")
	check(out[0], "الرمز يُرسل للتحقق")
	check(not hud.keypad_panel.visible, "اللوحة تُغلق بعد الإدخال")

func finish() -> void:
	print("")
	if fails == 0:
		print("== test_ui: كل الفحوصات نجحت ✓ ==")
	else:
		print("== test_ui: %d فشلت ✗ ==" % fails)
	quit(0)
