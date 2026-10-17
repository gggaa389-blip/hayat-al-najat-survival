class_name CharacterRig
extends Node3D
## يبني الشخصية برمجياً من GLB ويرتبط بالهيكل والأنيميشن

var config: CharacterConfig
var model: Node3D = null
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var hand_slot: Node3D = null
var weapon_item: Node3D = null
var _weapon_visible := false
var _state := ""
var _clip_map := {}

func build(cfg: CharacterConfig) -> void:
	config = cfg
	var scene: PackedScene = load(cfg.model_path)
	if scene == null:
		push_error("CharacterRig: تعذر تحميل " + cfg.model_path)
		return
	model = scene.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * cfg.scale
	skeleton = _find_skeleton(model)
	anim_player = _find_anim_player(model)
	if skeleton:
		var att := BoneAttachment3D.new()
		att.bone_name = cfg.hand_bone
		skeleton.add_child(att)
		hand_slot = Node3D.new()
		hand_slot.name = "HandSlot"
		att.add_child(hand_slot)
	if anim_player:
		for a in anim_player.get_animation_list():
			_clip_map[String(a).to_lower()] = a
	_play("idle")

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

func _resolve(anim_name: String) -> String:
	if anim_player.has_animation(anim_name):
		return anim_name
	var k := anim_name.to_lower()
	if _clip_map.has(k):
		return _clip_map[k]
	for key in _clip_map:
		if String(key).begins_with(k):
			return _clip_map[key]
	return ""

func _play(anim_name: String, custom_blend := -1.0) -> void:
	if anim_player == null:
		return
	var clip := _resolve(anim_name)
	if clip == "":
		return
	var blend := custom_blend if custom_blend >= 0.0 else config.blend_time
	anim_player.play(clip, blend)
	_state = anim_name

func play_state(state: String) -> void:
	match state:
		"idle": _play(config.anim_idle)
		"walk": _play(config.anim_walk)
		"run": _play(config.anim_run)
		"jump_start": _play(config.anim_jump_start)
		"jump_loop": _play(config.anim_jump_loop)
		"jump_land": _play(config.anim_jump_land)
		"sit_down": _play(config.anim_sit_down)
		"sit_idle": _play(config.anim_sit_idle)
		"sit_up": _play(config.anim_sit_up)
		"sleep_down": _play(config.anim_sleep_down)
		"sleep_idle": _play(config.anim_sleep_idle)
		"sleep_up": _play(config.anim_sleep_up)
		"carry_idle": _play(config.anim_carry_idle)
		"carry_walk": _play(config.anim_carry_walk)
		"carry_run": _play(config.anim_carry_run)
		"aim": _play(config.anim_aim)
		"shoot": _play(config.anim_shoot, 0.05)
		"reload": _play(config.anim_reload)
		"interact": _play(config.anim_interact, 0.1)
		"pickup": _play(config.anim_pickup, 0.1)
		"wave": _play(config.anim_wave)
		"hurt": _play(config.anim_hurt, 0.05)
		"death": _play(config.anim_death, 0.05)
		_: _play(state)

func current_clip() -> String:
	if anim_player and anim_player.current_animation != "":
		return anim_player.current_animation
	return ""

func has_state(state: String) -> bool:
	match state:
		"idle": return _resolve(config.anim_idle) != ""
		"walk": return _resolve(config.anim_walk) != ""
		"run": return _resolve(config.anim_run) != ""
		"sit_idle": return _resolve(config.anim_sit_idle) != ""
		"sleep_idle": return _resolve(config.anim_sleep_idle) != ""
		"aim": return _resolve(config.anim_aim) != ""
	return true

func attach_to_hand(item: Node3D) -> void:
	if hand_slot:
		hand_slot.add_child(item)
		item.position = Vector3.ZERO

func show_weapon() -> void:
	if weapon_item == null and hand_slot:
		weapon_item = _build_default_weapon()
		if weapon_item:
			hand_slot.add_child(weapon_item)
	if weapon_item:
		weapon_item.visible = true
	_weapon_visible = true

func hide_weapon() -> void:
	if weapon_item:
		weapon_item.visible = false
	_weapon_visible = false

func is_weapon_visible() -> bool:
	return _weapon_visible

## بندقية مبنية برمجياً (بلا نموذج CC0 للبندقية في الحزم)
func _build_default_weapon() -> Node3D:
	var w := Node3D.new()
	w.name = "Shotgun"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.26, 0.12)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.16, 0.18)
	metal.metallic = 0.85
	var stock := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.055, 0.11, 0.42)
	stock.mesh = bm
	stock.material_override = wood
	stock.position = Vector3(0, 0, 0.12)
	w.add_child(stock)
	for i in 2:
		var barrel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.022
		cm.bottom_radius = 0.022
		cm.height = 0.62
		barrel.mesh = cm
		barrel.material_override = metal
		barrel.rotation = Vector3(PI / 2, 0, 0)
		barrel.position = Vector3(-0.026 + i * 0.052, 0.045, -0.28)
		w.add_child(barrel)
	return w

func is_playing(state: String) -> bool:
	return _state == state
