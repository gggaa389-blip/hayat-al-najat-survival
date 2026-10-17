extends SceneTree
## أداة بناء بيانات التضاريس (Terrain3D) من الملفات الخام المولّدة بـ Python
## تُشغَّل مرة واحدة: godot --headless --path . --script tools/build_terrain.gd
## تعمل على أول إطار (_process) حتى تُهيَّأ بيانات Terrain3D داخل الشجرة.

const N := 1536
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	print("== build_terrain: تحميل البيانات الخام ==")
	var hbytes := FileAccess.get_file_as_bytes("res://data/heights.raw")
	var cbytes := FileAccess.get_file_as_bytes("res://data/control.raw")
	if hbytes.size() != N * N * 4 or cbytes.size() != N * N * 4:
		push_error("حجم الملفات الخام غير متوقع")
		quit(1); return true
	var h_img := Image.create_from_data(N, N, false, Image.FORMAT_RF, hbytes)
	var c_img := Image.create_from_data(N, N, false, Image.FORMAT_RF, cbytes)
	print("  heights+control: %dx%d" % [h_img.get_width(), h_img.get_height()])

	# ---- عقدة التضاريس داخل الشجرة (تهيّئ البيانات)
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	var cam := Camera3D.new()
	cam.name = "BuildCamera"
	cam.position = Vector3(500, 120, 800)
	root.add_child(cam)
	root.add_child(terrain)
	terrain.set_camera(cam)
	var data: Terrain3DData = terrain.get_data()
	if data == null:
		push_error("تعذر تهيئة Terrain3DData")
		quit(1); return true
	print("  البيانات مهيأة")

	# ---- خامات الأرض (4 طبقات)
	var assets := Terrain3DAssets.new()
	var tex_names := ["grass", "sand", "dirt", "rock"]
	for i in tex_names.size():
		var t := Terrain3DTextureAsset.new()
		t.name = tex_names[i]
		t.albedo_texture = load("res://assets/textures/%s_albedo.png" % tex_names[i])
		t.normal_texture = load("res://assets/textures/%s_normal.png" % tex_names[i])
		t.uv_scale = 0.25
		t.detiling_rotation = 0.25 if i >= 2 else 0.1
		t.detiling_shift = 0.25
		t.normal_depth = 1.0
		assets.set_texture(i, t)
	terrain.set_assets(assets)

	# ---- استيراد الصور (تُقسَّم تلقائياً إلى مناطق)
	var imported: Array[Image] = [h_img, c_img, null]
	data.import_images(imported, Vector3(0, 0, 0), 0.0, 1.0)
	print("  عدد المناطق: %d" % data.get_region_count())
	data.calc_height_range(true)

	# ---- الحفظ
	data.save_directory("res://data/terrain")
	print("== تم حفظ المناطق ==")
	var aerr := ResourceSaver.save(assets, "res://data/terrain/terrain_assets.tres")
	print("== حفظ الأصول: err=%d ==" % aerr)

	# ---- تحقق
	var h0 := data.get_height(Vector3(500, 0, 800))
	var c0 := data.get_control_base_id(Vector3(500, 0, 800))
	var h1 := data.get_height(Vector3(1150, 0, 800))
	var c1 := data.get_control_base_id(Vector3(1150, 0, 800))
	var h2 := data.get_height(Vector3(1150, 0, 300))
	print("تحقق: البلدة(500,800)=%.2f خامة=%d | الطريق(1150,800)=%.2f خامة=%d | البحيرة(1150,300)=%.2f" % [h0, c0, h1, c1, h2])
	print("== build_terrain: اكتمل ==")
	quit(0)
	return true
