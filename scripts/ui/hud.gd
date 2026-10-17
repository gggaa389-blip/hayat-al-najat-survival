class_name HUD
extends CanvasLayer
## واجهة الهاتف (أفقي): عصا يسار، كاميرا بالسحب يمين، أزرار سياقية، مخزون بضغطة مطولة

# ---- حالة اللمس (يقرأها اللاعب/الكاميرا) ----
var move_vector := Vector2.ZERO
var _cam_delta := Vector2.ZERO

# ---- عناصر واجهة ----
var root: Control
var hint_label: Label
var msg_label: Label
var money_label: Label
var needs_label: Label
var reticle: Label
var msg_tween: Tween
var keypad_panel: PanelContainer
var keypad_label: Label
var keypad_code := ""
var keypad_callback: Callable = Callable()

var joy_base: Control
var joy_knob: Control
var _joy_touch_id := -1
var _cam_touch_id := -1
var _joy_radius := 96.0

var btn_fire: Button
var btn_jump: Button
var btn_run: Button
var btn_weapon: Button
var btn_sit: Button
var btn_aim: Button
var btn_interact: Button
var btn_inventory: Button
var inv_panel: PanelContainer
var inv_labels := {}
var fuel_bar: ProgressBar
var fuel_label: Label
var btn_network: Button
var net_panel: PanelContainer
var net_name_edit: LineEdit
var net_ip_edit: LineEdit
var net_status_label: Label
var net_host_btn: Button
var net_join_btn: Button
var net_leave_btn: Button
var loan_panel: PanelContainer
var loan_label: Label

var _run_active := false
var _interact_held := false
var _interact_hold_time := 0.0
var _interact_long_done := false
var _inventory_shown := false
var _inv_held := false
var _ui_click: AudioStreamPlayer

func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_ui_click = AudioStreamPlayer.new()
	var s: AudioStreamWAV = load("res://assets/audio/ui_click.wav")
	if s:
		_ui_click.stream = s
	add_child(_ui_click)
	_build_hud()

func consume_camera_delta() -> Vector2:
	var d := _cam_delta
	_cam_delta = Vector2.ZERO
	return d

func _click() -> void:
	if _ui_click and _ui_click.stream:
		_ui_click.play()

# ============================================================ البناء
func _build_hud() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---------- العصا الافتراضية (يسار أسفل)
	joy_base = Control.new()
	joy_base.name = "Joystick"
	joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy_base.position = Vector2(48, -280)
	joy_base.size = Vector2(240, 240)
	joy_base.draw.connect(_draw_joy)
	root.add_child(joy_base)
	joy_knob = Control.new()
	joy_knob.name = "Knob"
	joy_knob.position = Vector2(72, 72)
	joy_knob.size = Vector2(96, 96)
	joy_knob.draw.connect(_draw_knob)
	joy_base.add_child(joy_knob)

	# ---------- أزرار يمين
	btn_fire = _mk_btn(root, "إطلاق", Vector2(-190, -300), Vector2(130, 130), Color(0.85, 0.2, 0.16, 0.88))
	btn_fire.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_fire.position = Vector2(-190, -300)
	btn_fire.visible = false
	btn_fire.pressed.connect(button_fire)

	btn_jump = _mk_btn(root, "قفز", Vector2(-330, -190), Vector2(104, 104), Color(0.25, 0.45, 0.8, 0.8))
	btn_jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_jump.position = Vector2(-330, -190)
	btn_jump.pressed.connect(button_jump)

	btn_run = _mk_btn(root, "جري", Vector2(-450, -150), Vector2(96, 96), Color(0.3, 0.55, 0.35, 0.8))
	btn_run.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_run.position = Vector2(-450, -150)
	btn_run.toggle_mode = true
	btn_run.toggled.connect(_on_run_toggled)

	btn_sit = _mk_btn(root, "جلوس", Vector2(-450, -270), Vector2(96, 96), Color(0.55, 0.45, 0.3, 0.8))
	btn_sit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_sit.position = Vector2(-450, -270)
	btn_sit.pressed.connect(button_sit)

	btn_weapon = _mk_btn(root, "سلاح", Vector2(-190, -440), Vector2(96, 96), Color(0.4, 0.4, 0.5, 0.85))
	btn_weapon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_weapon.position = Vector2(-190, -440)
	btn_weapon.pressed.connect(button_weapon)

	btn_aim = _mk_btn(root, "تصويب", Vector2(-310, -420), Vector2(88, 88), Color(0.35, 0.4, 0.55, 0.8))
	btn_aim.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_aim.position = Vector2(-310, -420)
	btn_aim.toggle_mode = true
	btn_aim.toggled.connect(_on_aim_toggled)

	# زر التفاعل السياقي (يعرض رسالته)
	btn_interact = _mk_btn(root, "تفاعل", Vector2(-330, -320), Vector2(120, 88), Color(0.2, 0.7, 0.5, 0.88))
	btn_interact.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_interact.position = Vector2(-330, -320)
	btn_interact.visible = false
	btn_interact.button_down.connect(_on_interact_down)
	btn_interact.button_up.connect(_on_interact_up)

	# زر المخزون (ضغط مطويل يعرض المؤشرات)
	btn_inventory = _mk_btn(root, "حقيبة", Vector2(-140, 12), Vector2(110, 56), Color(0.28, 0.3, 0.38, 0.85))
	btn_inventory.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_inventory.position = Vector2(-140, 12)
	btn_inventory.button_down.connect(_on_inventory_down)
	btn_inventory.button_up.connect(_on_inventory_up)

	# ---------- مؤشرات
	_build_indicators()
	_build_keypad(root)
	_build_network_ui(root)

	# ربط GameState
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.money_changed.connect(_on_money)
		gs.needs_changed.connect(_on_needs)
		_on_money(gs.money)
		_on_needs(gs.food, gs.water, gs.sleep_level)

func _mk_btn(parent: Control, text: String, _pos: Vector2, size: Vector2, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size.x * 0.32))
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = Color(color.r * 1.25, color.g * 1.25, color.b * 1.25, color.a)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb)
	parent.add_child(b)
	return b

func _draw_joy() -> void:
	joy_base.draw_circle(Vector2(120, 120), _joy_radius, Color(1, 1, 1, 0.12))
	joy_base.draw_arc(Vector2(120, 120), _joy_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)

func _draw_knob() -> void:
	joy_knob.draw_circle(Vector2(48, 48), 42, Color(1, 1, 1, 0.38))

func _build_indicators() -> void:
	# مال + احتياجات
	money_label = Label.new()
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.position = Vector2(-270, 16)
	money_label.size = Vector2(120, 34)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	money_label.add_theme_constant_override("outline_size", 5)
	root.add_child(money_label)

	needs_label = Label.new()
	needs_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	needs_label.position = Vector2(14, 10)
	needs_label.size = Vector2(220, 60)
	needs_label.add_theme_font_size_override("font_size", 15)
	needs_label.add_theme_color_override("font_outline_color", Color.BLACK)
	needs_label.add_theme_constant_override("outline_size", 4)
	root.add_child(needs_label)

	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-300, 24)
	msg_label.size = Vector2(600, 42)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 19)
	msg_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 6)
	msg_label.text = ""
	root.add_child(msg_label)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-220, -70)
	hint_label.size = Vector2(440, 36)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 5)
	root.add_child(hint_label)

	reticle = Label.new()
	reticle.text = "+"
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-12, -22)
	reticle.size = Vector2(24, 44)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 34)
	reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	root.add_child(reticle)

	# مقياس الوقود (يظهر أثناء القيادة)
	fuel_bar = ProgressBar.new()
	fuel_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fuel_bar.position = Vector2(-110, 80)
	fuel_bar.size = Vector2(220, 22)
	fuel_bar.max_value = 100.0
	fuel_bar.value = 100.0
	fuel_bar.visible = false
	root.add_child(fuel_bar)
	fuel_label = Label.new()
	fuel_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fuel_label.position = Vector2(-110, 104)
	fuel_label.size = Vector2(220, 24)
	fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fuel_label.add_theme_font_size_override("font_size", 15)
	fuel_label.text = ""
	root.add_child(fuel_label)

	# لوحة المخزون (تظهر بالضغط المطويل)
	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv_panel.position = Vector2(-330, 80)
	inv_panel.size = Vector2(310, 210)
	inv_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.82)
	sb.set_corner_radius_all(12)
	inv_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	inv_panel.add_child(vb)
	for key in ["food", "water", "sleep", "fish", "fuel", "shells"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 19)
		vb.add_child(l)
		inv_labels[key] = l
	root.add_child(inv_panel)

func _build_network_ui(parent: Control) -> void:
	# زر الشبكة (أعلى يمين)
	btn_network = _mk_btn(root, "📡 شبكة", Vector2(-220, 16), Vector2(180, 64), Color(0.16, 0.45, 0.75, 0.85))
	btn_network.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_network.position = Vector2(-220, 16)
	btn_network.pressed.connect(_toggle_net_panel)

	# لوحة الشبكة
	net_panel = PanelContainer.new()
	net_panel.name = "NetPanel"
	net_panel.set_anchors_preset(Control.PRESET_CENTER)
	net_panel.custom_minimum_size = Vector2(560, 420)
	net_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	net_panel.add_child(v)
	var title := Label.new()
	title.text = "📡 اللعب مع صديق (شبكة محلية)"
	title.add_theme_font_size_override("font_size", 28)
	v.add_child(title)
	var lbl_name := Label.new()
	lbl_name.text = "اسمك:"
	v.add_child(lbl_name)
	net_name_edit = LineEdit.new()
	net_name_edit.text = "لاعب"
	net_name_edit.custom_minimum_size = Vector2(400, 48)
	v.add_child(net_name_edit)
	var lbl_ip := Label.new()
	lbl_ip.text = "عنوان المضيف (IP):"
	v.add_child(lbl_ip)
	net_ip_edit = LineEdit.new()
	net_ip_edit.text = "192.168.1.2"
	net_ip_edit.custom_minimum_size = Vector2(400, 48)
	v.add_child(net_ip_edit)
	net_status_label = Label.new()
	net_status_label.text = "غير متصل"
	net_status_label.add_theme_font_size_override("font_size", 22)
	v.add_child(net_status_label)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	net_host_btn = _mk_btn(hb, "استضافة", Vector2.ZERO, Vector2(150, 60), Color(0.2, 0.6, 0.3, 0.9))
	net_join_btn = _mk_btn(hb, "انضمام", Vector2.ZERO, Vector2(150, 60), Color(0.25, 0.5, 0.8, 0.9))
	net_leave_btn = _mk_btn(hb, "خروج", Vector2.ZERO, Vector2(150, 60), Color(0.7, 0.3, 0.25, 0.9))
	root.add_child(net_panel)

	# نافذة طلب القرض
	loan_panel = PanelContainer.new()
	loan_panel.name = "LoanPanel"
	loan_panel.set_anchors_preset(Control.PRESET_CENTER)
	loan_panel.custom_minimum_size = Vector2(520, 260)
	loan_panel.visible = false
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 14)
	loan_panel.add_child(lv)
	loan_label = Label.new()
	loan_label.text = ""
	loan_label.add_theme_font_size_override("font_size", 26)
	loan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(loan_label)
	var lh := HBoxContainer.new()
	lh.alignment = BoxContainer.ALIGNMENT_CENTER
	lh.add_theme_constant_override("separation", 16)
	lv.add_child(lh)
	var btn_ok := _mk_btn(lh, "✅ موافقة", Vector2.ZERO, Vector2(180, 64), Color(0.2, 0.62, 0.32, 0.92))
	var btn_no := _mk_btn(lh, "❌ رفض", Vector2.ZERO, Vector2(180, 64), Color(0.72, 0.3, 0.24, 0.92))
	btn_ok.pressed.connect(_on_loan_approve)
	btn_no.pressed.connect(_on_loan_deny)
	root.add_child(loan_panel)

func _toggle_net_panel() -> void:
	if net_panel:
		net_panel.visible = not net_panel.visible

func set_network_status(text: String) -> void:
	if net_status_label:
		net_status_label.text = text

var _loan_approve_cb: Callable
var _loan_deny_cb: Callable

func show_loan_prompt(from_name: String, amount: float, approve_cb: Callable, deny_cb: Callable) -> void:
	_loan_approve_cb = approve_cb
	_loan_deny_cb = deny_cb
	if loan_label:
		loan_label.text = "%s يطلب منك قرضاً بقيمة %d\nهل توافق؟" % [from_name, int(amount)]
	if loan_panel:
		loan_panel.visible = true
	show_message("طلب قرض من " + from_name, 3.0)

func _on_loan_approve() -> void:
	if loan_panel:
		loan_panel.visible = false
	if _loan_approve_cb.is_valid():
		_loan_approve_cb.call()

func _on_loan_deny() -> void:
	if loan_panel:
		loan_panel.visible = false
	if _loan_deny_cb.is_valid():
		_loan_deny_cb.call()


func _build_keypad(parent: Control) -> void:
	keypad_panel = PanelContainer.new()
	keypad_panel.name = "Keypad"
	keypad_panel.visible = false
	keypad_panel.set_anchors_preset(Control.PRESET_CENTER)
	keypad_panel.position = Vector2(-130, -190)
	keypad_panel.size = Vector2(260, 380)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	keypad_panel.add_child(vb)
	keypad_label = Label.new()
	keypad_label.text = "— — — — —"
	keypad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keypad_label.add_theme_font_size_override("font_size", 30)
	vb.add_child(keypad_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for i in 9:
		_add_key(grid, str(i + 1))
	_add_key(grid, "مسح")
	_add_key(grid, "0")
	_add_key(grid, "✓")

func _add_key(grid: GridContainer, label: String) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(66, 52)
	b.pressed.connect(_on_key.bind(label))
	grid.add_child(b)

func _on_key(key: String) -> void:
	_click()
	if key == "مسح":
		keypad_code = ""
	elif key == "✓":
		if keypad_callback.is_valid():
			keypad_callback.call(keypad_code)
		hide_keypad()
		return
	else:
		if keypad_code.length() < 5:
			keypad_code += key
	keypad_label.text = ""
	for i in keypad_code.length():
		keypad_label.text += keypad_code[i] + " "
	for i in 5 - keypad_code.length():
		keypad_label.text += "— "
		if i < 4 - keypad_code.length():
			keypad_label.text += " "

# ============================================================ إدخال اللمس الحقيقي
func _input(event: InputEvent) -> void:
	# لمس/سحب بشاشة اللمس أو الفأرة (لاختبار المكتب)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_down(0, event.position)
		else:
			_touch_up(0)
	elif event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		_touch_move(0, event.relative)

func _touch_down(id: int, pos: Vector2) -> void:
	if pos.x < root.size.x * 0.42 and pos.y > root.size.y * 0.35:
		_joy_touch_id = id
		_update_joy(pos)
	else:
		_cam_touch_id = id

func _touch_up(id: int) -> void:
	if id == _joy_touch_id:
		_joy_touch_id = -1
		move_vector = Vector2.ZERO
		_apply_move_actions(Vector2.ZERO)
		joy_knob.position = Vector2(72, 72)
		joy_base.queue_redraw()
	if id == _cam_touch_id:
		_cam_touch_id = -1

func _touch_move(id: int, rel: Vector2) -> void:
	if id == _joy_touch_id:
		var knob_global: Vector2 = joy_base.position + joy_knob.position + Vector2(48, 48)
		_update_joy(knob_global + rel)
	elif id == _cam_touch_id:
		_cam_delta += rel

## مدخلات العصا (تستدعى من اللمس الحقيقي أو من الاختبارات)
func joystick_touch(pos: Vector2, pressed: bool) -> void:
	if pressed:
		_joy_touch_id = 100
		_update_joy(pos)
	else:
		_joy_touch_id = -1
		move_vector = Vector2.ZERO
		_apply_move_actions(Vector2.ZERO)
		joy_knob.position = Vector2(72, 72)
		joy_base.queue_redraw()

func _update_joy(pos: Vector2) -> void:
	var center: Vector2 = joy_base.position + Vector2(120, 120)
	var v: Vector2 = (pos - center) / _joy_radius
	v = v.limit_length(1.0)
	move_vector = v
	joy_knob.position = Vector2(72, 72) + v * (_joy_radius - 48)
	joy_base.queue_redraw()
	_apply_move_actions(v)

func _apply_move_actions(v: Vector2) -> void:
	_set_action("move_forward", v.y < -0.3)
	_set_action("move_back", v.y > 0.3)
	_set_action("move_left", v.x < -0.3)
	_set_action("move_right", v.x > 0.3)

func _set_action(action: String, on: bool) -> void:
	if on:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	else:
		if Input.is_action_pressed(action):
			Input.action_release(action)

## سحب الكاميرا (لمس حقيقي أو اختبار)
func camera_swipe(delta: Vector2) -> void:
	_cam_delta += delta

# ============================================================ أزرار
func button_fire() -> void:
	_click()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("_fire"):
		player._fire()

func button_jump() -> void:
	_click()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		Input.action_press("jump")
		await get_tree().create_timer(0.08).timeout
		Input.action_release("jump")

func _on_run_toggled(on: bool) -> void:
	_click()
	_run_active = on
	_set_action("run", on)

func _on_aim_toggled(on: bool) -> void:
	_click()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.camera_rig:
		player.camera_rig.set_aim(on)

func button_weapon() -> void:
	_click()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_weapon(not player.weapon_equipped)

func button_sit() -> void:
	_click()
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.is_seated():
		player._stand_up()
	elif int(player.mode) == 0:  # Mode.ROAM
		var marker := Node3D.new()
		var parent: Node = player.get_parent()
		if parent == null:
			parent = get_tree().root
		parent.add_child(marker)
		marker.global_position = player.global_position
		player.sit_at(marker, player.rotation.y)

func button_interact() -> void:
	_click()
	var player := get_tree().get_first_node_in_group("player")
	if player and player.detector:
		player.detector.try_interact()

func _on_interact_down() -> void:
	_interact_held = true
	_interact_hold_time = 0.0
	_interact_long_done = false

func _on_interact_up() -> void:
	if _interact_held and not _interact_long_done:
		button_interact()
	_interact_held = false

func _on_inventory_down() -> void:
	_click()
	_inv_held = true

func _on_inventory_up() -> void:
	_inv_held = false

# ============================================================ التحديث
func _process(delta: float) -> void:
	# ضغطة التفاعل المطولة (2 ثانية) → إرسال الحيوان للشاحنة
	if _interact_held:
		_interact_hold_time += delta
		if _interact_hold_time >= 2.0 and not _interact_long_done:
			_interact_long_done = true
			_send_nearest_to_truck()
	# إظهار المخزون ما دامت الحقيبة مضغوطة
	if _inv_held != _inventory_shown:
		_inventory_shown = _inv_held
		inv_panel.visible = _inv_held
	if _inventory_shown:
		_update_inventory_panel()

func _send_nearest_to_truck() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# أقرب جثة حيوان
	var best: Node = null
	var best_d := 22.0
	for a in get_tree().get_nodes_in_group("animals"):
		if a.state == 2 and a.has_method("send_to_truck"):
			var d: float = a.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = a
	if best:
		if best.send_to_truck(player):
			show_message("أُرسل الحيوان إلى الشاحنة ✓")
		else:
			show_message("الشاحنة بعيدة أو ممتلئة")
	else:
		show_message("لا توجد حيوانات قريبة للإرسال")

func _update_inventory_panel() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	inv_labels["food"].text = "الطعام: %d%%" % int(gs.food)
	inv_labels["water"].text = "الماء: %d%%" % int(gs.water)
	inv_labels["sleep"].text = "النوم: %d%%" % int(gs.sleep_level)
	inv_labels["fish"].text = "الأسماك: %d/%d" % [gs.fish_inventory.size(), gs.max_fish]
	inv_labels["shells"].text = "الذخيرة: %d" % gs.shells
	var fuel_txt := "الوقود: —"
	var player := get_tree().get_first_node_in_group("player")
	if player and player.vehicle:
		fuel_txt = "الوقود: %d/%d" % [int(player.vehicle.fuel), int(player.vehicle.fuel_max)]
	else:
		var vm := get_tree().get_first_node_in_group("vehicle_manager")
		if vm:
			var v = vm.nearest_vehicle(player.global_position if player else Vector3.ZERO, 12.0)
			if v:
				fuel_txt = "الوقود: %d/%d" % [int(v.fuel), int(v.fuel_max)]
	inv_labels["fuel"].text = fuel_txt

# ============================================================ واجهة عامة
func set_weapon_ui(shown: bool) -> void:
	btn_fire.visible = shown

func is_fire_visible() -> bool:
	return btn_fire.visible

func is_inventory_shown() -> bool:
	return _inventory_shown

func set_fuel_gauge(value: float, max_v: float) -> void:
	fuel_bar.visible = true
	fuel_bar.max_value = max_v
	fuel_bar.value = value
	fuel_label.text = "الوقود %d%%" % int(value / maxf(max_v, 1.0) * 100.0)

func hide_fuel_gauge() -> void:
	fuel_bar.visible = false
	fuel_label.text = ""

func set_reticle_red(on: bool) -> void:
	if reticle:
		reticle.add_theme_color_override("font_color", Color(1, 0.25, 0.2, 0.95) if on else Color(1, 1, 1, 0.85))

func show_keypad(cb: Callable) -> void:
	keypad_callback = cb
	keypad_code = ""
	keypad_label.text = "— — — — —"
	keypad_panel.visible = true

func hide_keypad() -> void:
	keypad_panel.visible = false

func set_interact_prompt(text: String) -> void:
	hint_label.text = text
	btn_interact.visible = text != ""
	btn_interact.text = text if text.length() < 18 else "تفاعل"

func show_message(text: String, duration := 2.5) -> void:
	msg_label.text = text
	if msg_tween:
		msg_tween.kill()
	msg_label.modulate.a = 1.0
	msg_tween = create_tween()
	msg_tween.tween_interval(duration)
	msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.5)

func _on_money(v: float) -> void:
	if money_label:
		money_label.text = "المال: %.0f" % v

func _on_needs(food: float, water: float, sleep_level: float) -> void:
	if needs_label:
		needs_label.text = "طعام %d%%  ماء %d%%  نوم %d%%" % [int(food), int(water), int(sleep_level)]
