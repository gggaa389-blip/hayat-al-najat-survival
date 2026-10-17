class_name Interactable
extends Area3D
## عنصر تفاعلي — يوضع فوق الكائن ويُعرف رسالته

signal interacted(player: Node)

@export var prompt := "تفاعل"
@export var action_id := ""
@export var enabled := true

func _init() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false

func _ready() -> void:
	add_to_group("interactables")

func get_prompt() -> String:
	return prompt

func try_interact(player: Node) -> void:
	if enabled:
		interacted.emit(player)
