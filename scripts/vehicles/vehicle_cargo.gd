class_name VehicleCargo
extends RefCounted
## حمولة الشاحنة: حيوانات (حد أقصى 5) وأسماك (حد أقصى 10) — سعة صارمة

var animals: Array = []
var fish: Array = []
var animal_capacity := 5
var fish_capacity := 10

func load_animal(item: Dictionary) -> bool:
	if animals.size() >= animal_capacity:
		return false
	animals.append(item)
	return true

func load_fish(item: Dictionary) -> bool:
	if fish.size() >= fish_capacity:
		return false
	fish.append(item)
	return true

func unload_animal() -> Dictionary:
	if animals.is_empty():
		return {}
	return animals.pop_back()

func unload_fish() -> Dictionary:
	if fish.is_empty():
		return {}
	return fish.pop_back()

func unload_all_animals() -> Array:
	var out := animals.duplicate()
	animals.clear()
	return out

func unload_all_fish() -> Array:
	var out := fish.duplicate()
	fish.clear()
	return out

func transfer_to(other: VehicleCargo) -> int:
	if other == null:
		return 0
	var moved := 0
	while not animals.is_empty() and other.load_animal(animals[-1]):
		animals.pop_back()
		moved += 1
	while not fish.is_empty() and other.load_fish(fish[-1]):
		fish.pop_back()
		moved += 1
	return moved

func animal_count() -> int:
	return animals.size()

func fish_count() -> int:
	return fish.size()

func is_full_animals() -> bool:
	return animals.size() >= animal_capacity

func is_full_fish() -> bool:
	return fish.size() >= fish_capacity

func clear_all() -> void:
	animals.clear()
	fish.clear()
