extends SceneTree
func _init():
    print("=== Terrain3D ===")
    for m in ClassDB.class_get_method_list("Terrain3D", true):
        print("T3D.", m.name)
    print("=== Terrain3DData ===")
    for m in ClassDB.class_get_method_list("Terrain3DData", true):
        print("D.", m.name)
    print("=== Terrain3DRegion ===")
    for m in ClassDB.class_get_method_list("Terrain3DRegion", true):
        print("R.", m.name, " args:", m.args.size() if m.has("args") else "?")
    print("=== Terrain3DAssets ===")
    for m in ClassDB.class_get_method_list("Terrain3DAssets", true):
        print("A.", m.name)
    print("=== Terrain3DTextureAsset props ===")
    for p in ClassDB.class_get_property_list("Terrain3DTextureAsset", true):
        print("Texp.", p.name)
    print("=== Terrain3DMeshAsset props ===")
    for p in ClassDB.class_get_property_list("Terrain3DMeshAsset", true):
        print("Meshp.", p.name)
    print("=== Terrain3DInstancer ===")
    for m in ClassDB.class_get_method_list("Terrain3DInstancer", true):
        print("I.", m.name)
    print("=== Terrain3DUtil ===")
    for m in ClassDB.class_get_method_list("Terrain3DUtil", true):
        print("U.", m.name)
    quit(0)
