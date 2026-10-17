class_name CharacterConfig
extends Resource
## إعدادات الشخصية — يُعدَّل هذا الملف فقط عند إدخال شخصيتك الخاصة

@export var display_name := "الناجي"
@export var model_path := "res://assets/models/character/Knight.glb"
@export var hand_bone := "handslot.r"
@export var scale := 1.0
@export var move_speed := 3.2
@export var run_speed := 6.2
@export var jump_velocity := 4.6
@export var blend_time := 0.2

@export_group("أسماء الأنيميشن")
@export var anim_idle := "Idle"
@export var anim_walk := "Walking_A"
@export var anim_run := "Running_A"
@export var anim_jump_start := "Jump_Start"
@export var anim_jump_loop := "Jump_Idle"
@export var anim_jump_land := "Jump_Land"
@export var anim_sit_down := "Sit_Chair_Down"
@export var anim_sit_idle := "Sit_Chair_Idle"
@export var anim_sit_up := "Sit_Chair_StandUp"
@export var anim_sleep_down := "Lie_Down"
@export var anim_sleep_idle := "Lie_Idle"
@export var anim_sleep_up := "Lie_StandUp"
@export var anim_carry_idle := "2H_Melee_Idle"
@export var anim_carry_walk := "Walking_A"
@export var anim_carry_run := "Running_A"
@export var anim_aim := "2H_Ranged_Aiming"
@export var anim_shoot := "2H_Ranged_Shooting"
@export var anim_reload := "2H_Ranged_Reload"
@export var anim_interact := "Interact"
@export var anim_pickup := "PickUp"
@export var anim_wave := "Cheer"
@export var anim_hurt := "Hit_A"
@export var anim_death := "Death_A"
