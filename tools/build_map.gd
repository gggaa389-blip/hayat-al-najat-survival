extends SceneTree
## أداة بناء مشهد العالم World.tscn — المرحلة الأولى (الخريطة)
## تُشغَّل بعد build_terrain.gd:
##   godot --headless --path . --script tools/build_map.gd

const N := 1536
const MOD := "res://assets/models"

var layout: Dictionary
var heights: PackedFloat32Array
var tree_mask: PackedByteArray
var rng := RandomNumberGenerator.new()
var count := {"trees": 0, "bushes": 0, "rocks": 0, "houses": 0, "shops": 0}

# عقد الجذر
var world: Node3D
var roads_node: Node3D
var water_node: Node3D
var town_node: Node3D
var market_node: Node3D
var forest_node: Node3D
var gas_node: Node3D
var house_node: Node3D
var signs_node: Node3D

func _process(_delta: float) -> bool:
	if world != null:
		return true
	rng.seed = 20261016
	print("== build_map: تحميل البيانات ==")
	var txt := FileAccess.get_file_as_string("res://data/layout.json")
	if txt.is_empty():
		push_error("لا يوجد res://data/layout.json"); quit(1); return true
	layout = JSON.parse_string(txt)
	var hbytes := FileAccess.get_file_as_bytes("res://data/heights.raw")
	heights = hbytes.to_float32_array()
	tree_mask = FileAccess.get_file_as_bytes("res://data/treemask.raw")
	print("  الخريطة %d م، ارتفاعات %d نقطة" % [int(layout.map_size), heights.size()])

	# ---------------- الهيكل
	world = Node3D.new(); world.name = "World"
	root.add_child(world)

	_build_environment()
	_build_terrain_node()
	_build_water()
	_build_roads()
	_build_town()
	_build_market()
	_build_forest()
	_build_gas_stations()
	_build_player_house()
	_build_signs()
	_build_debug_camera()

	# ---------------- الحفظ (مع تعيين ملكية العقد المشكِّلة للمشهد)
	_ensure_owned(world, world)
	DirAccess.make_dir_recursive_absolute("res://scenes/world")
	var scene := PackedScene.new()
	var err := scene.pack(world)
	if err == OK:
		err = ResourceSaver.save(scene, "res://scenes/world/World.tscn")
	print("== build_map: حفظ المشهد err=%d ==" % err)
	print("== الإحصاءات: ", count, " ==")
	print("== build_map: اكتمل ==")
	quit(0)
	return true

## تعيين owner للعقد المُنشأة يدوياً (بدون التعمق داخل المشاهد المستوردة)
func _ensure_owned(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		if String(c.scene_file_path).is_empty():
			_ensure_owned(c, owner_node)

# ================================================================
# أدوات مساعدة
# ================================================================
func h_at(x: float, z: float) -> float:
	var xi := clampi(int(x), 0, N - 1)
	var zi := clampi(int(z), 0, N - 1)
	return heights[zi * N + xi]

func mask_at(x: float, z: float) -> int:
	var xi := clampi(int(x), 0, N - 1)
	var zi := clampi(int(z), 0, N - 1)
	return int(tree_mask[zi * N + xi])

func glb(path: String) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("موديل مفقود: " + path)
		return Node3D.new()
	return ps.instantiate()

func find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := find_mesh(c)
		if m:
			return m
	return null

func mesh_of(path: String) -> Mesh:
	var mi := find_mesh(glb(path))
	return mi.mesh if mi else null

func aabb_size(path: String) -> Vector3:
	var mi := find_mesh(glb(path))
	return mi.mesh.get_aabb().size if mi and mi.mesh else Vector3.ONE

func mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func label3d(text: String, size := 0.12, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Tajawal-Bold.ttf")
	l.font_size = 96
	l.pixel_size = size
	l.modulate = color
	l.outline_size = 24
	l.outline_modulate = Color(0.1, 0.1, 0.1, 0.9)
	l.double_sided = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l

# ================================================================
# البيئة والشمس
# ================================================================
func _build_environment() -> void:
	var we := WorldEnvironment.new(); we.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.48, 0.82)
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sky_mat.ground_horizon_color = Color(0.55, 0.60, 0.55)
	sky_mat.ground_bottom_color = Color(0.35, 0.38, 0.33)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.9)
	env.fog_density = 0.0006
	env.fog_aerial_perspective = 0.35
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new(); sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	world.add_child(sun)

# ================================================================
# التضاريس
# ================================================================
func _build_terrain_node() -> void:
	var terrain := Terrain3D.new(); terrain.name = "Terrain3D"
	terrain.set_data_directory("res://data/terrain")
	terrain.set_assets(load("res://data/terrain/terrain_assets.tres"))
	terrain.set_collision_layer(1)
	terrain.set_collision_mask(1)
	world.add_child(terrain)

# ================================================================
# الماء
# ================================================================
func _water_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 water_color : source_color = vec4(0.12, 0.38, 0.58, 0.82);
uniform float wave_speed = 0.55;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.22 + TIME * wave_speed) * 0.06 + cos(wpos.z * 0.19 + TIME * wave_speed * 0.8) * 0.06;
}
void fragment() {
	float w = sin(wpos.x * 0.22 + TIME * wave_speed) * cos(wpos.z * 0.19 + TIME * wave_speed * 0.8);
	ALBEDO = water_color.rgb + vec3(w * 0.045);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	ALPHA = water_color.a;
}
"""
	return sm

func _build_water() -> void:
	water_node = Node3D.new(); water_node.name = "Water"
	world.add_child(water_node)
	for lake in layout.lakes:
		var r: float = lake.radius
		var w := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(r * 2.2, r * 2.2)
		w.mesh = pm
		w.material_override = _water_material()
		w.position = Vector3(lake.center[0], lake.water_y, lake.center[1])
		water_node.add_child(w)

# ================================================================
# الطرق (شرائط تتبع التضاريس + اصطدام)
# ================================================================
func _build_roads() -> void:
	roads_node = Node3D.new(); roads_node.name = "Roads"
	world.add_child(roads_node)
	var bridge_specs := []   # [center(Vector3), yaw, length]
	for road in layout.roads:
		var pts: Array = road.points
		var width: float = road.width
		var kind: String = road.kind
		var surf := SurfaceTool.new()
		surf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lakeA: Vector2 = Vector2(layout.lakes[0].center[0], layout.lakes[0].center[1])
		var lake_r: float = layout.lakes[0].radius * 0.95
		var verts := []
		for i in pts.size():
			var p := Vector2(pts[i][0], pts[i][1])
			var on_bridge := p.distance_to(lakeA) < lake_r and kind == "sand" and pts.size() > 10
			var y := h_at(p.x, p.y) + 0.07
			if on_bridge:
				y = 2.95
			verts.append(Vector3(p.x, y, p.y))
		for i in range(verts.size() - 1):
			var a: Vector3 = verts[i]
			var b: Vector3 = verts[i + 1]
			var dir := (b - a)
			dir.y = 0
			if dir.length() < 0.01:
				continue
			dir = dir.normalized()
			var side := dir.cross(Vector3.UP).normalized() * (width * 0.5)
			var l0 := a - side; var r0 := a + side
			var l1 := b - side; var r1 := b + side
			var v0 := a.distance_to(b)
			# المثلثان
			for tri in [[l0, r0, l1], [r0, r1, l1]]:
				var n := Vector3.UP
				surf.set_normal(n); surf.set_uv(Vector2(0, 0)); surf.add_vertex(tri[0])
				surf.set_normal(n); surf.set_uv(Vector2(1, 0)); surf.add_vertex(tri[1])
				surf.set_normal(n); surf.set_uv(Vector2(0.5, v0 / 4.0)); surf.add_vertex(tri[2])
			# اصطدام الشريط
			var mid := (a + b) * 0.5
			var seg_len := a.distance_to(b)
			if seg_len > 0.2:
				var body := StaticBody3D.new()
				body.collision_layer = 1
				body.collision_mask = 1
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(width, 0.35, seg_len)
				cs.shape = box
				body.add_child(cs)
				body.position = mid + Vector3(0, -0.12, 0)
				body.rotation.y = atan2(dir.x, dir.z)
				roads_node.add_child(body)
		surf.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = surf.commit()
		var m := StandardMaterial3D.new()
		var tex_name := "dirt" if kind == "dirt" else "sand"
		m.albedo_texture = load("res://assets/textures/%s_albedo.png" % tex_name)
		m.normal_texture = load("res://assets/textures/%s_normal.png" % tex_name)
		m.normal_enabled = true
		m.roughness = 0.95
		m.uv1_scale = Vector3(width * 0.35, 1, 0.25)
		mi.material_override = m
		roads_node.add_child(mi)

	# ---- جسر خشبي فوق البحيرة الأولى على الطريق المتقاطع معها
	var lakeA := Vector3(layout.lakes[0].center[0], 0, layout.lakes[0].center[1])
	var bridge_dir := Vector3(0, 0, -1)
	var bridge_len := 8.0
	var size := aabb_size(MOD + "/nature/bridge_wood.glb")
	if size.z > 0.5:
		bridge_len = size.z
	var start := Vector3(lakeA.x, 2.95, lakeA.z + layout.lakes[0].radius * 0.92)
	for i in 100:
		var pos := start + bridge_dir * (bridge_len * float(i))
		if pos.distance_to(lakeA) > layout.lakes[0].radius * 1.05:
			break
		var br := glb(MOD + "/nature/bridge_wood.glb")
		br.position = pos
		br.rotation.y = 0.0
		roads_node.add_child(br)
	# منصة الصيد + السنارة عند منتصف الجسر
	var pier := glb(MOD + "/survival/campfire-fishing-stand.glb")
	pier.position = Vector3(lakeA.x + 2.2, 3.05, lakeA.z + 18.0)
	pier.rotation_degrees = Vector3(0, 180, 0)
	roads_node.add_child(pier)

# ================================================================
# البلدة
# ================================================================
func _build_town() -> void:
	town_node = Node3D.new(); town_node.name = "Town"
	world.add_child(town_node)

	# بيوت ملونة بأحواش
	for h in layout.houses:
		var inst := glb(MOD + "/suburban/" + String(h.model).get_file())
		inst.position = Vector3(h.x, h_at(h.x, h.z) - 0.05, h.z)
		inst.rotation_degrees = Vector3(0, h.rot, 0)
		town_node.add_child(inst)
		count.houses += 1
		# حوش السور حول البيت
		var yard_r := 13.0
		_build_fence_rect(Vector2(h.x, h.z), yard_r, inst.rotation.y, false)

	# ساحة مع نافورة
	var plaza := Vector2(layout.town.center[0] - 70, layout.town.center[1] - 60)
	var fountain := glb(MOD + "/fantasy/fountain-round.glb")
	fountain.position = Vector3(plaza.x, h_at(plaza.x, plaza.y), plaza.y)
	town_node.add_child(fountain)

	# أعمدة إنارة على امتداد الشارع
	for i in 8:
		var lx: float = float(layout.town.center[0]) - 30.0 + float(i) * 10.0
		var lz: float = float(layout.town.center[1]) - 30.0
		if abs(lx - 500) < 12:
			continue
		var lamp := glb(MOD + "/fantasy/lantern.glb")
		lamp.position = Vector3(lx, h_at(lx, lz), lz)
		town_node.add_child(lamp)

	# عربة خشبية (ديكور)
	var cart := glb(MOD + "/fantasy/cart.glb")
	cart.position = Vector3(plaza.x + 12, h_at(plaza.x + 12, plaza.y + 8), plaza.y + 8)
	town_node.add_child(cart)

func _build_fence_rect(center: Vector2, radius: float, rot: float, tall: bool) -> void:
	var piece_path := MOD + "/suburban/fence.glb"
	var size := aabb_size(piece_path)
	var step := maxf(size.x, 2.0)
	var corners := []
	for i in 4:
		var a := rot + PI * 0.5 * float(i)
		corners.append(center + Vector2(cos(a), sin(a)) * radius)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var dist := a.distance_to(b)
		var n := maxi(1, int(dist / step))
		var yaw := atan2(b.x - a.x, b.y - a.y)
		for j in n:
			var t := (float(j) + 0.5) / float(n)
			var p := a.lerp(b, t)
			if abs(p.x - 500) < 12 or abs(p.y - 800) < 12:
				continue
			var f := glb(piece_path)
			f.position = Vector3(p.x, h_at(p.x, p.y), p.y)
			f.rotation.y = yaw + PI * 0.5
			# تقصير القطعة لتناسب المسافة
			f.scale = Vector3(step / maxf(size.x, 0.5), 1, 1)
			town_node.add_child(f)

# ================================================================
# السوق
# ================================================================
func _build_market() -> void:
	market_node = Node3D.new(); market_node.name = "Market"
	world.add_child(market_node)

	for s in layout.market_shops:
		var inst := glb(MOD + "/commercial/" + String(s.model).get_file())
		inst.position = Vector3(s.x, h_at(s.x, s.z) - 0.05, s.z)
		inst.rotation_degrees = Vector3(0, s.rot, 0)
		market_node.add_child(inst)
		count.shops += 1

		# مظلة أمام المحل
		var awning := glb(MOD + "/commercial/detail-awning-wide.glb")
		var yaw := deg_to_rad(s.rot)
		var front := Vector3(sin(yaw), 0, cos(yaw)) * 6.5
		awning.position = inst.position + front + Vector3(0, 3.4, 0)
		awning.rotation.y = yaw
		market_node.add_child(awning)

		# لوحة المتجر
		var sign := _make_shop_sign(String(s.sign), s.kind)
		sign.position = inst.position + front * 1.12 + Vector3(0, 4.6, 0)
		sign.rotation.y = yaw
		market_node.add_child(sign)

	# مظلات الطاولات وسط السوق
	var cx: float = layout.market.center[0]
	var cz: float = layout.market.center[1]
	for i in 3:
		var px := cx - 30 + i * 30
		var pz := cz + 5
		var parasol := glb(MOD + "/commercial/detail-parasol-a.glb")
		parasol.position = Vector3(px, h_at(px, pz), pz)
		market_node.add_child(parasol)
		var disp := glb(MOD + "/market/display-fruit.glb") if i % 2 == 0 else glb(MOD + "/market/display-bread.glb")
		disp.position = Vector3(px + 3, h_at(px + 3, pz), pz)
		disp.rotation_degrees = Vector3(0, 90 * i, 0)
		market_node.add_child(disp)
	# عربة تسوق + سلة
	var sc := glb(MOD + "/market/shopping-cart.glb")
	sc.position = Vector3(cx + 40, h_at(cx + 40, cz + 20), cz + 20)
	sc.rotation_degrees = Vector3(0, 40, 0)
	market_node.add_child(sc)

func _make_shop_sign(text: String, kind: String) -> Node3D:
	var g := Node3D.new()
	g.name = "ShopSign"
	var colors := {
		"food": Color(0.83, 0.55, 0.22), "water": Color(0.25, 0.55, 0.82),
		"sleep": Color(0.62, 0.42, 0.78), "fish": Color(0.22, 0.62, 0.62),
		"animals": Color(0.72, 0.52, 0.32),
	}
	var col: Color = colors.get(kind, Color(0.3, 0.5, 0.3))
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.5, 1.4, 0.22)
	board.mesh = bm
	board.material_override = mat(col)
	board.position = Vector3(0, 0, 0)
	g.add_child(board)
	var l := label3d(text, 0.055, Color.WHITE)
	l.position = Vector3(0, 0, 0.14)
	g.add_child(l)
	return g

# ================================================================
# الغابة والأشجار (MultiMesh)
# ================================================================
func _build_forest() -> void:
	forest_node = Node3D.new(); forest_node.name = "Foliage"
	world.add_child(forest_node)

	var tree_models := [
		MOD + "/nature/tree_oak.glb", MOD + "/nature/tree_default.glb",
		MOD + "/nature/tree_pineTallA.glb", MOD + "/nature/tree_pineRoundA.glb",
		MOD + "/nature/tree_tall.glb", MOD + "/nature/tree_fat.glb",
		MOD + "/nature/tree_detailed.glb", MOD + "/nature/tree_simple.glb",
	]
	var bush_models := [
		MOD + "/nature/plant_bush.glb", MOD + "/nature/plant_bushLarge.glb",
		MOD + "/nature/plant_bushSmall.glb", MOD + "/nature/plant_flatTall.glb",
		MOD + "/nature/grass_large.glb",
	]
	var rock_models := [
		MOD + "/nature/rock_largeA.glb", MOD + "/nature/rock_smallA.glb",
		MOD + "/nature/rock_tallA.glb", MOD + "/nature/log.glb",
	]
	var flower_models := [
		MOD + "/nature/flower_redA.glb", MOD + "/nature/flower_yellowA.glb",
		MOD + "/nature/flower_purpleA.glb",
	]

	var per_model := {}     # path -> Array[Transform3D]
	var colliders := []     # Transform3D للأشجار الكبيرة
	for m in tree_models + bush_models + rock_models + flower_models:
		per_model[m] = []

	var step := 2
	var zi := 0
	while zi < N:
		var xi := 0
		while xi < N:
			var v := int(tree_mask[zi * N + xi])
			xi += step
			if v == 0:
				continue
			var x := float(xi - step) + rng.randf_range(-0.8, 0.8)
			var z := float(zi) + rng.randf_range(-0.8, 0.8)
			var y := h_at(x, z)
			var t := Transform3D()
			var path: String
			if v == 2:
				# غابة كثيفة: أشجار + شجيرات أحياناً
				if rng.randf() < 0.22:
					path = bush_models[rng.randi_range(0, bush_models.size() - 1)]
				else:
					path = tree_models[rng.randi_range(0, tree_models.size() - 1)]
					colliders.append(Vector3(x, y, z))
			else:
				var r := rng.randf()
				if r < 0.45:
					path = tree_models[rng.randi_range(0, tree_models.size() - 1)]
					colliders.append(Vector3(x, y, z))
				elif r < 0.75:
					path = bush_models[rng.randi_range(0, bush_models.size() - 1)]
				elif r < 0.92:
					path = rock_models[rng.randi_range(0, rock_models.size() - 1)]
				else:
					path = flower_models[rng.randi_range(0, flower_models.size() - 1)]
			var sc := rng.randf_range(0.85, 1.35)
			if "flower" in path or "grass" in path or "bushSmall" in path:
				sc = rng.randf_range(0.7, 1.1)
			t = Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * sc), Vector3(x, y - 0.06, z))
			per_model[path].append(t)
		zi += step

	for path in per_model:
		var arr: Array = per_model[path]
		if arr.is_empty():
			continue
		var mesh := mesh_of(path)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		forest_node.add_child(mmi)
		if "tree" in path:
			count.trees += arr.size()
		elif "bush" in path or "grass" in path or "flower" in path:
			count.bushes += arr.size()
		else:
			count.rocks += arr.size()

	# اصطدام جذوع الأشجار (للكاميرا والمركبات) — جسم واحد بأشكال متعددة
	if colliders.size() > 0:
		var body := StaticBody3D.new()
		body.name = "TreeColliders"
		body.collision_layer = 1
		body.collision_mask = 1
		var added := 0
		for pos in colliders:
			if added >= 1200:
				break
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.55
			cyl.height = 7.0
			cs.shape = cyl
			cs.position = pos + Vector3(0, 3.5, 0)
			body.add_child(cs)
			added += 1
		forest_node.add_child(body)

# ================================================================
# محطات الوقود
# ================================================================
func _build_gas_stations() -> void:
	gas_node = Node3D.new(); gas_node.name = "GasStations"
	world.add_child(gas_node)
	for g in layout.gas_stations:
		var station := Node3D.new()
		station.name = "GasStation"
		var x: float = g.x; var z: float = g.z
		var y := h_at(x, z)
		station.position = Vector3(x, y, z)
		station.rotation_degrees = Vector3(0, g.rot, 0)

		# مظلة التغطية
		for cx in [-6.0, 6.0]:
			for cz2 in [-4.0, 4.0]:
				var col := glb(MOD + "/bldkit/column-wide.glb")
				col.position = Vector3(cx, 0, cz2)
				col.scale = Vector3(1, 1.35, 1)
				station.add_child(col)
		var roof := glb(MOD + "/bldkit/roof-flat-square.glb")
		roof.position = Vector3(0, 5.0, 0)
		roof.scale = Vector3(3.6, 1, 3.0)
		station.add_child(roof)

		# المضختان
		for px in [-2.6, 2.6]:
			var pump := _make_pump()
			pump.position = Vector3(px, 0, 0)
			station.add_child(pump)

		# مبنى صغير للموظف
		var shop := glb(MOD + "/commercial/building-d.glb")
		shop.position = Vector3(0, 0, -12)
		shop.scale = Vector3(0.55, 0.55, 0.55)
		station.add_child(shop)

		# لوحة المحطة
		var sign := _make_shop_sign(String(g.sign), "gas")
		sign.position = Vector3(0, 6.6, 4.2)
		station.add_child(sign)

		gas_node.add_child(station)

func _make_pump() -> Node3D:
	var g := Node3D.new(); g.name = "FuelPump"
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.2, 0.3, 0.9)
	base.mesh = bm; base.material_override = mat(Color(0.25, 0.25, 0.28), 0.6)
	base.position = Vector3(0, 0.15, 0)
	g.add_child(base)
	var body := MeshInstance3D.new()
	var bodym := BoxMesh.new(); bodym.size = Vector3(1.0, 2.1, 0.7)
	body.mesh = bodym; body.material_override = mat(Color(0.85, 0.22, 0.18), 0.5)
	body.position = Vector3(0, 1.35, 0)
	g.add_child(body)
	var top := MeshInstance3D.new()
	var tm := BoxMesh.new(); tm.size = Vector3(1.1, 0.45, 0.8)
	top.mesh = tm; top.material_override = mat(Color(0.95, 0.95, 0.95), 0.5)
	top.position = Vector3(0, 2.6, 0)
	g.add_child(top)
	var screen := MeshInstance3D.new()
	var sm2 := BoxMesh.new(); sm2.size = Vector3(0.62, 0.42, 0.06)
	screen.mesh = sm2; screen.material_override = mat(Color(0.08, 0.1, 0.1), 0.25)
	screen.position = Vector3(0, 1.8, 0.38)
	g.add_child(screen)
	var nozzle := MeshInstance3D.new()
	var nm := CylinderMesh.new(); nm.height = 0.8; nm.top_radius = 0.06; nm.bottom_radius = 0.08
	nozzle.mesh = nm; nozzle.material_override = mat(Color(0.2, 0.2, 0.22), 0.4, 0.6)
	nozzle.position = Vector3(0.55, 1.2, 0.1)
	nozzle.rotation_degrees = Vector3(20, 0, -55)
	g.add_child(nozzle)
	return g

# ================================================================
# منزل اللاعب: حوش بسور وبوابة + منزل بطابقين + حظيرة
# ================================================================
func _build_player_house() -> void:
	house_node = Node3D.new(); house_node.name = "PlayerHouse"
	world.add_child(house_node)
	var c := Vector2(layout.house.center[0], layout.house.center[1])
	var half: float = layout.house.yard_half
	var y := h_at(c.x, c.y)

	# ---- سور الحوش (مع فجوة البوابة جنوباً)
	var wall_piece := MOD + "/bldkit/border-high.glb"
	var wsize := aabb_size(wall_piece)
	var wstep := maxf(wsize.x, 2.0)
	for side in 4:
		var a: Vector2
		var b: Vector2
		match side:
			0: a = c + Vector2(-half, -half); b = c + Vector2(half, -half)   # جنوب
			1: a = c + Vector2(half, -half); b = c + Vector2(half, half)    # شرق
			2: a = c + Vector2(half, half); b = c + Vector2(-half, half)    # شمال
			3: a = c + Vector2(-half, half); b = c + Vector2(-half, -half)  # غرب
		var dist := a.distance_to(b)
		var n := maxi(1, int(dist / wstep))
		var yaw := atan2(b.x - a.x, b.y - a.y)
		for j in n:
			var t := (float(j) + 0.5) / float(n)
			var p := a.lerp(b, t)
			# فجوة البوابة في منتصف السور الجنوبي
			if side == 0 and absf(t - 0.5) < 0.11:
				continue
			var wall := glb(wall_piece)
			wall.position = Vector3(p.x, h_at(p.x, p.y), p.y)
			wall.rotation.y = yaw + PI * 0.5
			wall.scale = Vector3(wstep / maxf(wsize.x, 0.5), 1, 1)
			house_node.add_child(wall)

	# ---- البوابة
	var gate := Node3D.new(); gate.name = "Gate"
	var gx := c.x; var gz := c.y - half
	gate.position = Vector3(gx, h_at(gx, gz), gz)
	for sgn in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new(); pm.size = Vector3(0.6, 3.2, 0.6)
		post.mesh = pm
		post.material_override = mat(Color(0.35, 0.3, 0.28), 0.7)
		post.position = Vector3(sgn * 2.6, 1.6, 0)
		gate.add_child(post)
	var panel := MeshInstance3D.new()
	var plm := BoxMesh.new(); plm.size = Vector3(4.8, 2.6, 0.18)
	panel.mesh = plm
	panel.material_override = mat(Color(0.25, 0.28, 0.32), 0.5, 0.35)
	panel.position = Vector3(0, 1.35, 0)
	gate.add_child(panel)
	panel.name = "GatePanel"
	# لوحة إدخال الرمز (5 أرقام) — تتفاعل لاحقاً
	var keypad := MeshInstance3D.new()
	var km := BoxMesh.new(); km.size = Vector3(0.55, 0.85, 0.12)
	keypad.mesh = km
	keypad.material_override = mat(Color(0.12, 0.14, 0.16), 0.3)
	keypad.position = Vector3(3.1, 1.5, 0.35)
	keypad.name = "Keypad"
	gate.add_child(keypad)
	var kl := label3d("•••••", 0.03, Color(0.3, 1, 0.5))
	kl.position = Vector3(3.1, 1.5, 0.45)
	gate.add_child(kl)
	house_node.add_child(gate)

	# ---- المنزل (هيكل بطابقين)
	var house := Node3D.new(); house.name = "House"
	house.position = Vector3(c.x, y, c.y + 5)
	var W := 13.0; var D := 10.0; var FH := 3.3
	# الأرضيات
	for fl in 2:
		var floor_mi := MeshInstance3D.new()
		var fm := BoxMesh.new(); fm.size = Vector3(W, 0.25, D)
		floor_mi.mesh = fm
		floor_mi.material_override = mat(Color(0.76, 0.68, 0.55) if fl == 0 else Color(0.68, 0.58, 0.46), 0.85)
		floor_mi.position = Vector3(0, 0.12 + FH * fl, 0)
		house.add_child(floor_mi)
	# الجدران (بحواف ونوافذ)
	var wall_col := Color(0.92, 0.87, 0.78)
	for fl in 2:
		var yb := FH * fl
		# جداران جانبيان + خلفي
		for wdef in [[Vector3(-W/2, 0, 0), Vector3(0.3, FH, D)], [Vector3(W/2, 0, 0), Vector3(0.3, FH, D)], [Vector3(0, 0, -D/2), Vector3(W, FH, 0.3)]]:
			var wall := MeshInstance3D.new()
			var wm := BoxMesh.new(); wm.size = wdef[1]
			wall.mesh = wm
			wall.material_override = mat(wall_col, 0.9)
			wall.position = wdef[0] + Vector3(0, yb + FH / 2, 0)
			house.add_child(wall)
		# الجدار الأمامي مع فتحات (باب في الطابق الأرضي)
		for wdef2 in [[Vector3(-W/2 + 3.2, 0, D/2), Vector3(W - 6.4, FH, 0.3)], [Vector3(-W/2 + 1.1, 0, D/2), Vector3(2.2, FH, 0.3)], [Vector3(W/2 - 1.1, 0, D/2), Vector3(2.2, FH, 0.3)]]:
			var wall := MeshInstance3D.new()
			var wm := BoxMesh.new(); wm.size = wdef2[1]
			wall.mesh = wm
			wall.material_override = mat(wall_col, 0.9)
			wall.position = wdef2[0] + Vector3(0, yb + FH / 2, 0)
			house.add_child(wall)
		# عتب النوافذ (زجاج)
		var glass := MeshInstance3D.new()
		var gm := BoxMesh.new(); gm.size = Vector3(W - 8.2, 1.5, 0.08)
		glass.mesh = gm
		var glassmat := mat(Color(0.55, 0.75, 0.85, 0.35), 0.1)
		glassmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.material_override = glassmat
		glass.position = Vector3(0, yb + 2.0, D/2)
		house.add_child(glass)

	# الدرج (12 درجة)
	for i in 12:
		var st := MeshInstance3D.new()
		var stm := BoxMesh.new(); stm.size = Vector3(2.2, 0.28, 0.8)
		st.mesh = stm
		st.material_override = mat(Color(0.62, 0.5, 0.38), 0.85)
		st.position = Vector3(-W/2 + 2.2, 0.28 + 0.28 * i, -D/2 + 1.6 + 0.78 * i)
		house.add_child(st)

	# الأثاث: غرفة المعيشة (كنبة + كرسي + طاولة)
	var sofa := glb(MOD + "/furniture/loungeSofa.glb")
	sofa.position = Vector3(2.5, 0.28, -D/2 + 2.2)
	sofa.rotation_degrees = Vector3(0, 180, 0)
	house.add_child(sofa)
	var chair := glb(MOD + "/furniture/loungeChair.glb")
	chair.position = Vector3(-1.8, 0.28, -D/2 + 3.0)
	chair.rotation_degrees = Vector3(0, 150, 0)
	house.add_child(chair)
	var table := glb(MOD + "/furniture/tableCoffee.glb")
	table.position = Vector3(1.0, 0.28, -D/2 + 4.6)
	house.add_child(table)
	# الطابق العلوي: سرير + كرسي
	var bed := glb(MOD + "/furniture/bedDouble.glb")
	bed.position = Vector3(3.2, FH + 0.28, -D/2 + 3.0)
	bed.rotation_degrees = Vector3(0, 180, 0)
	house.add_child(bed)
	var chair2 := glb(MOD + "/furniture/chairCushion.glb")
	chair2.position = Vector3(-3.5, FH + 0.28, -D/2 + 3.0)
	house.add_child(chair2)

	# علامات التفاعل (تقرأها HouseSystem)
	var seat1 := Marker3D.new(); seat1.name = "SeatMarker"
	seat1.position = Vector3(-1.8, 0.28, -D/2 + 3.0)
	seat1.rotation.y = 1.05
	house.add_child(seat1)
	var seat2 := Marker3D.new(); seat2.name = "SeatMarker2"
	seat2.position = Vector3(-3.5, FH + 0.28, -D/2 + 3.0)
	seat2.rotation.y = 1.57
	house.add_child(seat2)
	var sleepm := Marker3D.new(); sleepm.name = "SleepMarker"
	sleepm.position = Vector3(3.2, FH + 0.28, -D/2 + 3.0)
	sleepm.rotation.y = PI
	house.add_child(sleepm)

	# السقف (يُخفى لرؤية الداخل)
	var roof := Node3D.new(); roof.name = "Roof"
	var roof_mi := MeshInstance3D.new()
	var rm := BoxMesh.new(); rm.size = Vector3(W + 0.8, 0.35, D + 0.8)
	roof_mi.mesh = rm
	roof_mi.material_override = mat(Color(0.62, 0.3, 0.24), 0.8)
	roof_mi.position = Vector3(0, FH * 2 + 0.3, 0)
	roof.add_child(roof_mi)
	house.add_child(roof)
	house_node.add_child(house)

	# ---- الحظيرة للحيوانات
	var barn := Node3D.new(); barn.name = "Barn"
	barn.position = Vector3(c.x - 12, h_at(c.x - 12, c.y - 10), c.y - 10)
	for cx in [-3.0, 3.0]:
		for cz in [-2.5, 2.5]:
			var col := glb(MOD + "/bldkit/column.glb")
			col.position = Vector3(cx, 0, cz)
			col.scale = Vector3(1, 1.2, 1)
			barn.add_child(col)
	var broof := glb(MOD + "/bldkit/roof-flat-square.glb")
	broof.position = Vector3(0, 4.1, 0)
	broof.scale = Vector3(2.0, 1, 1.8)
	barn.add_child(broof)
	var fence := glb(MOD + "/survival/fence.glb")
	for i in 4:
		var ang := PI * 0.5 * float(i)
		for j in 3:
			var fp := Vector2(cos(ang), sin(ang)) * 6.0 + Vector2(-sin(ang), cos(ang)) * (float(j) - 1.0) * 3.4
			var f := glb(MOD + "/survival/fence.glb") if j % 2 == 0 else glb(MOD + "/survival/fence.glb")
			f.position = Vector3(fp.x, 0, fp.y)
			f.rotation.y = -ang
			barn.add_child(f)
	house_node.add_child(barn)

	# سيارة وشاحنة داخل الحوش (موقف)
	var car := glb(MOD + "/vehicles/sedan.glb")
	car.name = "Car"
	car.position = Vector3(c.x + 12, h_at(c.x + 12, c.y + 2), c.y + 2)
	car.rotation_degrees = Vector3(0, 90, 0)
	house_node.add_child(car)
	var truck := glb(MOD + "/vehicles/truck.glb")
	truck.name = "Truck"
	truck.position = Vector3(c.x + 12, h_at(c.x + 12, c.y - 7), c.y - 7)
	truck.rotation_degrees = Vector3(0, 90, 0)
	house_node.add_child(truck)

# ================================================================
# اللوحات الإرشادية
# ================================================================
func _build_signs() -> void:
	signs_node = Node3D.new(); signs_node.name = "Signs"
	world.add_child(signs_node)
	for s in layout.signs:
		var g := Node3D.new()
		g.name = "Sign_" + String(s.text)
		var x: float = s.x; var z: float = s.z
		g.position = Vector3(x, h_at(x, z), z)
		g.rotation_degrees = Vector3(0, s.rot, 0)
		# عمودان + لوحة
		for sgn in [-1.6, 1.6]:
			var post := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.height = 3.0; pm.top_radius = 0.12; pm.bottom_radius = 0.14
			post.mesh = pm
			post.material_override = mat(Color(0.45, 0.42, 0.4), 0.7, 0.3)
			post.position = Vector3(sgn, 1.5, 0)
			g.add_child(post)
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(5.2, 1.35, 0.16)
		board.mesh = bm
		if s.green:
			board.material_override = mat(Color(0.11, 0.42, 0.22), 0.6)
		else:
			board.material_override = mat(Color(0.42, 0.28, 0.16), 0.7)
		board.position = Vector3(0, 2.45, 0)
		g.add_child(board)
		var l := label3d(String(s.text), 0.052, Color.WHITE)
		l.position = Vector3(0, 2.45, 0.12)
		g.add_child(l)
		signs_node.add_child(g)

# ================================================================
# كاميرا تجريبية (تُستبدل لاحقاً بكاميرا اللاعب)
# ================================================================
func _build_debug_camera() -> void:
	var cam := Camera3D.new(); cam.name = "DebugCamera"
	cam.position = Vector3(520, 95, 760)
	cam.rotation_degrees = Vector3(-32, 8, 0)
	cam.far = 1800.0
	world.add_child(cam)
