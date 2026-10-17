class_name GasStationSystem
extends Node3D
## تفاعلات تعبئة الوقود عند مضخات محطات الوقود الثلاث

const REFUEL_PRICE := 2.0

var vehicle_manager: VehicleManager

func setup(world: Node3D, vm: VehicleManager) -> void:
	vehicle_manager = vm
	var stations := world.get_node_or_null("GasStations")
	if stations == null:
		push_error("GasStationSystem: لا توجد GasStations")
		return
	for station in stations.get_children():
		for child in station.get_children():
			if child.name.begins_with("FuelPump"):
				_add_pump_interactable(child)

func _add_pump_interactable(pump: Node3D) -> void:
	var area := Interactable.new()
	area.name = "RefuelInteractable"
	area.prompt = "تعبئة الوقود (%.0f للوحدة)" % REFUEL_PRICE
	area.collision_layer = 16
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.8
	cs.shape = sphere
	cs.position = Vector3(0, 1.2, 0)
	area.add_child(cs)
	pump.add_child(area)
	area.interacted.connect(_on_refuel.bind(area))

func _on_refuel(_player: Node, area: Interactable) -> void:
	var v := vehicle_manager.nearest_vehicle(area.global_position, 18.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if v == null:
		if hud and hud.has_method("show_message"):
			hud.show_message("لا توجد مركبة قريبة")
		return
	var missing: float = v.fuel_max - v.fuel
	if missing <= 0.5:
		if hud and hud.has_method("show_message"):
			hud.show_message("الخزان ممتلئ")
		return
	var cost := missing * REFUEL_PRICE
	get_node("/root/GameState").spend_money(cost)
	v.refuel_full()
	_play_sound(area)
	if hud and hud.has_method("show_message"):
		hud.show_message("تم التعبئة: %.0f وحدة — التكلفة %.0f" % [missing, cost])

func _play_sound(parent: Node3D) -> void:
	var p := AudioStreamPlayer3D.new()
	var s: AudioStreamWAV = load("res://assets/audio/refuel.wav")
	if s:
		p.stream = s
		p.global_position = parent.global_position
		get_tree().current_scene.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
