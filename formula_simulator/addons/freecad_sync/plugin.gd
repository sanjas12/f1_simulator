@tool
extends EditorPlugin

const SOURCE: String = "../assets/cad/prototype_02/Formula_Prototype_02.FCStd"
const PYTHON_SETTING: String = "freecad_sync/python_executable"
var timer: Timer
var last_hash: String = ""
var candidate_hash: String = ""
var pending_hash: String = ""
var process_id: int = -1


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(PYTHON_SETTING):
		ProjectSettings.set_setting(PYTHON_SETTING, "C:/Program Files/FreeCAD 1.1/bin/python.exe")
	add_tool_menu_item("Update FreeCAD model", _force_update)
	timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_check_source)
	add_child(timer)
	timer.start()


func _exit_tree() -> void:
	remove_tool_menu_item("Update FreeCAD model")
	if is_instance_valid(timer):
		timer.queue_free()


func _force_update() -> void:
	last_hash = ""
	candidate_hash = ""


func _check_source() -> void:
	var status_path: String = ProjectSettings.globalize_path("res://.godot/freecad_sync.json")
	if process_id != -1:
		if OS.is_process_running(process_id):
			return
		process_id = -1
		var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(status_path))
		if result is Dictionary and result.get("ok", false):
			print("FreeCAD Sync: model updated (", result.get("parts"), " parts).")
			EditorInterface.get_resource_filesystem().scan()
		else:
			push_warning("FreeCAD Sync failed. Previous model retained. See .godot/freecad_sync.json; retry via Project > Tools > Update FreeCAD model.")
		last_hash = pending_hash
	var source_path: String = ProjectSettings.globalize_path("res://").path_join(SOURCE).simplify_path()
	if not FileAccess.file_exists(source_path):
		return
	var current_hash: String = FileAccess.get_sha256(source_path)
	if current_hash == last_hash:
		return
	# Two matching observations avoid reading an unfinished save.
	if current_hash != candidate_hash:
		candidate_hash = current_hash
		return
	var python: String = ProjectSettings.get_setting(PYTHON_SETTING)
	if not FileAccess.file_exists(python):
		last_hash = current_hash
		push_warning("Set freecad_sync/python_executable to FreeCAD's bundled python.exe.")
		return
	var exporter: String = ProjectSettings.globalize_path("res://../tools/export_freecad.py")
	var status_file: FileAccess = FileAccess.open(status_path, FileAccess.WRITE)
	status_file.store_string("{}")
	status_file.close()
	pending_hash = current_hash
	process_id = OS.create_process(python, [exporter, "--status", status_path])
	if process_id == -1:
		last_hash = current_hash
		push_warning("Could not start FreeCAD exporter.")
