tool
extends EditorPlugin

var vap_player_script = preload("res://addons/godot_vap/vap_player.gd")

func _enter_tree():
	add_custom_type("VAPPlayer", "Control", vap_player_script, null)


func _exit_tree():
	remove_custom_type("VAPPlayer")
