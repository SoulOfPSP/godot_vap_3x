extends Control

onready var vap = $VAPPlayer
onready var status = $Status

var screenshot_path = ""
var screenshot_frame = 40
var screenshot_saved = false


func _ready():
	vap.connect("animation_ready", self, "_on_ready")
	vap.connect("animation_started", self, "_on_started")
	vap.connect("animation_finished", self, "_on_finished")
	vap.connect("animation_error", self, "_on_error")
	vap.connect("frame_changed", self, "_on_frame")
	vap.connect("fusion_resource_needed", self, "_on_resource_needed")
	# warning-ignore:return_value_discarded
	$Normal.connect("pressed", self, "_load_normal")
	# warning-ignore:return_value_discarded
	$Fusion.connect("pressed", self, "_load_fusion")

	screenshot_path = OS.get_environment("VAP_SCREENSHOT")
	if not OS.get_environment("VAP_SCREENSHOT_FRAME").empty():
		screenshot_frame = int(OS.get_environment("VAP_SCREENSHOT_FRAME"))
	var requested = OS.get_environment("VAP_DEMO_VIDEO")
	if requested.empty():
		_load_normal()
	else:
		vap.load_vap_video(requested)


func _load_normal():
	screenshot_saved = false
	vap.load_vap_video("res://demo/video.mp4")


func _load_fusion():
	screenshot_saved = false
	vap.load_vap_video("res://demo/vapx.mp4")


func _on_ready(config):
	var info = config["info"]
	status.text = "Ready\n%d × %d\n%d fps · %d frames\nVAPX: %s" % [int(info["w"]), int(info["h"]), int(info["fps"]), int(info["f"]), str(int(info["isVapx"]) == 1)]


func _on_started():
	status.text += "\nPlaying"


func _on_finished():
	status.text += "\nFinished"
	if OS.get_environment("VAP_AUTO_QUIT") == "1":
		get_tree().quit()


func _on_error(message):
	status.text = "ERROR\n" + str(message)
	if OS.get_environment("VAP_AUTO_QUIT") == "1":
		get_tree().quit(2)


func _on_frame(frame):
	if frame % 10 == 0:
		var lines = status.text.split("\n")
		if lines.size() > 0:
			status.text = "Frame %d\n%s" % [frame, "\n".join(lines)]
	if not screenshot_saved and not screenshot_path.empty() and frame >= screenshot_frame:
		screenshot_saved = true
		call_deferred("_save_screenshot")


func _on_resource_needed(resource_id, resource_type):
	if resource_type == "txt":
		vap.set_fusion_resource(resource_id, "Godot VAP")
	else:
		var source = vap.get_fusion_source_config(resource_id)
		var image = Image.new()
		image.create(max(1, int(source.get("w", 256))), max(1, int(source.get("h", 256))), false, Image.FORMAT_RGBA8)
		image.fill(Color(0.12, 0.95, 0.38, 1.0))
		vap.set_fusion_resource(resource_id, image)


func _save_screenshot():
	yield(VisualServer, "frame_post_draw")
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	var error = image.save_png(screenshot_path)
	print("VAP_SCREENSHOT_SAVED path=", screenshot_path, " error=", error, " frame=", vap.current_frame)
	if OS.get_environment("VAP_AUTO_QUIT") == "1":
		get_tree().quit(error)
