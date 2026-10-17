extends SceneTree
func _process(_d):
    print("children of root:")
    for c in root.get_children():
        print("  ", c.name, " ", c.get_class())
    print("has GameState node: ", root.has_node("GameState"))
    quit(0)
    return true
