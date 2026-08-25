tool
extends EditorPlugin

var vap_player_script = preload("res://addons/godot_vap/vap_player.gd")
var mp4_path_importer = preload("res://addons/godot_vap/mp4_path_importer.gd").new()

func _enter_tree():
	add_custom_type("VAPPlayer", "Control", vap_player_script, null)
	add_import_plugin(mp4_path_importer)


func _exit_tree():
	remove_import_plugin(mp4_path_importer)
	remove_custom_type("VAPPlayer")
