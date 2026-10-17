extends SceneTree

const VehicleScript := preload("res://scripts/vehicles/vehicle.gd")
## يبني مشاهد المركبات Car.tscn و Truck.tscn
## godot --headless --path . --script tools/build_vehicles.gd

func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute("res://scenes/vehicles")

	# ---------------- السيارة (sedan)
	var car = VehicleScript.new()
	car.name = "Car"
	car.vehicle_name = "السيارة"
	car.visual_path = "res://assets/models/vehicles/sedan.glb"
	car.visual_scale = 1.4
	car.mass = 1200.0
	car.body_size = Vector3(2.1, 1.5, 3.7)
	car.body_offset = Vector3(0, 0.85, 0)
	car.engine_power = 2300.0
	car.brake_power = 40.0
	car.max_steer = 0.42
	car.wheel_radius = 0.42
	var car_wheels: Array[Vector3] = [
		Vector3(-0.78, 0.42, -1.15), Vector3(0.78, 0.42, -1.15),
		Vector3(-0.78, 0.42, 1.15), Vector3(0.78, 0.42, 1.15),
	]
	car.wheel_positions = car_wheels
	var car_front: Array[int] = [0, 1]
	car.front_wheel_indices = car_front
	car.fuel_max = 100.0
	car.fuel = 100.0
	car.fuel_consumption = 1.1
	car.seat_offset = Vector3(0.5, 0.95, -0.2)
	car.camera_length = 5.4
	car.has_cargo = false
	var ps := PackedScene.new()
	var err := ps.pack(car)
	if err == OK:
		err = ResourceSaver.save(ps, "res://scenes/vehicles/Car.tscn")
	print("Car.tscn err=", err)
	car.free()

	# ---------------- الشاحنة الكبيرة (delivery box truck)
	var truck = VehicleScript.new()
	truck.name = "Truck"
	truck.vehicle_name = "الشاحنة"
	truck.visual_path = "res://assets/models/vehicles/delivery.glb"
	truck.visual_scale = 1.45
	truck.mass = 3400.0
	truck.body_size = Vector3(2.25, 2.3, 4.8)
	truck.body_offset = Vector3(0, 1.25, 0)
	truck.engine_power = 11500.0
	truck.brake_power = 55.0
	truck.max_steer = 0.36
	truck.wheel_radius = 0.52
	var truck_wheels: Array[Vector3] = [
		Vector3(-0.85, 0.52, -1.75), Vector3(0.85, 0.52, -1.75),
		Vector3(-0.85, 0.52, 1.55), Vector3(0.85, 0.52, 1.55),
	]
	truck.wheel_positions = truck_wheels
	var truck_front: Array[int] = [0, 1]
	truck.front_wheel_indices = truck_front
	truck.fuel_max = 160.0
	truck.fuel = 160.0
	truck.fuel_consumption = 1.9
	truck.seat_offset = Vector3(0.62, 1.75, -1.5)
	truck.camera_length = 7.2
	truck.has_cargo = true
	truck.cargo_animal_capacity = 5
	truck.cargo_fish_capacity = 10
	var ps2 := PackedScene.new()
	err = ps2.pack(truck)
	if err == OK:
		err = ResourceSaver.save(ps2, "res://scenes/vehicles/Truck.tscn")
	print("Truck.tscn err=", err)
	truck.free()

	print("== build_vehicles: اكتمل ==")
	quit(0)
	return true
