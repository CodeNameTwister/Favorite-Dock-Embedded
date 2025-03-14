@tool
extends EditorPlugin
#{
	#"type": "plugin",
	#"codeRepository": "https://github.com/CodeNameTwister",
	#"description": "Favorite dock embedded addon for godot 4",
	#"license": "https://spdx.org/licenses/MIT",
	#"name": "Twister",
	#"version": "1.0.0"
#}
var fav_tree : Tree = null
var finish_update : bool = true
var _SHA256 : String = ""
var _chk : float = 0.0

const FAV_FOLDER : String = "res://.godot/editor/favorites"

func _enter_tree() -> void:

	var dock := EditorInterface.get_file_system_dock()
	var fsystem := EditorInterface.get_resource_filesystem()
	_n(dock)
	if !fav_tree:
		push_error("[ERROR] Can not find favorites tree!")
		return

	_update()

	fsystem.filesystem_changed.connect(_def_update)
	dock.folder_color_changed.connect(_def_update)

func _exit_tree() -> void:
	var dock := EditorInterface.get_file_system_dock()
	var fsystem := EditorInterface.get_resource_filesystem()
	if fsystem.filesystem_changed.is_connected(_def_update):
		fsystem.filesystem_changed.disconnect(_def_update)
	if dock.folder_color_changed.is_connected(_def_update):
		dock.folder_color_changed.disconnect(_def_update)

func _def_update() -> void:
	_update.call_deferred(true)

## Refresh dock
func _update(force : bool = false) -> void:
	if !finish_update:return
	finish_update = false
	if FileAccess.file_exists(FAV_FOLDER):
		var n_SHA256 : String = FileAccess.get_sha256(FAV_FOLDER)
		if _SHA256 != n_SHA256 or force == true:
			_SHA256 = n_SHA256
			var root : TreeItem = fav_tree.get_root()
			if root != null and root.get_first_child() != null:
				_c(root.get_first_child().get_first_child())
	finish_update = true

## Add recursive folders/files
func _explorer(path : String, tree : TreeItem, data : Dictionary, base_color : Color = Color.SKY_BLUE) -> void:
	var efs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	var fs : EditorFileSystemDirectory = efs.get_filesystem_path(path)
	if !fs:return

	if base_color != Color.SKY_BLUE:
		base_color.a = max(base_color.a  - 0.15, 0.05)
	for x : int in fs.get_subdir_count():
		var new_path : String = fs.get_subdir(x).get_path()
		var new_tree : TreeItem = tree.create_child()
		var fname : String = new_path.trim_suffix("/").get_file()
		new_tree.set_text(0, fname)
		#root.set_text(0, "res://")
		new_tree.set_metadata(0, new_path)
		new_tree.set_icon(0, _get_icon(new_path))
		new_tree.set_custom_bg_color(0, base_color)
		#root.set_icon_modulate(0, Color.SKY_BLUE)
		var current_color : Color = base_color
		if data.has(new_path):
			current_color = Color.from_string(data[new_path], Color.SKY_BLUE)
			if current_color != Color.SKY_BLUE:
				var nw : Color = current_color.lightened(0.25)
				nw.a = 0.85
				new_tree.set_icon_modulate(0, current_color)
		else:
			var b : Color = base_color
			b.a = 1.0
			new_tree.set_icon_modulate(0, b)
		current_color.a = min(current_color.a, 0.25)
		_explorer(new_path, new_tree, data, current_color)
	for x : int in fs.get_file_count():
		var current_color : Color = base_color
		var new_path : String = fs.get_file_path(x)
		var new_tree : TreeItem = tree.create_child()
		var fname : String = new_path.trim_suffix("/").get_file()
		new_tree.set_text(0, fname)
		new_tree.set_metadata(0, new_path)
		new_tree.set_icon(0, _get_icon(new_path))
		if data.has(new_path):
			current_color = Color.from_string(data[new_path], Color.SKY_BLUE)
			if current_color != Color.SKY_BLUE:
				current_color = current_color.lightened(0.25)

		current_color.a = min(current_color.a, 0.25)
		new_tree.set_custom_bg_color(0, current_color)

#region rescue_fav
func _n(n : Node) -> bool:
	if n is Tree:
		var t : TreeItem = (n.get_root())
		if null != t:
			t = t.get_first_child()
			if null != t:
				var txt : String = (t.get_text(0)).to_lower()
				if "fav" in txt or txt.ends_with(":") or txt.begins_with(":"):
					fav_tree = n
					return true
	for x in n.get_children():
		if _n(x): return true
	return false

func _c(i : TreeItem) -> void:
	if i == null : return
	var d : String = str(i.get_metadata(0))
	if FileAccess.file_exists(d) or DirAccess.dir_exists_absolute(d):
		var data : Dictionary = ProjectSettings.get_setting("file_customization/folder_colors",{})
		var color : Color = Color.SKY_BLUE
		if data.has(d):
			color = Color.from_string(data[d], Color.SKY_BLUE)
			#if color != Color.SKY_BLUE:
		color.a = 0.25
		_explorer(d, i, data, color)
	var n : TreeItem = i.get_next()
	if n != null:
		_c(n)
#endregion


## Get icon type using path as reference
func _get_icon(path : String) -> Texture:
	var base_gui : Control = EditorInterface.get_base_control()
	var editor : EditorFileSystem = EditorInterface.get_resource_filesystem()

	if path == "":
		return base_gui.get_theme_icon("Load", "EditorIcons")

	var ticon : StringName = editor.get_file_type(path)
	var load_icon :  Texture2D = base_gui.get_theme_icon("", "EditorIcons")
	var default_icon : Texture2D = load_icon
	load_icon = base_gui.get_theme_icon(ticon, "EditorIcons")
	if load_icon == default_icon:
		if path.get_extension() == "":
			if !path.ends_with("."):
				load_icon = base_gui.get_theme_icon("Folder", "EditorIcons")
		elif ticon.ends_with("s"):
			load_icon = base_gui.get_theme_icon(ticon.trim_suffix("s"), "EditorIcons")
		if load_icon == default_icon:
			return base_gui.get_theme_icon("File", "EditorIcons")
	return load_icon

func _physics_process(_delta: float) -> void:
	_chk += _delta
	if _chk < 0.35:return
	_chk = 0.0
	var n_SHA256 : String = FileAccess.get_sha256(FAV_FOLDER)
	if _SHA256 != n_SHA256:
		_update(true)
