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

