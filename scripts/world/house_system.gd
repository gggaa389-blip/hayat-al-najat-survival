class_name HouseSystem
extends Node3D
## أنظمة المنزل: السقف التلقائي، بوابة الرمز، الجلوس، النوم، راتب اليوم

var player: Player
var roof: Node3D
var house_center := Vector3.ZERO
var roof_hidden := false
var keypad_panel: Control

func setup(world: Node3D, p: Player) -> void:
	player = p
	var house := world.get_node_or_null("PlayerHouse/House")
	if house:
		roof = house.get_node_or_null("Roof")
		house_center = house.global_position
		var seat := house.get_node_or_null("SeatMarker")
		if seat:
			_add_seat_interactable(seat, "الجلوس على الكرسي", "sit")
		var seat2 := house.get_node_or_null("SeatMarker2")
		if seat2:
			_add_seat_interactable(seat2, "الجلوس على الأريكة", "sit")
		var sleep_m := house.get_node_or_null("SleepMarker")
		if sleep_m:
			_add_seat_interactable(sleep_m, "النوم على السرير", "sleep")
	var gate := world.get_node_or_null("PlayerHouse/Gate")
	if gate:
		var kp := gate.get_node_or_null("Keypad")
		if kp:
			_add_gate_interactable(kp)
	# تفاعل الحظيرة: تفريغ حمولة الشاحنة إلى الحظيرة
	var barn := world.get_node_or_null("PlayerHouse/Barn")
	if barn:
		_add_barn_interactable(barn)

func _add_seat_interactable(marker: Node3D, prompt: String, kind: String) -> void:
	var area := Interactable.new()
	area.name = "Interactable_" + kind
	area.prompt = prompt
	area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	cs.shape = sphere
	cs.position = Vector3(0, 1.0, 0)
	area.add_child(cs)
	marker.add_child(area)
	area.interacted.connect(_on_seat.bind(marker, kind))

func _on_seat(player_node: Node, marker: Node3D, kind: String) -> void:
	if kind == "sleep":
		player_node.sleep_on(marker)
	else:
		player_node.sit_down(marker)

func _add_barn_interactable(barn: Node3D) -> void:
	var area := Interactable.new()
	area.name = "BarnInteractable"
	area.prompt = "تفريغ الشاحنة في الحظيرة"
	area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	cs.shape = sphere
	cs.position = Vector3(0, 1.4, 0)
	area.add_child(cs)
	barn.add_child(area)
	area.interacted.connect(_on_barn)

func _on_barn(player_node: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var gs := get_node_or_null("/root/GameState")
	var truck = null
	var vm := get_parent().get_node_or_null("VehicleManager") if get_parent() else null
	if vm and vm.has_method("nearest_vehicle"):
		truck = vm.nearest_vehicle(player_node.global_position, 30.0)
	if truck == null or truck.cargo == null:
		if hud and hud.has_method("show_message"):
			hud.show_message("لا توجد شاحنة قريبة")
		return
	var anim: Array = truck.cargo.unload_all_animals()
	var fish: Array = truck.cargo.unload_all_fish()
	if gs and gs.has_method("barn_store"):
		gs.barn_store(anim)
	# الأسماك تنتقل لمخزون اللاعب إن وسع
	for f in fish:
		if gs and gs.has_method("add_fish"):
			gs.add_fish(String(f.get("type", "fish")), float(f.get("price", 20.0)))
	if hud and hud.has_method("show_message"):
		hud.show_message("تم التفريغ: %d حيوان في الحظيرة، %d سمكة" % [anim.size(), fish.size()])

func _add_gate_interactable(kp: Node3D) -> void:
	var area := Interactable.new()
	area.name = "GateInteractable"
	area.prompt = "استخدام لوحة الرمز"
	area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	cs.shape = sphere
	cs.position = Vector3(0, 1.2, 0)
	area.add_child(cs)
	kp.add_child(area)
	area.interacted.connect(_on_keypad)

func _on_keypad(_player_node: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_keypad"):
		hud.show_keypad(_on_code_entered)

func _on_code_entered(code: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var gs := get_node_or_null("/root/GameState")
	var ok := false
	if gs and gs.has_method("try_gate_code"):
		ok = gs.try_gate_code(code)
	if ok:
		if hud and hud.has_method("show_message"):
			hud.show_message("✓ الرمز صحيح — البوابة مفتوحة")
		_open_gate()
	else:
		if hud and hud.has_method("show_message"):
			hud.show_message("✗ رمز خاطئ")

func _open_gate() -> void:
	var gate := get_tree().current_scene.get_node_or_null("World/PlayerHouse/Gate/GatePanel")
	if gate:
		var tw := create_tween()
		tw.tween_property(gate, "rotation:y", gate.rotation.y + PI * 0.5, 1.2)

# ---- السقف (يُخفى تلقائياً داخل المنزل) ----
func _process(_delta: float) -> void:
	if player == null or roof == null:
		return
	var inside: bool = player.global_position.distance_to(house_center) < 16.0
	if inside and not roof_hidden:
		hide_roof()
	elif not inside and roof_hidden and player.mode == Player.Mode.ROAM:
		show_roof()
	# راتب اليوم عند الزيارة
	if inside:
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("register_house_visit"):
			gs.register_house_visit()

func toggle_roof() -> void:
	if roof == null:
		return
	roof_hidden = not roof_hidden
	roof.visible = not roof_hidden

func hide_roof() -> void:
	if roof:
		roof_hidden = true
		roof.visible = false

func show_roof() -> void:
	if roof:
		roof_hidden = false
		roof.visible = true

func is_roof_hidden() -> bool:
	return roof_hidden
