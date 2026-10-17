extends Node
## الحالة العامة: المال، الاحتياجات، المخزون، القروض، الاقتصاد، دورة اليوم

signal money_changed(new_amount: float)
signal needs_changed(food: float, water: float, sleep_level: float)
signal player_died(reason: String)
signal loan_requested(amount: float)
signal loan_approved(amount: float)
signal loan_denied()
signal day_passed(day: int)
signal noise_event(pos: Vector3, radius: float)

var money: float = 1500.0
var day: int = 1
var food: float = 100.0
var water: float = 100.0
var sleep_level: float = 100.0
var health: float = 100.0

# المخزون
var fish_inventory: Array = []
var max_fish: int = 10
var has_fishing_rod := true
var barn_animals: Array = []      # حيوانات مخزنة في الحظيرة
var shells: int = 30              # ذخيرة البندقية

# الصيد بالصنارة
var fishing_active := false
var fishing_timer := 0.0
const FISH_INTERVAL := 60.0       # سمكة كل دقيقة

# أسعار كل نوع حيوان
const ANIMAL_PRICES := {"cow": 400.0, "pig": 320.0, "deer": 280.0, "bunny": 120.0, "chick": 80.0}
const FISH_PRICES := {"fish": 20.0, "big_fish": 35.0}
const FOOD_PRICE := 25.0
const WATER_PRICE := 15.0
const POTION_PRICE := 80.0
const SHELLS_PRICE := 100.0      # 20 طلقة
const DEATH_PENALTY := 1000.0
const HOUSE_DAILY_PAY := 500.0

const FOOD_DRAIN := 0.12
const WATER_DRAIN := 0.16
const SLEEP_DRAIN := 0.08

var _needs_paused := false
var house_visited_since_pay := false

# بوابة المنزل
var gate_code := "12345"
var gate_open := false

# القرض من الصديق (يتطلب موافقته)
var pending_loan_amount: float = 0.0
var loan_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# الصيد يتقدم ويتوقف عند الامتلاء (يعمل دائماً)
	if fishing_active and fish_inventory.size() < max_fish:
		fishing_timer += delta
		if fishing_timer >= FISH_INTERVAL:
			fishing_timer = 0.0
			if randf() < 0.25:
				add_fish("big_fish", FISH_PRICES["big_fish"])
			else:
				add_fish("fish", FISH_PRICES["fish"])
	if _needs_paused:
		return
	food = maxf(0.0, food - FOOD_DRAIN * delta)
	water = maxf(0.0, water - WATER_DRAIN * delta)
	sleep_level = maxf(0.0, sleep_level - SLEEP_DRAIN * delta)
	needs_changed.emit(food, water, sleep_level)
	if food <= 0.0:
		die("الجوع")
	elif water <= 0.0:
		die("العطش")

func add_money(v: float) -> void:
	money += v
	money_changed.emit(money)

func spend_money(v: float) -> bool:
	money -= v
	money_changed.emit(money)
	return true

func set_needs_paused(p: bool) -> void:
	_needs_paused = p

func eat(v: float) -> void:
	food = minf(100.0, food + v)
	needs_changed.emit(food, water, sleep_level)

func drink(v: float) -> void:
	water = minf(100.0, water + v)
	needs_changed.emit(food, water, sleep_level)

func sleep(v: float) -> void:
	sleep_level = minf(100.0, sleep_level + v)
	needs_changed.emit(food, water, sleep_level)

func damage(v: float) -> void:
	health -= v
	if health <= 0.0:
		die("الجرح")

func die(reason: String) -> void:
	spend_money(DEATH_PENALTY)
	food = 60.0
	water = 60.0
	sleep_level = 60.0
	health = 100.0
	player_died.emit(reason)

func can_afford(v: float) -> bool:
	return money >= v

func try_gate_code(code: String) -> bool:
	if code == gate_code:
		gate_open = true
		return true
	return false

# ---- المتاجر ----
func buy_food() -> bool:
	if not can_afford(FOOD_PRICE):
		return false
	spend_money(FOOD_PRICE)
	eat(35.0)
	return true

func buy_water() -> bool:
	if not can_afford(WATER_PRICE):
		return false
	spend_money(WATER_PRICE)
	drink(40.0)
	return true

func buy_sleep_potion() -> bool:
	if not can_afford(POTION_PRICE):
		return false
	spend_money(POTION_PRICE)
	sleep(70.0)
	return true

func buy_shells() -> bool:
	if not can_afford(SHELLS_PRICE):
		return false
	spend_money(SHELLS_PRICE)
	shells += 20
	return true

func spend_shell() -> bool:
	if shells <= 0:
		return false
	shells -= 1
	return true

# ---- الصيد ----
func add_fish(kind := "fish", price := 20.0) -> bool:
	if fish_inventory.size() >= max_fish:
		return false
	fish_inventory.append({"type": kind, "price": price})
	return true

func sell_all_fish() -> float:
	var total := 0.0
	for f in fish_inventory:
		total += float(f.get("price", 20.0))
	fish_inventory.clear()
	add_money(total)
	return total

func start_fishing() -> void:
	fishing_active = true
	fishing_timer = 0.0

func stop_fishing() -> void:
	fishing_active = false

# ---- الحيوانات ----
func sell_animals(items: Array) -> float:
	var total := 0.0
	for a in items:
		var t := String(a.get("type", ""))
		total += float(ANIMAL_PRICES.get(t, 50.0))
	add_money(total)
	return total

func barn_store(items: Array) -> void:
	for a in items:
		barn_animals.append(a)

func barn_take_all() -> Array:
	var out := barn_animals.duplicate()
	barn_animals.clear()
	return out

# ---- القرض من الصديق (يستلزم موافقة الصديق) ----
func request_loan(amount: float) -> void:
	pending_loan_amount = amount
	loan_requested.emit(amount)

func friend_approves_loan() -> void:
	if pending_loan_amount > 0.0:
		add_money(pending_loan_amount)
		loan_active = true
		var amt := pending_loan_amount
		pending_loan_amount = 0.0
		loan_approved.emit(amt)

func friend_denies_loan() -> void:
	pending_loan_amount = 0.0
	loan_denied.emit()

func repay_loan(amount: float) -> void:
	spend_money(amount)
	loan_active = false

func emit_noise(pos: Vector3, radius: float) -> void:
	noise_event.emit(pos, radius)

# ---- دورة اليوم ----
func register_house_visit() -> void:
	house_visited_since_pay = true

func on_new_day() -> void:
	if house_visited_since_pay:
		add_money(HOUSE_DAILY_PAY)
	else:
		spend_money(HOUSE_DAILY_PAY)
	house_visited_since_pay = false
	day += 1
	day_passed.emit(day)
