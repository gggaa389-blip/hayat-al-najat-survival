extends SceneTree
func _process(_d):
    for path in ["res://assets/models/vehicles/sedan.glb", "res://assets/models/vehicles/truck.glb", "res://assets/models/vehicles/delivery.glb", "res://assets/models/vehicles/truck-flat.glb"]:
        var inst = (load(path) as PackedScene).instantiate()
        root.add_child(inst)
        var verts := PackedVector3Array()
        _verts(inst, Transform3D.IDENTITY, verts)
        if verts.is_empty():
            print(path.get_file(), " NO VERTS"); inst.queue_free(); continue
        var mn := verts[0]; var mx := verts[0]
        for v in verts:
            mn = mn.min(v); mx = mx.max(v)
        var y_thresh: float = mn.y + (mx.y - mn.y) * 0.8
        var top_z := 0.0; var top_n := 0
        for v in verts:
            if v.y >= y_thresh:
                top_z += v.z; top_n += 1
        print("%s size=%s top_z=%.2f n=%d/%d" % [path.get_file(), str((mx - mn).snapped(Vector3(0.01, 0.01, 0.01))), top_z / maxf(1, top_n), top_n, verts.size()])
        inst.queue_free()
    quit(0)
    return true

func _verts(n: Node, acc: Transform3D, out: PackedVector3Array) -> void:
    var t := acc
    if n is Node3D:
        t = acc * (n as Node3D).transform
    if n is MeshInstance3D and (n as MeshInstance3D).mesh:
        var mesh: Mesh = (n as MeshInstance3D).mesh
        for s in mesh.get_surface_count():
            var arr := mesh.surface_get_arrays(s)
            var varr: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
            for v in varr:
                out.append(t * v)
    for c in n.get_children():
        _verts(c, t, out)
