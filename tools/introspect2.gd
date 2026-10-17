extends SceneTree
func _init():
    for m in ClassDB.class_get_method_list("Terrain3DUtil", true):
        print("U.", m.name, " args:", m.args.size())
    for m in ClassDB.class_get_method_list("Terrain3DInstancer", true):
        print("I.", m.name, " args:", m.args.size())
    print("enc_base(2)=", Terrain3DUtil.enc_base(2))
    print("enc_auto(1)=", Terrain3DUtil.enc_auto(1) if ClassDB.class_has_method("Terrain3DUtil", "enc_auto") else "N/A")
    var d = Terrain3DData.new()
    print("data props:")
    for p in ClassDB.class_get_property_list("Terrain3DData", true):
        print("  Dp.", p.name)
    quit(0)
