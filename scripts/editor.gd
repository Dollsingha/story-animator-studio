extends Control

const StageScript = preload("res://scripts/stage.gd")
const ProjectStorage = preload("res://scripts/project_storage.gd")
var stage: StageScript
var objects: Array = []
var selected := -1
var duration := 12.0
var current_time := 0.0
var playing := false
var refreshing := false
var drag_transaction := false
var undo_stack: Array = []
var redo_stack: Array = []
var project_path := ""
var timeline: HSlider
var time_label: Label
var object_list: ItemList
var status: Label
var rotation_input: SpinBox
var scale_input: SpinBox
var opacity_input: SpinBox
var pivot_x_input: SpinBox
var pivot_y_input: SpinBox
var name_input: LineEdit
var parent_input: OptionButton
var duration_input: SpinBox
var markers: HBoxContainer
var import_dialog: FileDialog
var save_dialog: FileDialog
var open_dialog: FileDialog
var grid_toggle: CheckButton
var background_path := ""
var background_dialog: FileDialog
var path_mode := false
var path_points: Array = []

func _ready() -> void:
    _apply_theme()
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 5)
    add_child(root)
    _build_header(root)
    _build_workspace(root)
    _build_timeline(root)
    _setup_dialogs()
    _bind_shortcuts()
    _sync()
    _set_status("Import artwork or add a shape. Select an object, move the playhead, then record a pose.")

func _apply_theme() -> void:
    var editor_theme := Theme.new()
    editor_theme.set_color("font_color", "Label", Color("#dbe6f1"))
    editor_theme.set_color("font_color", "Button", Color("#e5edf7"))
    editor_theme.set_color("font_color", "CheckButton", Color("#e5edf7"))
    editor_theme.set_color("font_color", "LineEdit", Color("#e5edf7"))
    editor_theme.set_color("font_color", "SpinBox", Color("#e5edf7"))
    editor_theme.set_color("font_color", "OptionButton", Color("#e5edf7"))
    self.theme = editor_theme
    var bg := ColorRect.new()
    bg.color = Color("#171d28")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

func _label(parent: Node, content: String) -> Label:
    var l := Label.new()
    l.text = content
    parent.add_child(l)
    return l

func _button(parent: Node, caption: String, callback: Callable, tooltip: String = "") -> Button:
    var b := Button.new()
    b.text = caption
    b.tooltip_text = tooltip
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func _build_header(root: VBoxContainer) -> void:
    var header_scroll := ScrollContainer.new()
    header_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(header_scroll)
    var header := HBoxContainer.new()
    header_scroll.add_child(header)
    var brand := _label(header, "  STORY ANIMATOR STUDIO  |  P1 Rebuilt  ")
    brand.add_theme_color_override("font_color", Color("#78d6e6"))
    _button(header, "Import", _import_image, "Import PNG/JPG/WebP image")
    _button(header, "Set Scenery", _import_background, "Use your own image as the fixed scene background")
    _button(header, "Clear Scenery", _clear_background)
    _button(header, "Draw Route", _start_path, "Click points on the stage; press Finish Route")
    _button(header, "Finish Route", _finish_path, "Create movement keys for the selected object")
    _button(header, "Offline Demo", _load_offline_demo, "Load a car with passengers and a boat on the river")
    _button(header, "+ Shape", _add_shape)
    _button(header, "Duplicate", _duplicate_object, "Ctrl+D")
    _button(header, "Delete", _delete_object, "Delete")
    _button(header, "Undo", _undo, "Ctrl+Z")
    _button(header, "Redo", _redo, "Ctrl+Y")
    _button(header, "Save", _save_project, "Ctrl+S")
    _button(header, "Open", _open_project, "Ctrl+O")
    _button(header, "New", _new_project)

func _build_workspace(root: VBoxContainer) -> void:
    var middle := HSplitContainer.new()
    middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(middle)
    var left := VBoxContainer.new()
    left.custom_minimum_size.x = 205
    middle.add_child(left)
    _label(left, "  SCENE OBJECTS  (back → front)")
    object_list = ItemList.new()
    object_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    object_list.item_selected.connect(func(i): _select(int(i)))
    left.add_child(object_list)
    _button(left, "↑ Move forward", func(): _reorder(1))
    _button(left, "↓ Move backward", func(): _reorder(-1))
    _button(left, "Show / Hide", _toggle_visibility)
    _button(left, "Lock / Unlock", _toggle_lock)
    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    middle.add_child(center)
    var canvas_header := HBoxContainer.new()
    center.add_child(canvas_header)
    _label(canvas_header, "  STAGE  960 × 540  |  Drag to move  ")
    grid_toggle = CheckButton.new()
    grid_toggle.text = "Grid"
    grid_toggle.button_pressed = true
    grid_toggle.toggled.connect(func(v): stage.show_grid = v; stage.queue_redraw())
    canvas_header.add_child(grid_toggle)
    stage = StageScript.new()
    stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stage.custom_minimum_size = Vector2(300, 230)
    stage.mouse_filter = Control.MOUSE_FILTER_STOP
    center.add_child(stage)
    stage.object_selected.connect(_select)
    stage.path_point_added.connect(_path_point_added)
    stage.object_moved.connect(_on_moved)
    stage.drag_finished.connect(func(): drag_transaction = false; _refresh_markers())
    var inspector_scroll := ScrollContainer.new()
    inspector_scroll.custom_minimum_size.x = 220
    inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    middle.add_child(inspector_scroll)
    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inspector_scroll.add_child(right)
    _label(right, "  INSPECTOR")
    _label(right, "Name")
    name_input = LineEdit.new()
    name_input.text_submitted.connect(_rename)
    name_input.focus_exited.connect(func(): _rename(name_input.text))
    right.add_child(name_input)
    _label(right, "Rotation (degrees)")
    rotation_input = _spin(right, -720, 720, 1, 0, _rotation_changed)
    _label(right, "Scale")
    scale_input = _spin(right, 0.05, 10, 0.05, 1, _scale_changed)
    _label(right, "Opacity")
    opacity_input = _spin(right, 0, 1, 0.05, 1, _opacity_changed)
    _label(right, "Pivot offset X / Y (part joints)")
    pivot_x_input = _spin(right, -500, 500, 1, 0, func(v): _pivot_changed("pivot_x", v))
    pivot_y_input = _spin(right, -500, 500, 1, 0, func(v): _pivot_changed("pivot_y", v))
    _label(right, "Attach to (puppet parent)")
    parent_input = OptionButton.new()
    parent_input.item_selected.connect(_change_parent)
    right.add_child(parent_input)
    _button(right, "◆ Record Pose", _add_keyframe, "K")
    _button(right, "Remove Key at Playhead", _remove_keyframe)
    _button(right, "Apply Sway / Wave", _preset_wave, "Creates rotation keys for the selected part")
    _button(right, "Apply Walk Path", _preset_walk, "Creates horizontal movement keys")
    var help := _label(right, "TIP: Import body parts separately.\nAttach arms to a torso using\n'Attach to', then animate rotation.\n\nSelect a part to see its keyframes.")
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _spin(parent: Node, minimum: float, maximum: float, step: float, initial: float, callback: Callable) -> SpinBox:
    var s := SpinBox.new()
    s.min_value = minimum
    s.max_value = maximum
    s.step = step
    s.value = initial
    s.value_changed.connect(callback)
    parent.add_child(s)
    return s

func _build_timeline(root: VBoxContainer) -> void:
    var bottom := VBoxContainer.new()
    root.add_child(bottom)
    var controls := HBoxContainer.new()
    bottom.add_child(controls)
    _button(controls, "▶ Play / Pause", _toggle_play, "Space")
    _button(controls, "■ Stop", _stop)
    _button(controls, "◀ 1 frame", func(): _seek(maxf(0.0, current_time - 1.0 / 24.0)))
    _button(controls, "1 frame ▶", func(): _seek(minf(duration, current_time + 1.0 / 24.0)))
    time_label = _label(controls, "0.00 / 12.00 s")
    _label(controls, "   Duration:")
    duration_input = _spin(controls, 1, 300, 1, duration, _set_duration)
    timeline = HSlider.new()
    timeline.min_value = 0
    timeline.max_value = duration
    timeline.step = 1.0 / 24.0
    timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    timeline.value_changed.connect(_seek)
    bottom.add_child(timeline)
    var row := HBoxContainer.new()
    bottom.add_child(row)
    _label(row, "  KEYFRAMES  ")
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 34
    row.add_child(scroll)
    markers = HBoxContainer.new()
    scroll.add_child(markers)
    status = _label(bottom, "Ready")
    status.clip_text = true

func _setup_dialogs() -> void:
    import_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE, "*.png, *.jpg, *.jpeg, *.webp", "Images", _image_selected)
    background_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE, "*.png, *.jpg, *.jpeg, *.webp", "Scenery", _background_selected)
    save_dialog = _dialog(FileDialog.FILE_MODE_SAVE_FILE, "*.json", "Story Animator Project", _write_project)
    open_dialog = _dialog(FileDialog.FILE_MODE_OPEN_FILE, "*.json", "Story Animator Project", _read_project)

func _dialog(mode: FileDialog.FileMode, filter: String, description: String, callback: Callable) -> FileDialog:
    var d := FileDialog.new()
    d.file_mode = mode
    d.access = FileDialog.ACCESS_FILESYSTEM
    d.add_filter(filter, description)
    d.file_selected.connect(callback)
    add_child(d)
    return d

func _bind_shortcuts() -> void:
    set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    if get_viewport().gui_get_focus_owner() is LineEdit: return
    if event.ctrl_pressed:
        match event.keycode:
            KEY_S: _save_project(); get_viewport().set_input_as_handled()
            KEY_O: _open_project(); get_viewport().set_input_as_handled()
            KEY_Z: _undo(); get_viewport().set_input_as_handled()
            KEY_Y: _redo(); get_viewport().set_input_as_handled()
            KEY_D: _duplicate_object(); get_viewport().set_input_as_handled()
    else:
        match event.keycode:
            KEY_SPACE: _toggle_play(); get_viewport().set_input_as_handled()
            KEY_K: _add_keyframe(); get_viewport().set_input_as_handled()
            KEY_DELETE: _delete_object(); get_viewport().set_input_as_handled()

func _snapshot() -> Dictionary:
    return {"objects": objects.duplicate(true), "duration": duration, "selected": selected, "background_path": background_path}

func _checkpoint() -> void:
    undo_stack.append(_snapshot())
    if undo_stack.size() > 80: undo_stack.pop_front()
    redo_stack.clear()

func _restore(snapshot: Dictionary) -> void:
    objects = snapshot["objects"].duplicate(true)
    background_path = str(snapshot.get("background_path", ""))
    stage.background_path = background_path
    selected = int(snapshot["selected"])
    duration = float(snapshot["duration"])
    _cancel_interaction()
    current_time = minf(current_time, duration)
    refreshing = true
    duration_input.value = duration
    timeline.max_value = duration
    refreshing = false
    _sync()
    _select(selected)

func _undo() -> void:
    if undo_stack.is_empty(): return
    redo_stack.append(_snapshot())
    _restore(undo_stack.pop_back())
    _set_status("Undo")

func _redo() -> void:
    if redo_stack.is_empty(): return
    undo_stack.append(_snapshot())
    _restore(redo_stack.pop_back())
    _set_status("Redo")

func _load_offline_demo() -> void:
    if not _read_project("res://examples/Offline_Smart_Objects.json"): return
    _set_status("Offline demo loaded: press Play; inspect car and boat parent-child attachments")

func _import_image() -> void: import_dialog.popup_centered_ratio(0.75)
func _import_background() -> void: background_dialog.popup_centered_ratio(0.75)
func _background_selected(path: String) -> void:
    _checkpoint()
    background_path = path
    stage.background_path = path
    stage.queue_redraw()
    _set_status("Scenery loaded. Add objects over it or select one and Draw Route.")
func _clear_background() -> void:
    _checkpoint()
    background_path = ""
    stage.background_path = ""
    stage.queue_redraw()
func _start_path() -> void:
    if selected < 0:
        _set_status("Select a character, car, animal or boat before drawing its route")
        return
    path_mode = true
    path_points.clear()
    stage.path_mode = true
    stage.path_points = path_points
    stage.queue_redraw()
    _set_status("Route mode: click stage to add points, then click Finish Route")
func _path_point_added(point: Vector2) -> void:
    path_points.append([point.x, point.y])
    stage.path_points = path_points
    stage.queue_redraw()
func _finish_path() -> void:
    path_mode = false
    stage.path_mode = false
    if selected < 0 or path_points.size() < 2:
        stage.path_points = []
        _set_status("Route needs at least two points")
        return
    _checkpoint()
    var obj: Dictionary = objects[selected]
    var lengths: Array = [0.0]
    for i in range(1, path_points.size()):
        var a := Vector2(float(path_points[i - 1][0]), float(path_points[i - 1][1]))
        var b := Vector2(float(path_points[i][0]), float(path_points[i][1]))
        lengths.append(float(lengths[-1]) + a.distance_to(b))
    var total: float = maxf(float(lengths[-1]), 0.001)
    var span: float = minf(4.0, duration - current_time)
    if span <= 0.0:
        stage.path_points = []
        path_points.clear()
        stage.queue_redraw()
        _set_status("Move the playhead before the end to create a route")
        return
    for i in range(path_points.size()):
        var t: float = current_time + span * float(lengths[i]) / total
        var p: Dictionary = stage.interpolated(obj, t)
        var world := Vector2(float(path_points[i][0]), float(path_points[i][1]))
        var local := stage.to_local_position(selected, world, t)
        p["x"] = local.x
        p["y"] = local.y
        p["time"] = t
        _replace_key(obj, p)
    obj["easing"] = "Linear"
    obj["route"] = path_points.duplicate(true)
    stage.path_points = []
    path_points.clear()
    _sync()
    _set_status("Offline route applied as %d keyframes. Play to preview." % lengths.size())
func _save_project() -> void:
    if project_path.is_empty() or project_path.begins_with("res://"):
        save_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
        save_dialog.popup_centered_ratio(0.75)
    else: _write_project(project_path)
func _open_project() -> void: open_dialog.popup_centered_ratio(0.75)

func _image_selected(path: String) -> void:
    _add_object(path.get_file().get_basename(), path)

func _add_shape() -> void:
    _add_object("Shape %d" % (objects.size() + 1), "")

func _add_object(name: String, path: String) -> void:
    _checkpoint()
    objects.append({"name": name, "path": path, "x": 480.0, "y": 270.0, "rotation": 0.0, "scale": 1.0, "opacity": 1.0, "pivot_x": 0.0, "pivot_y": 0.0, "parent": -1, "visible": true, "locked": false, "easing": "Smooth", "keys": []})
    selected = objects.size() - 1
    _sync()
    _select(selected)
    _set_status("Added %s. Move it, select a time, then Record Pose." % name)

func _duplicate_object() -> void:
    if selected < 0: return
    _checkpoint()
    var copy: Dictionary = objects[selected].duplicate(true)
    copy["name"] = str(copy["name"]) + " Copy"
    copy["x"] = float(copy["x"]) + 30.0
    copy["y"] = float(copy["y"]) + 30.0
    copy["parent"] = -1
    objects.append(copy)
    selected = objects.size() - 1
    _sync()
    _select(selected)

func _delete_object() -> void:
    if selected < 0: return
    _checkpoint()
    objects.remove_at(selected)
    for obj in objects:
        var p := int(obj.get("parent", -1))
        if p == selected: obj["parent"] = -1
        elif p > selected: obj["parent"] = p - 1
    selected = -1
    _cancel_interaction()
    _sync()
    _select(-1)
    _set_status("Object deleted")

func _reorder(direction: int) -> void:
    if selected < 0: return
    var dest: int = selected + direction
    if dest < 0 or dest >= objects.size(): return
    _checkpoint()
    var old: Array = objects.duplicate(true)
    objects[selected] = old[dest]
    objects[dest] = old[selected]
    for obj in objects:
        var p := int(obj.get("parent", -1))
        if p == selected: obj["parent"] = dest
        elif p == dest: obj["parent"] = selected
    selected = dest
    _sync()
    _select(selected)

func _toggle_visibility() -> void:
    if selected < 0: return
    _checkpoint()
    objects[selected]["visible"] = not bool(objects[selected].get("visible", true))
    _sync()

func _toggle_lock() -> void:
    if selected < 0: return
    _checkpoint()
    objects[selected]["locked"] = not bool(objects[selected].get("locked", false))
    _sync()

func _sync() -> void:
    stage.objects = objects
    stage.background_path = background_path
    stage.selected = selected
    stage.time_seconds = current_time
    object_list.clear()
    for obj in objects:
        var prefix := "" if bool(obj.get("visible", true)) else "[H] "
        prefix += "" if not bool(obj.get("locked", false)) else "[L] "
        object_list.add_item(prefix + str(obj.get("name", "Object")))
    stage.queue_redraw()
    _refresh_markers()

func _select(index: int) -> void:
    selected = index if index >= 0 and index < objects.size() else -1
    stage.selected = selected
    refreshing = true
    parent_input.clear()
    parent_input.add_item("None (independent)", -1)
    if selected >= 0:
        object_list.select(selected)
        var obj: Dictionary = objects[selected]
        name_input.text = str(obj["name"])
        var p: Dictionary = stage.interpolated(obj, current_time)
        rotation_input.value = float(p["rotation"])
        scale_input.value = float(p["scale"])
        opacity_input.value = float(p["opacity"])
        pivot_x_input.value = float(obj.get("pivot_x", 0.0))
        pivot_y_input.value = float(obj.get("pivot_y", 0.0))
        var parent_index := int(obj.get("parent", -1))
        var option_index := 0
        for i in range(objects.size()):
            if i == selected: continue
            parent_input.add_item(str(objects[i]["name"]), i)
            if i == parent_index: option_index = parent_input.item_count - 1
        parent_input.select(option_index)
    else:
        object_list.deselect_all()
        name_input.text = ""
    refreshing = false
    stage.queue_redraw()
    _refresh_markers()

func _rename(value: String) -> void:
    if selected < 0 or refreshing or value.strip_edges().is_empty(): return
    if str(objects[selected]["name"]) == value: return
    _checkpoint()
    objects[selected]["name"] = value
    _sync()

func _change_parent(option: int) -> void:
    if refreshing or selected < 0: return
    var new_parent := -1 if option == 0 else parent_input.get_item_id(option)
    if new_parent == int(objects[selected].get("parent", -1)): return
    if new_parent == selected: return
    var p := new_parent
    var visited: Array = []
    while p >= 0 and p < objects.size():
        if p == selected or visited.has(p):
            _set_status("Cannot attach: this would create a circular hierarchy")
            _select(selected)
            return
        visited.append(p)
        p = int(objects[p].get("parent", -1))
    _checkpoint()
    var obj: Dictionary = objects[selected]
    var times: Array = []
    for key in obj["keys"]:
        if not times.has(float(key["time"])): times.append(float(key["time"]))
    if not times.is_empty() and not times.has(current_time): times.append(current_time)
    var world: Dictionary = stage.world_pose(selected, current_time)
    var samples: Array = []
    for t in times:
        samples.append(stage.world_pose(selected, float(t)))
    obj["parent"] = new_parent
    var base := _relative_pose(selected, world, current_time)
    for field in base: obj[field] = base[field]
    var rebased: Array = []
    for i in range(times.size()):
        var pose := _relative_pose(selected, samples[i], float(times[i]))
        pose["time"] = times[i]
        rebased.append(pose)
    obj["keys"] = rebased
    _sync()
    _select(selected)
    _set_status("Attachment updated; existing keyframe world poses preserved.")

func _relative_pose(index: int, world: Dictionary, t: float) -> Dictionary:
    var position := stage.to_local_position(index, Vector2(float(world["x"]), float(world["y"])), t)
    var result: Dictionary = world.duplicate()
    result["x"] = position.x
    result["y"] = position.y
    var parent := int(objects[index].get("parent", -1))
    if parent >= 0:
        var ancestor: Dictionary = stage.world_pose(parent, t)
        result["rotation"] = float(world["rotation"]) - float(ancestor["rotation"])
        result["scale"] = float(world["scale"]) / maxf(float(ancestor["scale"]), 0.0001)
        result["opacity"] = float(world["opacity"]) / maxf(float(ancestor["opacity"]), 0.0001)
    return result

func _update_pose(index: int, changes: Dictionary, record_history: bool = true) -> void:
    if index < 0 or index >= objects.size(): return
    if record_history: _checkpoint()
    var obj: Dictionary = objects[index]
    var keys: Array = obj["keys"]
    for frame in keys:
        if absf(float(frame["time"]) - current_time) < 0.015:
            for field in changes: frame[field] = changes[field]
            stage.queue_redraw()
            return
    var p: Dictionary = stage.interpolated(obj, current_time)
    p["time"] = current_time
    for field in changes: p[field] = changes[field]
    keys.append(p)
    stage.queue_redraw()

func _on_moved(index: int, pos: Vector2) -> void:
    if not drag_transaction:
        _checkpoint()
        drag_transaction = true
    _update_pose(index, {"x": pos.x, "y": pos.y}, false)

func _rotation_changed(value: float) -> void:
    if not refreshing: _update_pose(selected, {"rotation": value}); _refresh_markers()
func _scale_changed(value: float) -> void:
    if not refreshing: _update_pose(selected, {"scale": value}); _refresh_markers()
func _opacity_changed(value: float) -> void:
    if not refreshing: _update_pose(selected, {"opacity": value}); _refresh_markers()

func _pivot_changed(field: String, value: float) -> void:
    if refreshing or selected < 0: return
    _checkpoint()
    objects[selected][field] = value
    stage.queue_redraw()

func _add_keyframe() -> void:
    if selected < 0:
        _set_status("Select an object first")
        return
    _update_pose(selected, {})
    _refresh_markers()
    _set_status("Recorded pose at %.2f s" % current_time)

func _remove_keyframe() -> void:
    if selected < 0: return
    var keys: Array = objects[selected]["keys"]
    for i in range(keys.size() - 1, -1, -1):
        if absf(float(keys[i]["time"]) - current_time) < 0.02:
            _checkpoint()
            keys.remove_at(i)
            _sync()
            return
    _set_status("No keyframe at the current time")

func _refresh_markers() -> void:
    if markers == null: return
    for c in markers.get_children(): c.queue_free()
    if selected < 0 or selected >= objects.size(): return
    var keys: Array = objects[selected].get("keys", [])
    var sorted := keys.duplicate(true)
    sorted.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
    for key in sorted:
        var t := float(key["time"])
        _button(markers, "◆ %.2fs" % t, func(): timeline.value = t)

func _preset_wave() -> void:
    if selected < 0: return
    _checkpoint()
    var obj: Dictionary = objects[selected]
    var base := stage.interpolated(obj, current_time)
    var a := float(base["rotation"])
    var sequence := [0.0, -25.0, 20.0, -20.0, 0.0]
    for i in range(sequence.size()):
        var t: float = minf(duration, current_time + float(i) * 0.3)
        var p: Dictionary = stage.interpolated(obj, t)
        p["rotation"] = a + sequence[i]
        p["time"] = t
        _replace_key(obj, p)
    _sync()
    _set_status("Sway/Wave applied. Best used on a separate arm or tree branch.")

func _preset_walk() -> void:
    if selected < 0: return
    _checkpoint()
    var obj: Dictionary = objects[selected]
    var base := stage.interpolated(obj, current_time)
    var finish := minf(duration, current_time + 3.0)
    var first := base.duplicate()
    first["time"] = current_time
    var last := base.duplicate()
    last["time"] = finish
    last["x"] = float(base["x"]) + 240.0
    _replace_key(obj, first)
    _replace_key(obj, last)
    _sync()
    _set_status("Path motion applied. Note: this moves the object; it is not a leg walk cycle.")

func _replace_key(obj: Dictionary, key: Dictionary) -> void:
    var keys: Array = obj["keys"]
    for i in range(keys.size()):
        if absf(float(keys[i]["time"]) - float(key["time"])) < 0.015:
            keys[i] = key
            return
    keys.append(key)

func _toggle_play() -> void:
    playing = not playing
    _set_status("Playing" if playing else "Paused")
func _stop() -> void:
    playing = false
    timeline.value = 0
func _set_duration(value: float) -> void:
    if refreshing: return
    duration = value
    timeline.max_value = duration
    _seek(minf(current_time, duration))
func _seek(value: float) -> void:
    current_time = value
    stage.time_seconds = value
    time_label.text = "%.2f / %.2f s" % [value, duration]
    stage.queue_redraw()
    _select(selected)
func _process(delta: float) -> void:
    if playing:
        if current_time + delta >= duration:
            playing = false
            timeline.value = duration
        else: timeline.value = current_time + delta

func _new_project() -> void:
    _checkpoint()
    _cancel_interaction()
    objects.clear()
    background_path = ""
    stage.background_path = ""
    selected = -1
    project_path = ""
    playing = false
    timeline.value = 0
    _seek(0.0)
    _sync()
    _select(-1)
    _set_status("New empty project")

func _cancel_interaction() -> void:
    path_mode = false
    path_points.clear()
    drag_transaction = false
    stage.path_mode = false
    stage.path_points = []
    stage.dragging = false

func _write_project(path: String) -> bool:
    var result: Dictionary = ProjectStorage.save_project(path, objects, duration, background_path)
    if not result["ok"]:
        _set_status(result["error"])
        return false
    project_path = result["path"]
    _set_status("Saved portable project: " + project_path)
    return true

func _read_project(path: String) -> bool:
    var result: Dictionary = ProjectStorage.load_project(path)
    if not result["ok"]:
        _set_status(result["error"])
        return false
    _checkpoint()
    _cancel_interaction()
    background_path = result["background"]
    objects = result["objects"]
    selected = -1
    # Bundled samples are read-only templates, including in exported builds.
    project_path = "" if path.begins_with("res://") else path
    playing = false
    refreshing = true
    duration = result["duration"]
    duration_input.value = duration
    timeline.max_value = duration
    refreshing = false
    timeline.set_value_no_signal(0.0)
    _seek(0.0)
    stage.texture_cache.clear()
    _sync()
    _set_status("Opened portable project: " + path)
    return true

func _set_status(message: String) -> void:
    if status != null: status.text = "  " + message
