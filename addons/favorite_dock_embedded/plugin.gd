@tool
extends EditorPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	https://github.com/CodeNameTwister/Favorite-Dock-Embedded
#
#	Favorite-Dock-Embedded addon for godot 4
#	author:		"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

const WAIT_TIME_TO_REPLICATE_COLORS : float = 1.25 # Seconds
const REPLICATE_COLORS_TIMES : int = 0 # Times repeat to secure recplitae colors

var fav_tree : Tree = null
var finish_update : bool = true

var _col_cache : Dictionary = {}

var _current_replicate_times : int = 0
var _require_update : bool = true:
	set(e):
		if e:
			_current_replicate_times = REPLICATE_COLORS_TIMES
		_require_update = e
var _chk : float = 0.0
var _hook_item : TreeItem = null

func _enter_tree() -> void:
	var dock := EditorInterface.get_file_system_dock()
	var fsystem := EditorInterface.get_resource_filesystem()
	_n(dock)
	if !fav_tree:
		push_error("[ERROR] Can not find favorites tree!")
		return

	_update.call_deferred()

	fsystem.filesystem_changed.connect(_def_update)
	dock.folder_color_changed.connect(_def_update)
	dock.files_moved.connect(_moved_callback)
	dock.file_removed.connect(_remove_callback)
	dock.folder_moved.connect(_moved_callback)
	dock.folder_removed.connect(_remove_callback)

	var vp : Viewport = Engine.get_main_loop().root
	vp.focus_entered.connect(_on_wnd)
	vp.focus_exited.connect(_out_wnd)

func _on_wnd() -> void:set_physics_process(true)
func _out_wnd() -> void:set_physics_process(false)

func _exit_tree() -> void:
	var dock := EditorInterface.get_file_system_dock()
	var fsystem := EditorInterface.get_resource_filesystem()
	var vp : Viewport = Engine.get_main_loop().root
	if fsystem.filesystem_changed.is_connected(_def_update):
		fsystem.filesystem_changed.disconnect(_def_update)
	if dock.folder_color_changed.is_connected(_def_update):
		dock.folder_color_changed.disconnect(_def_update)
	if dock.files_moved.is_connected(_moved_callback):
		dock.files_moved.disconnect(_moved_callback)
	if dock.file_removed.is_connected(_remove_callback):
		dock.file_removed.disconnect(_remove_callback)
	if dock.folder_moved.is_connected(_moved_callback):
		dock.folder_moved.disconnect(_moved_callback)
	if dock.folder_removed.is_connected(_remove_callback):
		dock.folder_removed.disconnect(_remove_callback)
	if dock.folder_color_changed.is_connected(_def_update):
		dock.folder_color_changed.disconnect(_def_update)
	if fav_tree.item_collapsed.is_connected(_on_collap):
		fav_tree.item_collapsed.disconnect(_on_collap)
	if vp.focus_entered.is_connected(_on_wnd):
		vp.focus_entered.disconnect(_on_wnd)
	if vp.focus_exited.is_connected(_out_wnd):
		vp.focus_exited.disconnect(_out_wnd)
	_col_cache.clear()

func _def_update() -> void:
	if !is_instance_valid(_hook_item):
		_update.call()
	_require_update = true

## Tree callback
func _on_collap(i : TreeItem) -> void:
	const RES : String = "res://"
	var v : Variant = i.get_metadata(0)
	if v is String:
		if v.is_empty():return
		if _col_cache.has(v):
			var parent : TreeItem = i.get_parent()
			while null != parent:
				if parent.get_metadata(0) == RES:
					return
				parent = parent.get_parent()
			_col_cache[v][1] = i.collapsed

## Refresh dock
func _update(only_colors : bool = false) -> void:
	var root : TreeItem = fav_tree.get_root()
	if !fav_tree.item_collapsed.is_connected(_on_collap):
		fav_tree.item_collapsed.connect(_on_collap)
	if root != null and root.get_first_child() != null:
		_explorer(fav_tree, only_colors)
		for x : String in _col_cache.keys():
			if _col_cache[x][0] == false:
				_col_cache.erase(x)

func _map(from : TreeItem, to : TreeItem, only_colors : bool = false) -> void:
	if from == null:return
	var meta_data : String = str(from.get_metadata(0))
	to.set_metadata(0, meta_data)
	to.set_icon(0, from.get_icon(0))
	to.set_icon_modulate(0, from.get_icon_modulate(0))
	#to.set_custom_color(0, from.get_custom_color(0))
	if from.get_custom_bg_color(0) == Color.BLACK:
		to.clear_custom_bg_color(0)
	else:
		to.set_custom_bg_color(0, from.get_custom_bg_color(0))
	to.set_text(0, from.get_text(0))

	if !_col_cache.has(meta_data):
		_col_cache[meta_data] = [true, true]
	_col_cache[meta_data][0] = true
	to.collapsed = _col_cache[meta_data][1]

	if only_colors:
		var from_current : TreeItem = from.get_first_child()
		var to_current : TreeItem = to.get_first_child()
		while null != from_current and null != to_current:
			_map(from_current, to_current, only_colors)
			from_current = from_current.get_next()
			to_current = to_current.get_next()
	else:
		var from_current : TreeItem = from.get_first_child()
		while null != from_current:
			_map(from_current, to.create_child(), only_colors)
			from_current = from_current.get_next()


func _explorer(current_tree : Tree, only_colors: bool) -> void:
	const MAX_TREE : int = 2000
	var itry : int = 0
	var root : TreeItem = current_tree.get_root()
	var fav : TreeItem = null
	var res : TreeItem = null
	var current : TreeItem = root.get_first_child()

	while null != current:
		var variant : Variant = current.get_metadata(0)
		if variant is String:
			if variant == "Favorites":
				fav = current
				if res and fav:break
			elif variant == "res://":
				res = current
				if res and fav:break
		current = current.get_next()
	if fav and res:
		_hook_item = fav
		current = fav.get_first_child()

		while null != current:
			var variant : Variant = current.get_metadata(0)
			if variant is String:
				var res_current : TreeItem = res.get_first_child()
				while null != res_current:
					var sub_variant : Variant = res_current.get_metadata(0)
					if sub_variant is String:
						if sub_variant == variant:
							_map(res_current, current, only_colors)
							break
						if variant.begins_with(sub_variant):
							itry += 1
							if itry > MAX_TREE:
								push_warning("[PLUGIN] Error, elements overflow!")
								break
							res_current = res_current.get_first_child()
							continue
					res_current = res_current.get_next()
			current = current.get_next()

func _moved_callback(a : String, b : String) -> void:
	if a != b:
		if _col_cache.has(a):
			_col_cache[b] = _col_cache[a]
			_col_cache.erase(a)

func _remove_callback(a : String) -> void:
	if _col_cache.has(a):
		_col_cache.erase(a)

func _save_external_data() -> void:
	_require_update = true

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
	if !is_instance_valid(_hook_item):
		_require_update = true
		_chk = 0.0
		_update.call()
	if _require_update:
		_chk += _delta
		if _chk < WAIT_TIME_TO_REPLICATE_COLORS:return
		if _current_replicate_times > 0:
			_current_replicate_times -= 1
		else:
			_require_update = false
		_chk = 0.0
		_update.call(true)
