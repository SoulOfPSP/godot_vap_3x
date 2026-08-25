extends Control

# video2.mp4 内嵌的 VAPX 资源对应关系：
#   srcId "0" / [img0]：真正显示头像的蒙版。
#   srcId "1" / [img1]：只提供位置和缩放轨迹，不往里面放头像。
const AVATAR_RESOURCE_ID = "0"
const FOLLOWER_RESOURCE_ID = "1"
const AVATAR_TEXTURE = preload("res://demo/image (4).jpg")
const FOLLOWER_SCENE = preload("res://Node2D.tscn")

onready var vap = $VAPPlayer
onready var status = $Status

var screenshot_path = ""
var screenshot_frame = 40
var screenshot_saved = false
# 保存跟随实例，避免 animation_ready 再次触发时重复创建。
var follower_instance = null


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
	$Fusion.connect("pressed", self, "_load_avatar_fusion")

	screenshot_path = OS.get_environment("VAP_SCREENSHOT")
	if not OS.get_environment("VAP_SCREENSHOT_FRAME").empty():
		screenshot_frame = int(OS.get_environment("VAP_SCREENSHOT_FRAME"))
	var requested = OS.get_environment("VAP_DEMO_VIDEO")
	if requested.empty():
		_load_avatar_fusion()
	else:
		vap.load_vap_video(requested)


func _load_normal():
	screenshot_saved = false
	vap.load_vap_video("res://demo/video.mp4")


func _load_avatar_fusion():
	screenshot_saved = false
	vap.load_vap_video("res://demo/video2.mp4")


func _on_ready(config):
	var info = config["info"]
	var playback = vap.get_playback_info()
	var audio_status = "streaming" if playback["has_audio"] and playback["audio_enabled"] else ("disabled" if playback["has_audio"] else "no track")
	status.text = "Ready\n%d × %d\n%d fps · %d frames\nVAPX: %s\nAudio: %s" % [int(info["w"]), int(info["h"]), int(info["fps"]), int(info["f"]), str(int(info["isVapx"]) == 1), audio_status]

	# VAPX 配置读取完成后，创建一个尚未加入场景树的实例。
	if int(info["isVapx"]) == 1 and follower_instance == null:
		follower_instance = FOLLOWER_SCENE.instance()

		# 绑定到 img1，而不是显示头像的 img0：
		#   FOLLOWER_RESOURCE_ID：使用 img1 每一帧的 frame 位置。
		#   follower_instance：要放在视频上层的 Godot 实例。
		#   true：除了移动，还按 img1 的 frame 宽高逐帧缩放。
		#   Vector2.ZERO：实例中心与 img1 中心重合，不添加偏移。
		vap.add_fusion_follower(
			FOLLOWER_RESOURCE_ID,
			follower_instance,
			true,
			Vector2.ZERO
		)

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
	# 文字资源仍然使用 VAP 原本的动态文字注入逻辑。
	if resource_type == "txt":
		vap.set_fusion_resource(resource_id, "Godot VAP")
		return

	# 只有 img0 需要显示头像，所以只给 srcId "0" 设置头像纹理。
	if str(resource_id) == AVATAR_RESOURCE_ID:
		vap.set_fusion_resource(resource_id, AVATAR_TEXTURE)
		return

	# img1 只是一条隐藏的运动/缩放轨迹。
	# 不调用 set_fusion_resource()，因此 img1 本身不会显示任何头像或图片；
	# add_fusion_follower() 绑定的 Node2D.tscn 仍会读取它的逐帧 frame。
	if str(resource_id) == FOLLOWER_RESOURCE_ID:
		return

	push_warning("未处理的 VAPX 图片资源 srcId=" + str(resource_id))


func _save_screenshot():
	yield(VisualServer, "frame_post_draw")
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	var error = image.save_png(screenshot_path)
	print("VAP_SCREENSHOT_SAVED path=", screenshot_path, " error=", error, " frame=", vap.current_frame)
	if OS.get_environment("VAP_AUTO_QUIT") == "1":
		get_tree().quit(error)
