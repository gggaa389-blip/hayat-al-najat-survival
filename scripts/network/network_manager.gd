extends Node
## مدير الشبكة — وضع الأصدقاء عبر ENet (LAN) + مزامنة المركبات

signal connected_to_game
signal disconnected_from_game
signal peer_joined(id: int)
signal peer_left(id: int)
signal loan_request_received(from_name: String, amount: float)
signal loan_response_received(approved: bool, amount: float)
signal friend_payment(amount: float, i_am_payer: bool)
signal net_message(text: String)

const DEFAULT_PORT := 47231
const SYNC_INTERVAL := 0.10
const KILL_PAYMENT := 1000.0

var is_online := false
var is_host := false
var player_name := "لاعب"
var player: Node = null

var _peers: Dictionary = {}
var _remote_players: Dictionary = {}
var _remote_vehicles: Dictionary = {}
var _pending_loan_from := 0
var _pending_loan_amount := 0.0
var _sync_timer := 0.0
var _mp_connected := false

func _ready() -> void:
	add_to_group("network")

func setup(p: Node) -> void:
	player = p

func my_id() -> int:
	if not is_online or multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

func host_game(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		net_message.emit("تعذّرت الاستضافة على المنفذ %d" % port)
		return false
	multiplayer.multiplayer_peer = peer
	_wire_mp()
	is_online = true
	is_host = true
	net_message.emit("تمت الاستضافة — أخبر صديقك بالانضمام عبر الشبكة المحلية")
	return true

func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		net_message.emit("تعذّر الاتصال بـ %s" % ip)
		return false
	multiplayer.multiplayer_peer = peer
	_wire_mp()
	is_online = true
	is_host = false
	net_message.emit("جارٍ الانضمام إلى %s..." % ip)
	return true

func leave_game() -> void:
	for id in _remote_vehicles.keys():
		if is_instance_valid(_remote_vehicles[id]):
			_remote_vehicles[id].queue_free()
	_remote_vehicles.clear()
	for id in _remote_players.keys():
		if is_instance_valid(_remote_players[id]):
			_remote_players[id].queue_free()
	_remote_players.clear()
	_peers.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_mp_connected = false
	if is_online:
		is_online = false
		is_host = false
		disconnected_from_game.emit()
		net_message.emit("تم قطع الاتصال")

func _wire_mp() -> void:
	if _mp_connected:
		return
	_mp_connected = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	rpc_id(id, "rpc_register_name", player_name)
	_get_remote_player(id)
	_peers[id] = "..."
	peer_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if _remote_vehicles.has(id) and is_instance_valid(_remote_vehicles[id]):
		_remote_vehicles[id].queue_free()
	_remote_vehicles.erase(id)
	if _remote_players.has(id) and is_instance_valid(_remote_players[id]):
		_remote_players[id].queue_free()
	_remote_players.erase(id)
	_peers.erase(id)
	peer_left.emit(id)
	net_message.emit("غادر الصديق الشبكة")

func _on_connected_to_server() -> void:
	rpc_id(1, "rpc_register_name", player_name)
	connected_to_game.emit()
	net_message.emit("تم الاتصال بالمضيف!")

func _on_connection_failed() -> void:
	net_message.emit("فشل الاتصال بالمضيف")
	leave_game()

func _on_server_disconnected() -> void:
	net_message.emit("انقطع اتصال المضيف")
	leave_game()

@rpc("any_peer", "call_remote", "reliable")
func rpc_register_name(nm: String) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		return
	_peers[sid] = nm
	var rp = _get_remote_player(sid)
	if rp:
		rp.set_display_name(nm)
	peer_joined.emit(sid)
	net_message.emit("انضم إلى اللعبة: " + nm)

func _first_other_peer() -> int:
	for id in _peers.keys():
		if int(id) != my_id():
			return int(id)
	return 0

func remote_players_count() -> int:
	return _remote_players.size()

func remote_vehicles_count() -> int:
	return _remote_vehicles.size()

func remote_vehicle_of(peer_id: int):
	return _remote_vehicles.get(peer_id)

func _get_remote_player(id: int):
	if _remote_players.has(id) and is_instance_valid(_remote_players[id]):
		return _remote_players[id]
	var ps: Script = load("res://scripts/network/remote_player.gd")
	if ps == null:
		return null
	var rp = ps.new()
	rp.name = "Remote%d" % id
	rp.peer_id = id
	if _peers.has(id):
		rp.set_display_name(str(_peers[id]))
	var host: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else self
	host.add_child(rp)
	rp.global_position = Vector3(702, 5, 924)
	_remote_players[id] = rp
	return rp

func _get_remote_vehicle(id: int, type: int):
	if _remote_vehicles.has(id) and is_instance_valid(_remote_vehicles[id]):
		var rv = _remote_vehicles[id]
		if rv.vehicle_type == type:
			return rv
		rv.queue_free()
		_remote_vehicles.erase(id)
	var ps: Script = load("res://scripts/network/remote_vehicle.gd")
	if ps == null:
		return null
	var rv = ps.new()
	rv.name = "RemoteVehicle%d" % id
	rv.setup(type, str(_peers.get(id, "صديق")))
	var host: Node = get_tree().current_scene if get_tree() and get_tree().current_scene else self
	host.add_child(rv)
	rv.global_position = Vector3(702, 5, 930)
	_remote_vehicles[id] = rv
	return rv

func _process(delta: float) -> void:
	if not is_online or multiplayer.multiplayer_peer == null or player == null:
		return
	if not is_instance_valid(player):
		return
	_sync_timer -= delta
	if _sync_timer > 0.0:
		return
	_sync_timer = SYNC_INTERVAL
	var anim := "idle"
	var vel: Vector3 = player.velocity if "velocity" in player else Vector3.ZERO
	var moving := vel.length()
	if not player.is_on_floor() if player.has_method("is_on_floor") else false:
		anim = "jump_loop"
	elif moving > 4.0:
		anim = "run"
	elif moving > 0.5:
		anim = "walk"
	var veh := {}
	if "vehicle" in player:
		var pv = player.vehicle
		if pv != null and is_instance_valid(pv):
			var kind := 1
			if "delivery" in String(pv.get("visual_path")) or "truck" in String(pv.name).to_lower():
				kind = 2
			veh = {
				"t": kind,
				"p": pv.global_position,
				"y": pv.global_rotation.y,
				"s": pv.speed_kmh() / 3.6 if pv.has_method("speed_kmh") else 0.0,
				"st": pv.steering if "steering" in pv else 0.0,
			}
	rpc("rpc_state", player.global_position, player.global_rotation.y, anim, veh)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_state(pos: Vector3, yaw: float, anim: String, veh: Dictionary) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		return
	var rp = _get_remote_player(sid)
	if rp == null:
		return
	rp.apply_state(pos, yaw, anim)
	if veh.is_empty():
		if _remote_vehicles.has(sid) and is_instance_valid(_remote_vehicles[sid]):
			_remote_vehicles[sid].queue_free()
			_remote_vehicles.erase(sid)
		rp.set_in_vehicle(null)
	else:
		var rv = _get_remote_vehicle(sid, int(veh.get("t", 1)))
		if rv:
			rv.apply_state(veh.get("p", pos), float(veh.get("y", yaw)), float(veh.get("s", 0.0)), float(veh.get("st", 0.0)))
			rp.set_in_vehicle(rv)
			rv.occupant = rp

func report_attack(target_peer_id: int, damage: float, instant_kill: bool) -> void:
	if not is_online or target_peer_id <= 0 or target_peer_id == my_id():
		return
	if instant_kill:
		rpc_id(target_peer_id, "rpc_friend_killed_victim", KILL_PAYMENT)
		apply_friend_killed_payer()
	else:
		rpc_id(target_peer_id, "rpc_apply_damage", damage)

func check_run_over(pos: Vector3, kmh: float, radius: float) -> void:
	if not is_online or kmh < 15.0:
		return
	for id in _remote_players.keys():
		var rp = _remote_players[id]
		if not is_instance_valid(rp) or rp.is_in_vehicle() != null:
			continue
		if rp.global_position.distance_to(pos) < radius:
			report_attack(int(id), KILL_PAYMENT, true)
			net_message.emit("دهست صديقك! دفعت %d" % int(KILL_PAYMENT))
			return

@rpc("any_peer", "call_remote", "reliable")
func rpc_friend_killed_victim(amount: float) -> void:
	var sid := multiplayer.get_remote_sender_id()
	apply_attack(amount, sid if sid != 0 else 1, true)

@rpc("any_peer", "call_remote", "reliable")
func rpc_do_pay() -> void:
	apply_friend_killed_payer()

@rpc("any_peer", "call_remote", "reliable")
func rpc_apply_damage(damage: float) -> void:
	var sid := multiplayer.get_remote_sender_id()
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.health = maxf(0.0, gs.health - damage)
		net_message.emit("أُصبت بطلق! (%d)" % int(damage))
		if gs.health <= 0.0:
			apply_attack(KILL_PAYMENT, sid if sid != 0 else 1, true)
			if sid != 0:
				rpc_id(sid, "rpc_do_pay")

func apply_attack(amount: float, attacker_id: int, _instant_kill: bool) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.money += amount
		if gs.has_signal("money_changed"):
			gs.money_changed.emit(gs.money)
		gs.health = 100.0
		if player and is_instance_valid(player) and player.has_method("respawn_at"):
			player.respawn_at(player.global_position)
	friend_payment.emit(amount, false)
	net_message.emit("صديقك قتلك! استلمت %d تعويضاً" % int(amount))
	if attacker_id == 0:
		apply_friend_killed_payer()

func apply_friend_killed_payer() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.money -= KILL_PAYMENT
		if gs.has_signal("money_changed"):
			gs.money_changed.emit(gs.money)
	friend_payment.emit(KILL_PAYMENT, true)
	net_message.emit("دفعت %d لصديقك (مقتل الصديق)" % int(KILL_PAYMENT))

func request_loan_networked(amount: float) -> void:
	if not is_online:
		net_message.emit("غير متصل بشبكة — القروض تحتاج صديقاً متصلاً")
		return
	var target := _first_other_peer()
	if target <= 0:
		net_message.emit("لا يوجد صديق متصل الآن")
		return
	_pending_loan_amount = amount
	rpc_id(target, "rpc_loan_request", player_name, amount)
	net_message.emit("أُرسل طلب قرض %d إلى صديقك" % int(amount))

@rpc("any_peer", "call_remote", "reliable")
func rpc_loan_request(from_name: String, amount: float) -> void:
	_pending_loan_from = multiplayer.get_remote_sender_id()
	if _pending_loan_from == 0:
		_pending_loan_from = 1
	_pending_loan_amount = amount
	loan_request_received.emit(from_name, amount)

func respond_to_loan(approve: bool) -> void:
	if _pending_loan_from <= 0:
		return
	if is_online and multiplayer.multiplayer_peer != null:
		rpc_id(_pending_loan_from, "rpc_loan_reply", approve, _pending_loan_amount)
	_pending_loan_from = 0

@rpc("any_peer", "call_remote", "reliable")
func rpc_loan_reply(approved: bool, amount: float) -> void:
	loan_response_received.emit(approved, amount)
	apply_loan_response(approved, amount)

func apply_loan_response(approved: bool, amount: float) -> void:
	if approved:
		var gs := get_node_or_null("/root/GameState")
		if gs:
			gs.money += amount
			if gs.has_signal("money_changed"):
				gs.money_changed.emit(gs.money)
		net_message.emit("وافِق صديقك على قرضك — استلمت %d" % int(amount))
	else:
		net_message.emit("رفض صديقك طلب القرض")
