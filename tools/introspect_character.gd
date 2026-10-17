extends SceneTree
func _process(_d):
    var ps: PackedScene = load("res://assets/models/character/Knight.glb")
    var inst = ps.instantiate()
    root.add_child(inst)
    print("ROOT: ", inst.name, " class=", inst.get_class())
    for c in inst.get_children():
        print("  child: ", c.name, " ", c.get_class())
    var sk := _find_skeleton(inst)
    if sk:
        print("SKELETON bones (", sk.get_bone_count(), "):")
        var names := []
        for i in sk.get_bone_count():
            names.append(sk.get_bone_name(i))
        print("  ", names)
    var ap := _find_anim_player(inst)
    if ap:
        print("ANIMS (", ap.get_animation_list().size(), "):")
        print("  ", Array(ap.get_animation_list()))
    inst.queue_free()
    quit(0)
    return true

func _find_skeleton(n: Node) -> Skeleton3D:
    if n is Skeleton3D: return n
    for c in n.get_children():
        var r := _find_skeleton(c)
        if r: return r
    return null

func _find_anim_player(n: Node) -> AnimationPlayer:
    if n is AnimationPlayer: return n
    for c in n.get_children():
        var r := _find_anim_player(c)
        if r: return r
    return null
