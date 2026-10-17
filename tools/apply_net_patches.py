#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""تطبيق تعديلات الشبكة على القاعدة القديمة — يعمل بعد أي استعادة"""
import os, re

ROOT = "/home/user/survival_game"

def patch(path, old, new, label):
    p = os.path.join(ROOT, path)
    if not os.path.isfile(p):
        print("MISSING:", path); return False
    s = open(p).read()
    if new.strip() in s:
        print("ALREADY:", label); return True
    if old not in s:
        print("NOT-FOUND:", label); return False
    s = s.replace(old, new, 1)
    open(p, "w").write(s)
    print("PATCHED:", label); return True

# 1) player.gd
patch("scripts/player/player.gd",
      "collision_mask = 1 | 4 | 8",
      "collision_mask = 1 | 4 | 8 | 32", "player mask 1")
patch("scripts/player/player.gd",
      "PhysicsRayQueryParameters3D.create(from, to, 1 | 8)",
      "PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 32)", "player fire ray")
patch("scripts/player/player.gd",
      """\tif hit and hit.collider and hit.collider.has_method(\"on_hit\"):\n\t\thit.collider.on_hit(1, self)""",
      """\tif hit and hit.collider and hit.collider.has_method(\"on_hit\"):\n\t\tif hit.collider.has_method(\"is_remote_player\") and hit.collider.is_remote_player():\n\t\t\thit.collider.on_hit(34.0, self)\n\t\telse:\n\t\t\thit.collider.on_hit(1, self)""", "player on_hit 34")

# 2) vehicle.gd — دهس الأصدقاء
patch("scripts/vehicles/vehicle.gd",
      "func speed_kmh() -> float:\n\treturn linear_velocity.length() * 3.6",
      "func speed_kmh() -> float:\n\treturn linear_velocity.length() * 3.6\n\nfunc _physics_process_net() -> void:\n\tvar net := get_tree().get_first_node_in_group(\"network\") if get_tree() else null\n\tif net and net.has_method(\"check_run_over\"):\n\t\tnet.check_run_over(global_position, speed_kmh(), 1.8)", "vehicle net func")
patch("scripts/vehicles/vehicle.gd",
      "\t\t\t\t_engine_audio.stop()\n\nfunc speed_kmh()",
      "\t\t\t\t_engine_audio.stop()\n\t_physics_process_net()\n\nfunc speed_kmh()", "vehicle net call")

# 3) hud.gd — واجهة الشبكة
HUDVARS = """var fuel_bar: ProgressBar
var fuel_label: Label"""
patch("scripts/ui/hud.gd", HUDVARS, HUDVARS + """
var btn_network: Button
var net_panel: PanelContainer
var net_name_edit: LineEdit
var net_ip_edit: LineEdit
var net_status_label: Label
var net_host_btn: Button
var net_join_btn: Button
var net_leave_btn: Button
var loan_panel: PanelContainer
var loan_label: Label""", "hud vars")

NETUI = open(os.path.join(ROOT, "scripts/ui/_netui_snippet.gd")).read()
patch("scripts/ui/hud.gd", "func _build_keypad(parent: Control) -> void:", NETUI + "\nfunc _build_keypad(parent: Control) -> void:", "hud net ui")
patch("scripts/ui/hud.gd", "\t_build_indicators()\n\t_build_keypad(root)", "\t_build_indicators()\n\t_build_keypad(root)\n\t_build_network_ui(root)", "hud net call")

# 4) main.gd — ربط الشبكة
MAINWIRE = open(os.path.join(ROOT, "scripts/main/_wire_snippet.gd")).read()
patch("scripts/main/main.gd", "\t$NPCSystem.setup(world)", "\t$NPCSystem.setup(world)\n\t_wire_network(player)", "main wire call")
patch("scripts/main/main.gd", "func _on_player_died(", MAINWIRE + "\nfunc _on_player_died(", "main wire func")

# 5) Main.tscn
p = os.path.join(ROOT, "scenes/main/Main.tscn")
s = open(p).read()
if "network_manager.gd" not in s:
    s = s.replace('[ext_resource type="Script" path="res://scripts/world/weather_system.gd" id="12"]',
                  '[ext_resource type="Script" path="res://scripts/world/weather_system.gd" id="12"]\n[ext_resource type="Script" path="res://scripts/network/network_manager.gd" id="20"]')
    s = s.replace('[node name="VehicleManager" type="Node3D" parent="."]\nscript = ExtResource("6")',
                  '[node name="VehicleManager" type="Node3D" parent="."]\nscript = ExtResource("6")\n\n[node name="NetworkManager" type="Node" parent="."]\nscript = ExtResource("20")')
    open(p, "w").write(s)
    print("PATCHED: Main.tscn")
else:
    print("ALREADY: Main.tscn")

# تحقق من وجود معرف فريد
ids = re.findall(r'id="(\d+)"', open(p).read())
print("ext ids:", sorted(set(ids), key=int)[-4:])
