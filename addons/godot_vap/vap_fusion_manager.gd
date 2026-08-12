extends Control

signal resource_request(resource_id, resource_type, resource_config)
signal resource_ready(resource_id)
signal fusion_error(error_message)

const FUSION_SHADER = preload("res://addons/godot_vap/shaders/vap_fusion_mask.shader")

var player = null
var video_info = {}
var resource_configs = {}
var frame_map = {}
var loaded_textures = {}
var fusion_elements = {}
var _resource_versions = {}
var _current_frame = 0
var _is_fusion = false
var _generation = 0


func _ready():
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(vap_config, backend):
	clear()
	player = backend
	video_info = vap_config.get("info", {})
	_is_fusion = int(video_info.get("isVapx", 0)) == 1
	visible = _is_fusion
	if not _is_fusion:
		return true
	if typeof(vap_config.get("src", [])) != TYPE_ARRAY or typeof(vap_config.get("frame", [])) != TYPE_ARRAY:
		return _fail("VAPX config requires src and frame arrays")

	for source in vap_config["src"]:
		if not _valid_source(source):
			return false
		resource_configs[str(source["srcId"])] = source.duplicate(true)

	for frame_set in vap_config["frame"]:
		if typeof(frame_set) != TYPE_DICTIONARY or not frame_set.has("i") or typeof(frame_set.get("obj", [])) != TYPE_ARRAY:
			return _fail("Invalid VAPX frame entry")
		var objects = frame_set["obj"].duplicate(true)
		for object in objects:
			if not _valid_frame_object(object):
				return false
		objects.sort_custom(self, "_sort_by_z")
		frame_map[int(frame_set["i"])] = objects

	for resource_id in resource_configs:
		var source = resource_configs[resource_id]
		emit_signal("resource_request", resource_id, str(source["srcType"]), source.duplicate(true))
	return true


func _sort_by_z(a, b):
	return int(a.get("z", 0)) < int(b.get("z", 0))


func set_resource(resource_id, resource_data):
	resource_id = str(resource_id)
	if not resource_configs.has(resource_id):
		return _fail("Unknown VAPX resource: " + resource_id)
	var source = resource_configs[resource_id]
	var source_type = str(source["srcType"])
	_resource_versions[resource_id] = int(_resource_versions.get(resource_id, 0)) + 1
	var version = int(_resource_versions[resource_id])
	var generation = _generation

	if source_type == "txt":
		if typeof(resource_data) != TYPE_STRING:
			return _fail("VAPX text resource must be a String: " + resource_id)
		_render_text_resource(resource_id, resource_data, source, version, generation)
		return true

	var texture = null
	if resource_data is Texture:
		texture = resource_data
	elif resource_data is Image:
		texture = ImageTexture.new()
		texture.create_from_image(resource_data, 0)
	else:
		return _fail("VAPX image resource must be a Texture or Image: " + resource_id)
	_install_texture(resource_id, texture, version, generation)
	return true


func present_frame(frame_number):
	_current_frame = frame_number
	for element in fusion_elements.values():
		if is_instance_valid(element):
			element.visible = false
	if not _is_fusion or not frame_map.has(frame_number):
		return
	for object in frame_map[frame_number]:
		var resource_id = str(object["srcId"])
		if not loaded_textures.has(resource_id):
			continue
		var element = _ensure_element(resource_id)
		_apply_frame_object(element, object, resource_configs[resource_id])


func bind_video_texture():
	for element in fusion_elements.values():
		_bind_mask_texture(element)
	present_frame(_current_frame)


func clear():
	_generation += 1
	for element in fusion_elements.values():
		if is_instance_valid(element):
			element.queue_free()
	resource_configs.clear()
	frame_map.clear()
	loaded_textures.clear()
	fusion_elements.clear()
	_resource_versions.clear()
	_current_frame = 0
	_is_fusion = false


func get_source_config(resource_id):
	return resource_configs.get(str(resource_id), {}).duplicate(true)


func _valid_source(source):
	if typeof(source) != TYPE_DICTIONARY:
		return _fail("VAPX src entry must be an object")
	for key in ["srcId", "srcType", "w", "h"]:
		if not source.has(key):
			return _fail("VAPX src entry is missing " + key)
	var source_id = str(source["srcId"])
	if source_id.empty():
		return _fail("VAPX srcId cannot be empty")
	if resource_configs.has(source_id):
		return _fail("Duplicate VAPX srcId: " + source_id)
	if not str(source["srcType"]) in ["img", "txt"]:
		return _fail("Unsupported VAPX srcType: " + str(source["srcType"]))
	if int(source["w"]) <= 0 or int(source["h"]) <= 0:
		return _fail("VAPX source dimensions must be positive: " + source_id)
	return true


func _valid_frame_object(object):
	if typeof(object) != TYPE_DICTIONARY:
		return _fail("VAPX frame object must be an object")
	for key in ["srcId", "frame", "mFrame"]:
		if not object.has(key):
			return _fail("VAPX frame object is missing " + key)
	if not resource_configs.has(str(object["srcId"])):
		return _fail("VAPX frame references unknown srcId: " + str(object["srcId"]))
	if not _valid_rect(object["frame"]) or not _valid_rect(object["mFrame"]):
		return _fail("VAPX frame or mFrame is invalid")
	if not int(object.get("mt", 0)) in [0, 90]:
		return _fail("VAPX mt only supports 0 or 90 degrees")
	return true


func _valid_rect(value):
	return typeof(value) == TYPE_ARRAY and value.size() == 4 and int(value[2]) > 0 and int(value[3]) > 0


func _render_text_resource(resource_id, text, source, version, generation):
	var width = max(1, int(source["w"]))
	var height = max(1, int(source["h"]))
	var viewport = Viewport.new()
	viewport.size = Vector2(width, height)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	add_child(viewport)

	var font_scale = max(1.0, float(height) / 24.0)
	var label = Label.new()
	label.text = text
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.clip_text = true
	label.rect_size = Vector2(width, height) / font_scale
	label.rect_scale = Vector2(font_scale, font_scale)
	label.add_color_override("font_color", Color(1, 1, 1, 1))
	viewport.add_child(label)

	yield(get_tree(), "idle_frame")
	yield(VisualServer, "frame_post_draw")
	var image = viewport.get_texture().get_data()
	image.flip_y()
	viewport.queue_free()
	if image.is_empty():
		_fail("Failed to render VAPX text texture: " + resource_id)
		return
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	_install_texture(resource_id, texture, version, generation)


func _install_texture(resource_id, texture, version, generation):
	if generation != _generation or version != int(_resource_versions.get(resource_id, -1)):
		return
	loaded_textures[resource_id] = texture
	var element = _ensure_element(resource_id)
	element.texture = texture
	_configure_fit(element, resource_configs[resource_id])
	_bind_mask_texture(element)
	emit_signal("resource_ready", resource_id)
	present_frame(_current_frame)


func _ensure_element(resource_id):
	if fusion_elements.has(resource_id) and is_instance_valid(fusion_elements[resource_id]):
		return fusion_elements[resource_id]
	var element = TextureRect.new()
	element.name = "fusion_" + resource_id.replace("/", "_").replace(":", "_")
	element.expand = true
	element.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = FUSION_SHADER
	element.material = material
	add_child(element)
	fusion_elements[resource_id] = element
	return element


func _configure_fit(element, source):
	if str(source.get("fitType", "fitXY")) == "centerFull":
		element.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		element.stretch_mode = TextureRect.STRETCH_SCALE


func _apply_frame_object(element, object, source):
	var frame = object["frame"]
	var mask_frame = object["mFrame"]
	var content_rect = player.get_content_display_rect()
	var scale = content_rect.size.x / float(video_info["w"])
	element.rect_position = content_rect.position + Vector2(float(frame[0]), float(frame[1])) * scale
	element.rect_size = Vector2(float(frame[2]), float(frame[3])) * scale
	element.set("z_index", int(object.get("z", 0)))
	element.visible = true
	var material = element.material
	material.set_shader_param("mask_region", Color(
		float(mask_frame[0]) / float(video_info["videoW"]),
		float(mask_frame[1]) / float(video_info["videoH"]),
		float(mask_frame[2]) / float(video_info["videoW"]),
		float(mask_frame[3]) / float(video_info["videoH"])
	))
	material.set_shader_param("mask_rotation", int(object.get("mt", 0)))
	material.set_shader_param("use_fill", str(source["srcType"]) == "txt")
	material.set_shader_param("fill_color", _parse_color(source.get("color", "#FFFFFF")))
	_bind_mask_texture(element)


func _bind_mask_texture(element):
	if player == null or player.get_video_texture() == null:
		return
	element.material.set_shader_param("mask_texture", player.get_video_texture())


func _parse_color(value):
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING and Color(value).to_html() != "":
		return Color(value)
	return Color(1, 1, 1, 1)


func _fail(message):
	emit_signal("fusion_error", message)
	return false
