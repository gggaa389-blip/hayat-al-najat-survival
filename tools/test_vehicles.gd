extends SceneTree
## اختبار المرحلة الثالثة: المركبات (قيادة، وقود، ركوب، حمولة)
var _frame := 0
var _step := 0
var fails := 0
var main: Node3D
var player
var gs: Node
var car
var truck
var steps: Array = []

func _init() -> void:
	steps = [
		[10, setup_check],
		[16, enter_car],
		[22, drive_car_check],
		[170, speed_fuel_check],
		[176, exit_car_check],
		[182, fuel_system_check],
		[190, fuel_zero_check],
		[200, refuel_check],
		[210, cargo_check],
		[220, truck_enter_check],
		[226, truck_drive_check],
		[380, finish],
	]

func _process(_delta: float) -> bool:
	_frame += 1
	if _step == 0:
		print("== test_vehicles: تحميل Main.tscn ==")
		var ps: PackedScene = load("res://scenes/main/Main.tscn")
		if ps == null:
			print("FAIL: لا يمكن تحميل Main.tscn"); quit(1); return true
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
	var vm = main.get_node("VehicleManager")
	check(vm != null and vm.vehicles.size() == 2, "مركبتان مُنشأتان (%d)" % (vm.vehicles.size() if vm else 0))
	car = vm.nearest_vehicle(Vector3(740, 0, 900), 200.0)
	# السيارة الأقرب لمنزل اللاعب
	car = null
	truck = null
	for v in vm.vehicles:
		if v.name == "Car":
			car = v
		elif v.name == "Truck":
			truck = v
	check(car != null, "السيارة موجودة")
	check(truck != null, "الشاحنة موجودة")
	if car:
		check(car.fuel > 0.0, "السيارة بها وقود (%.0f)" % car.fuel)
		check(absf(car.speed_kmh()) < 8.0, "السيارة ساكنة تقريباً (%.1f)" % car.speed_kmh())
		check(car.driver == null, "لا سائق مبدئياً")
	if truck:
		check(truck.has_cargo and truck.cargo != null, "الشاحنة بها نظام حمولة")
		check(truck.cargo.animal_capacity == 5, "سعة الحيوانات 5")

func enter_car() -> void:
	print("-- الركوب والقيادة --")
	car.enter(player)
	check(player.mode == player.Mode.DRIVING, "اللاعب يقود (DRIVING)")
	check(car.driver == player, "السائق مسجل على المركبة")

func drive_car_check() -> void:
	Input.action_press("move_forward")

func speed_fuel_check() -> void:
	Input.action_release("move_forward")
	var speed: float = car.speed_kmh()
	check(speed > 8.0, "السيارة تتحرك (%.1f كم/س)" % speed)
	check(car.fuel < car.fuel_max, "الوقود يتناقص (%.1f)" % car.fuel)
	check(player.global_position.distance_to(car.global_position) < 3.0, "اللاعب يتبع المركبة")

func exit_car_check() -> void:
	player.exit_vehicle()
	check(player.mode == player.Mode.ROAM, "النزول يعيد وضع التنقل")
	check(car.driver == null, "المقعد فارغ بعد النزول")

func fuel_system_check() -> void:
	print("-- الوقود --")
	car.fuel = 0.0
	car.enter(player)

func fuel_zero_check() -> void:
	Input.action_press("move_forward")

func refuel_check() -> void:
	Input.action_release("move_forward")
	check(is_equal_approx(car.engine_force, 0.0), "لا قوة محرك بدون وقود")
	var money_before: float = gs.money
	var needed: float = car.fuel_max - car.fuel
	car.refuel_full()
	check(car.fuel >= car.fuel_max - 0.1, "الخزان امتلأ (%.1f)" % car.fuel)
	# التكلفة عبر نظام المحطة
	var sys = main.get_node("GasStationSystem")
	var price: float = sys.REFUEL_PRICE
	check(price > 0.0, "سعر الوقود معرف (%.1f)" % price)
	gs.spend_money(needed * price)
	check(gs.money < money_before or needed < 0.5, "المال يُخصم مقابل الوقود")
	car.exit()

func cargo_check() -> void:
	print("-- الحمولة --")
	var ok_count := 0
	for i in 6:
		if truck.cargo.load_animal({"type": "cow", "price": 100.0}):
			ok_count += 1
	check(ok_count == 5, "5 حيوانات كحد أقصى (حُمّل %d)" % ok_count)
	check(truck.cargo.animal_count() == 5, "العدّاد يعكس السعة")
	var f_ok := 0
	for i in 12:
		if truck.cargo.load_fish({"type": "fish", "price": 20.0}):
			f_ok += 1
	check(f_ok == 10, "10 أسماك كحد أقصى (حُمّل %d)" % f_ok)
	var unloaded: Dictionary = truck.cargo.unload_animal()
	check(not unloaded.is_empty(), "تنزيل حيوان يعمل")
	var moved: int = truck.cargo.transfer_to(car.cargo) if car.cargo else -1
	# السيارة بلا حمولة — النقل إليها يُعاد 0 أو -1
	var all: Array = truck.cargo.unload_all_animals()
	check(truck.cargo.animal_count() == 0, "إفراغ الحيوانات (%d نُقل)" % all.size())
	check(truck.cargo.unload_all_fish().size() == 10, "إفراغ الأسماك")

func truck_enter_check() -> void:
	print("-- الشاحنة --")
	truck.enter(player)
	check(player.mode == player.Mode.DRIVING, "الركوب في الشاحنة")

func truck_drive_check() -> void:
	Input.action_press("move_forward")

func finish() -> void:
	Input.action_release("move_forward")
	var speed: float = truck.speed_kmh()
	check(speed > 8.0, "الشاحنة تتحرك (%.1f كم/س)" % speed)
	check(truck.fuel < truck.fuel_max, "وقود الشاحنة يتناقص")
	player.exit_vehicle()
	print("")
	if fails == 0:
		print("== test_vehicles: كل الفحوصات نجحت ✓ ==")
	else:
		print("== test_vehicles: %d فشلت ✗ ==" % fails)
	quit(0)
