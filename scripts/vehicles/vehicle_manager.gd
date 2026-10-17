class_name VehicleManager
extends Node3D
## ينشئ المركبات القابلة للقيادة في مواضع المواقف بالخريطة

const CAR_SCENE := "res://scenes/vehicles/Car.tscn"
const TRUCK_SCENE := "res://scenes/vehicles/Truck.tscn"

var vehicles: Array = []

func _ready() -> void:
	add_to_group("vehicle_manager")

func setup(world: Node3D) -> void:
	var terrain := world.get_node_or_null("Terrain3D")
	_spawn(world, "PlayerHouse/Car", CAR_SCENE, terrain)
	_spawn(world, "PlayerHouse/Truck", TRUCK_SCENE, terrain)

func _spawn(world: Node3D, placeholder_path: String, scene_path: String, terrain: Node) -> void:
	var ph := world.get_node_or_null(placeholder_path)
	var pos := Vector3.ZERO
	var yaw := 0.0
	if ph:
		pos = ph.global_position
		yaw = ph.global_rotation.y
		ph.get_parent().remove_child(ph)
		ph.queue_free()
	var ps: PackedScene = load(scene_path)
	if ps == null:
		push_error("VehicleManager: مشهد مفقود " + scene_path)
		return
	var v: Vehicle = ps.instantiate()
	add_child(v)
	if terrain and terrain.has_method("get_data"):
		var y: float = terrain.get_data().get_height(pos)
		if y > -100.0:
			pos.y = y + 0.9
	v.global_position = pos
	v.rotation.y = yaw
	vehicles.append(v)

func get_vehicles() -> Array:
	return vehicles

func nearest_vehicle(to: Vector3, max_dist := 25.0) -> Vehicle:
	var best: Vehicle = null
	var best_d := max_dist
	for v in vehicles:
		var d: float = v.global_position.distance_to(to)
		if d < best_d:
			best_d = d
			best = v
	return best
