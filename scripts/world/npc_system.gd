class_name NPCSystem
extends Node3D
## NPC: مشاة في البلدة/السوق + مركبات مرور على الطرق الرئيسية

var pedestrians: Array = []
var traffic: Array = []

func setup(world: Node3D) -> void:
	var terrain := world.get_node_or_null("Terrain3D")
	# ---- المشاة: نقاط تجول بين البلدة والسوق
	var points := [
		Vector3(500, 0, 800), Vector3(560, 0, 830), Vector3(620, 0, 860),
		Vector3(760, 0, 880), Vector3(900, 0, 890), Vector3(1040, 0, 900),
		Vector3(1080, 0, 860), Vector3(520, 0, 760), Vector3(480, 0, 830),
	]
	var npc_paths := [
		"res://assets/models/npc/character-male-a.glb",
		"res://assets/models/npc/character-male-b.glb",
		"res://assets/models/npc/character-male-c.glb",
		"res://assets/models/npc/character-female-a.glb",
		"res://assets/models/npc/character-female-b.glb",
		"res://assets/models/npc/character-female-c.glb",
	]
	for i in 8:
		var n := Node3D.new()
		n.name = "NPC%d" % i
		var ps: PackedScene = load(npc_paths[i % npc_paths.size()])
		if ps:
			var vis := ps.instantiate()
			vis.scale = Vector3.ONE * 1.1
			n.add_child(vis)
		add_child(n)
		var start: Vector3 = points[i % points.size()]
		if terrain and terrain.has_method("get_data"):
			var h: float = terrain.get_data().get_height(start)
			if h > -100.0:
				start.y = h
		n.global_position = start
		pedestrians.append({"node": n, "target_idx": (i + 1) % points.size(), "points": points})
	# ---- المرور: مركبات على الطريق الرئيسي (شرق-غرب z≈800)
	var f := FileAccess.open("res://data/layout.json", FileAccess.READ)
	var road_pts: Array = []
	if f:
		var layout: Dictionary = JSON.parse_string(f.get_as_text())
		f.close()
		var roads: Array = layout.get("roads", [])
		if roads.size() > 0:
			var raw: Array = roads[0].get("points", [])
			for i in range(0, raw.size(), 14):
				road_pts.append(Vector3(float(raw[i][0]), 0, float(raw[i][1])))
	var car_paths := [
		"res://assets/models/vehicles/taxi.glb",
		"res://assets/models/vehicles/van.glb",
		"res://assets/models/vehicles/police.glb",
		"res://assets/models/vehicles/sedan-sports.glb",
	]
	for i in 4:
		var v := Node3D.new()
		v.name = "Traffic%d" % i
		var ps: PackedScene = load(car_paths[i % car_paths.size()])
		if ps:
			var vis := ps.instantiate()
			vis.rotation.y = PI   # النماذج تواجه +Z
			vis.scale = Vector3.ONE * 1.35
			v.add_child(vis)
		add_child(v)
		var idx := i * 3
		if road_pts.size() > 0:
			var p: Vector3 = road_pts[idx % road_pts.size()]
			if terrain and terrain.has_method("get_data"):
				var h2: float = terrain.get_data().get_height(p)
				if h2 > -100.0:
					p.y = h2 + 0.3
			v.global_position = p
			traffic.append({"node": v, "pts": road_pts, "idx": (idx + 1) % road_pts.size(), "speed": 7.0 + i * 0.8})

func _process(delta: float) -> void:
	for ped in pedestrians:
		var n: Node3D = ped["node"]
		var pts: Array = ped["points"]
		var ti: int = ped["target_idx"]
		var target: Vector3 = pts[ti]
		var flat := target - n.global_position
		flat.y = 0
		if flat.length() < 2.0:
			ped["target_idx"] = (ti + 1) % pts.size()
		else:
			n.global_position += flat.normalized() * 1.35 * delta
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-flat.x, -flat.z), 6.0 * delta)
	for t in traffic:
		if t["pts"].is_empty():
			continue
		var n: Node3D = t["node"]
		var pts: Array = t["pts"]
		var idx: int = t["idx"]
		var target: Vector3 = pts[idx]
		var flat := target - n.global_position
		flat.y = 0
		if flat.length() < 3.0:
			t["idx"] = (idx + 1) % pts.size()
		else:
			n.global_position += flat.normalized() * float(t["speed"]) * delta
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-flat.x, -flat.z), 4.0 * delta)

func pedestrian_count() -> int:
	return pedestrians.size()

func traffic_count() -> int:
	return traffic.size()
