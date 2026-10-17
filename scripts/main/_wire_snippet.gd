func _wire_network(player: Node) -> void:
	## ربط الشبكة: المدير + الواجهة (استضافة/انضمام/طلبات القروض)
	var net := $NetworkManager
	if net == null:
		return
	net.setup(player)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if hud.has_method("set_network_status"):
		hud.set_network_status("غير متصل")
	if hud.btn_network:
		hud.btn_network.pressed.connect(hud._toggle_net_panel)
	if hud.net_host_btn:
		hud.net_host_btn.pressed.connect(func():
			var nm: String = hud.net_name_edit.text.strip_edges()
			if nm != "":
				net.player_name = nm
			if net.host_game():
				hud.set_network_status("建篥 يستضيف — أخبر صديقك بالانضمام")
				hud.show_message("建篥! أخبر صديقك بالانضمام")
			else:
				hud.set_network_status("تعذّرت الاستضافة"))
	if hud.net_join_btn:
		hud.net_join_btn.pressed.connect(func():
			var nm: String = hud.net_name_edit.text.strip_edges()
			if nm != "":
				net.player_name = nm
			var ip: String = hud.net_ip_edit.text.strip_edges()
			if net.join_game(ip):
				hud.set_network_status("جارٍ الاتصال بـ " + ip)
				hud.show_message("جارٍ الانضمام...")
			else:
				hud.set_network_status("تعذّر الاتصال"))
	if hud.net_leave_btn:
		hud.net_leave_btn.pressed.connect(func():
			net.leave_game()
			hud.set_network_status("غير متصل")
			hud.show_message("تم قطع الاتصال"))
	net.net_message.connect(func(t):
		if hud.has_method("show_message"):
			hud.show_message(t, 3.0))
	net.friend_payment.connect(func(amount, i_am_payer):
		if i_am_payer:
			hud.show_message("💸 دفعت %d لصديقك" % int(amount), 3.5)
		else:
			hud.show_message("💰 استلمت %d من صديقك" % int(amount), 3.5))
	net.loan_request_received.connect(func(from_name, amount):
		hud.show_loan_prompt(from_name, amount,
			func(): net.respond_to_loan(true),
			func(): net.respond_to_loan(false)))
	net.loan_response_received.connect(func(ok, amount):
		hud.show_message("القرض %s (%d)" % ["مقبول" if ok else "مرفوض", int(amount)], 3.0))
	net.connected_to_game.connect(func(): hud.set_network_status("متصل — " + net.player_name))
	net.disconnected_from_game.connect(func(): hud.set_network_status("غير متصل"))

