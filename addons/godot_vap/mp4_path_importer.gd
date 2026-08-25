tool
extends EditorImportPlugin


func get_importer_name():
	return "godot_vap.mp4_path"


func get_visible_name():
	return "MP4 Path"


func get_recognized_extensions():
	return ["mp4"]


func get_save_extension():
	return "res"


func get_resource_type():
	return "Resource"


func get_preset_count():
	return 1


func get_preset_name(preset):
	return "Default"


func get_import_options(preset):
	return []


func get_option_visibility(option, options):
	return true


func import(source_file, save_path, options, platform_variants, gen_files):
	var mp4_path_resource = Resource.new()
	mp4_path_resource.resource_name = source_file.get_file()
	return ResourceSaver.save(save_path + "." + get_save_extension(), mp4_path_resource)
