extends SceneTree
## اختبار المرحلة الثانية: الشخصية والحركة
## جدول خطوات مرتبط برقم الإطار: [رقم_الإطار, دالة]
var _frame := 0
var _step := 0
var fails := 0
var main: Node3D
var player: Player
var gs: Node
var start_pos := Vector3.ZERO
var jump_y0 := 0.0
var steps: Array = []

func _init() -> void:
	steps = [
		[8, setup_check],
		[10, start_walk],
		[75, stop_walk_check],
		[77, start_jump],
		[80, release_jump],
		[215, check_jump],
		[220, weapon_test],
		[225, sit_start],
		[262, sit_check_stand],
		[269, stand_check],
		[272, roof_enter],
		[292, roof_check_hidden],
		[295, roof_exit],
		[318, roof_check_shown],
		[321, keypad_test],
		[324, finish],
	]

var _dbg_frames := [74, 180, 215]
func _process(_delta: float) -> bool:
	_frame += 1
	if player and _frame in _dbg_frames:
		print("DBG f=%d pos=%s vel=%s onfloor=%s" % [_frame, str(player.global_position), str(player.velocity), player.is_on_floor()])
	if _step == 0:
		print("== test_player: تحميل Main.tscn ==")
		var ps: PackedScene = load("res://scenes/main/Main.tscn")
		if ps == null:
			print("FAIL: لا يمكن تحميل Main.tscn")
			quit(1); return true
		main = ps.instantiate()
		root.add_child(main)
		player = main.get_node("Player")
		gs = root.get_node("GameState")
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
	check(player != null, "اللاعب موجود")
	check(player.config != null, "إعدادات الشخصية محمّلة (%s)" % player.config.display_name)
	check(player.rig != null and player.rig.anim_player != null, "الشخصية والأنيميشن محمّلة")
	if player.rig and player.rig.anim_player:
		var n: int = player.rig.anim_player.get_animation_list().size()
		check(n >= 60, "عدد الأنيميشن (%d)" % n)
	check(player.camera_rig != null, "الكاميرا موجودة")
	check(player.detector != null, "كاشف التفاعل موجود")
	check(player.rig.skeleton != null, "الهيكل العظمي موجود")
	if player.rig.skeleton:
		check(player.rig.skeleton.find_bone(player.config.hand_bone) >= 0, "عظمة اليد للسلاح (%s)" % player.config.hand_bone)
	print("-- الحركة --")

func start_walk() -> void:
	start_pos = player.global_position
	Input.action_press("move_forward")

func stop_walk_check() -> void:
	Input.action_release("move_forward")
	var d := player.global_position.distance_to(start_pos)
	check(d > 0.9, "المشي للأمام (%.2f م)" % d)

func start_jump() -> void:
	jump_y0 = player.global_position.y
	Input.action_press("jump")

func release_jump() -> void:
	Input.action_release("jump")

func check_jump() -> void:
	check(player.is_on_floor() or absf(player.global_position.y - jump_y0) < 0.4, "اللاعب يعود لمستوى الأرض (Δy=%.2f)" % absf(player.global_position.y - jump_y0))
	check(player.global_position.y > 1.0 and player.global_position.y < 15.0, "الارتفاع معقول بعد القفز (%.2f)" % player.global_position.y)
	check(player.is_on_floor() or player.velocity.y <= 0.2, "القفز يعود للهبوط (y=%.2f)" % player.global_position.y)
	var clip: String = player.rig.current_clip()
	check(clip.begins_with("Jump") or clip in [player.config.anim_idle, player.config.anim_walk], "أنيميشن القفز/الهبوط (%s)" % clip)

func weapon_test() -> void:
	print("-- السلاح --")
	player.set_weapon(true)
	check(player.weapon_equipped and player.rig.is_weapon_visible(), "إظهار السلاح")
	check(player.rig.has_state("carry_idle"), "أنيميشن حمل السلاح متاح")
	check(player.rig.has_state("aim"), "أنيميشن التصويب متاح")
	player.set_weapon(false)
	check(not player.rig.is_weapon_visible(), "إخفاء السلاح")

func sit_start() -> void:
	print("-- الجلوس --")
	var seat := main.get_node_or_null("World/PlayerHouse/House/SeatMarker")
	check(seat != null, "علامة الجلوس موجودة")
	if seat:
		player.sit_at(seat, seat.rotation.y)
		check(player.is_seated(), "الوضع: جلوس")

func sit_check_stand() -> void:
	var clip: String = player.rig.current_clip()
	check(clip in [player.config.anim_sit_down, player.config.anim_sit_idle], "أنيميشن الجلوس (%s)" % clip)
	Input.action_press("move_forward")

func stand_check() -> void:
	Input.action_release("move_forward")
	check(not player.is_seated(), "الوقوف عند الحركة")
	print("-- السقف --")

func roof_enter() -> void:
	var house := main.get_node("World/PlayerHouse/House")
	player.global_position = house.global_position + Vector3(0, 1.2, 0)

func roof_check_hidden() -> void:
	var roof := main.get_node("World/PlayerHouse/House/Roof")
	check(roof != null and not roof.visible, "السقف يُخفى عند الدخول")

func roof_exit() -> void:
	player.global_position = Vector3(555, 8, 845)

func roof_check_shown() -> void:
	var roof := main.get_node("World/PlayerHouse/House/Roof")
	check(roof.visible, "السقف يظهر عند الخروج")

func keypad_test() -> void:
	print("-- البوابة --")
	check(str(gs.gate_code).length() == 5, "رمز البوابة 5 أرقام (%s)" % gs.gate_code)
	check(gs.try_gate_code(gs.gate_code), "الرمز الصحيح يُقبل")
	check(not gs.try_gate_code("99999") or gs.gate_code == "99999", "الرمز الخاطئ يُرفض")
	var hs := main.get_node("HouseSystem")
	hs._on_code_entered(gs.gate_code)
	check(gs.gate_open, "البوابة تُفتح بالرمز الصحيح")

func finish() -> void:
	print("")
	if fails == 0:
		print("== test_player: كل الفحوصات نجحت ✓ ==")
	else:
		print("== test_player: %d فشلت ✗ ==" % fails)
	quit(0)
