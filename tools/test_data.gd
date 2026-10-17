extends SceneTree
func _initialize():
    var d := Terrain3DData.new()
    print("data ok: ", d != null)
    var names := []
    for m in d.get_method_list():
        names.append(m.name)
    print("has import_images: ", names.has("import_images"))
    print("has save_directory: ", names.has("save_directory"))
    print("has save_region: ", names.has("save_region"))
    print("D methods:", names.filter(func(n): return n.begins_with("import") or n.begins_with("export") or n.begins_with("save") or n.begins_with("load") or n.contains("region")))
    quit(0)
