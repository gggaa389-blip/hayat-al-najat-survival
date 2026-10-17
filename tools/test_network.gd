extends SceneTree
## اختبار المرحلة السادسة: الشبكة (منطق + مكونات) — التكامل الثنائي في net_host/net_join

var _frame := 0
var _step := 0
var fails := 0
var main: Node3D
var player
var gs: Node
var net
var hud
var steps: Array = []

func _init() -> void:
	steps = [
		[10, setup_check],
		[20, host_check],
		[40, remote_player_check],
		[60, loan_logic_check],
		[80, attack_logic_check],
		[100, runover_check],
		[115, hud_network_check],
		[135, finish],
	]

func _process(_delta: float) -> bool:
	_frame += 1
	if _step == 0:
		print("== test_network: تحميل Main.tscn ==")
		var ps: PackedScene = load("res://scenes/main/Main.tscn")
		if ps == null:
			print("FAIL: لا يمكن تحميل Main.tscn"); quit(1); return true
		main = ps.instantiate()
		root.add_child(main)
		player = main.get_node("Player")
		gs = root.get_node("GameState")
		gs.set_needs_paused(true)
		net = main.get_node("NetworkManager")
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
	print("-- الشبكة --")
	check(net != null, "مدير الشبكة موجود")
	check(net.has_method("host_game") and net.has_method("join_game"), "استضافة/انضمام متاحان")
	check(main.get_node_or_null("NetworkManager") != null, "عقدة الشبكة في Main")

func host_check() -> void:
	print("-- الاستضافة (ENet حقيقي) --")
	var ok: bool = net.host_game(47233)
	check(ok, "الاستضافة على منفذ 47233")
	check(net.is_online and net.is_host, "الحالة: مضيف متصل")
	check(net.my_id() == 1, "معرف المضيف 1")
	net.leave_game()
	check(not net.is_online, "القطع يعمل")

func remote_player_check() -> void:
	print("-- اللاعب البعيد --")
	var script = load("res://scripts/network/remote_player.gd")
	check(script != null, "سكربت اللاعب البعيد")
	var rp = script.new()
	root.add_child(rp)
	rp.set_display_name("صديق")
	check(rp.is_remote_player(), "معرّف اللاعب البعيد")
	rp.apply_state(Vector3(5, 0, 7), 1.2, "walk")
	check(rp.global_position.distance_to(Vector3(5, 0, 7)) < 0.01, "تطبيق الحالة (الموضع)")
	check(absf(rp.rotation.y - 1.2) < 0.01, "تطبيق الحالة (الدوران)")
	check(rp.collision_layer == 32, "طبقة الاصطدام 32 (npc)")
	rp.queue_free()

func loan_logic_check() -> void:
	print("-- منطق القرض --")
	var m0: float = gs.money
	var events := []
	net.friend_payment.connect(func(a, payer): events.append([a, payer]))
	gs.request_loan(500.0)
	net.apply_loan_response(true, 500.0)
	check(gs.money == m0 + 500.0, "موافقة القرض تُحوّل المال (+500)")
	gs.request_loan(300.0)
	var m1: float = gs.money
	net.apply_loan_response(false, 300.0)
	check(gs.money == m1, "الرفض لا يُحوّل شيئاً")

func attack_logic_check() -> void:
	print("-- القتال والدفع --")
	var payments := []
	net.friend_payment.connect(func(a, payer): payments.append(payer))
	var deltas := [gs.money]
	gs.money_changed.connect(func(v): deltas.append(v))
	net.apply_attack(1000.0, 0, true)
	check(deltas.size() >= 3 and deltas[1] == deltas[0] + 1000.0, "الضحية تستقبل 1000 أولاً")
	check(deltas[2] == deltas[1] - 1000.0, "القاتل يُخصم منه 1000 (الطرفان في الاستدعاء المباشر)")
	check(payments.size() >= 1 and payments[0] == false, "إشارة الدفع للضحية")
	check(payments.size() >= 2 and payments[1] == true, "إشارة الدفع للقاتل")
	var m1: float = gs.money
	net.apply_friend_killed_payer()
	check(gs.money == m1 - 1000.0, "القاتل يدفع 1000 (استدعاء منفصل)")

func runover_check() -> void:
	print("-- الدهس --")
	var rp = load("res://scripts/network/remote_player.gd").new()
	root.add_child(rp)
	rp.global_position = player.global_position + Vector3(1, 0, 0)
	check(net.has_method("check_run_over"), "فحص الدهس متاح")
	rp.queue_free()

func hud_network_check() -> void:
	print("-- واجهة الشبكة --")
	check(hud.btn_network != null, "زر الشبكة")
	hud._toggle_net_panel()
	check(hud.net_panel.visible, "لوحة الشبكة تظهر")
	check(hud.net_name_edit != null and hud.net_ip_edit != null, "حقلا الاسم والعنوان")
	hud._toggle_net_panel()
	check(not hud.net_panel.visible, "اللوحة تُخفى")
	var got := [false, false]
	hud.show_loan_prompt("صديق", 700.0, func(): got[0] = true, func(): got[1] = true)
	check(hud.loan_panel.visible, "نافذة القرض تظهر")
	check("700" in hud.loan_label.text and "صديق" in hud.loan_label.text, "تفاصيل القرض معروضة")
	hud._on_loan_approve()
	check(got[0] and not hud.loan_panel.visible, "زر الموافقة يعمل ويُغلق")
	hud.show_loan_prompt("صديق", 200.0, func(): got[0] = true, func(): got[1] = true)
	hud._on_loan_deny()
	check(got[1], "زر الرفض يعمل")

func finish() -> void:
	print("")
	if fails == 0:
		print("== test_network: كل الفحوصات نجحت ✓ ==")
	else:
		print("== test_network: %d فشلت ✗ ==" % fails)
	quit(1 if fails > 0 else 0)
