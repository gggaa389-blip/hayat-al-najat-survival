class_name InteractionDetector
extends Node3D
## يكتشف أقرب Interactable في المدى ويعيد رسالته للواجهة

@export var detect_radius := 3.5
var current: Interactable = null
var player: Node = null

func _process(_delta: float) -> void:
	if player == null:
		return
	var best: Interactable = null
	var best_d := detect_radius
	for area in get_tree().get_nodes_in_group("interactables"):
		if not (area is Interactable) or not area.enabled:
			continue
		var d: float = area.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = area
	current = best
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_interact_prompt"):
		hud.set_interact_prompt(current.get_prompt() if current else "")

func try_interact() -> bool:
	if current:
		current.try_interact(player)
		return true
	return false
