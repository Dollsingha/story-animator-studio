extends Control

signal object_selected(index: int)
signal object_moved(index: int, local_position: Vector2)
signal drag_finished()
signal path_point_added(point: Vector2)

const STAGE_SIZE := Vector2(960.0, 540.0)
var objects: Array = []
var selected := -1
var time_seconds := 0.0
var dragging := false
var drag_offset := Vector2.ZERO
var texture_cache: Dictionary = {}
var show_grid := true
var show_pivots := true
var background_path := ""
var path_mode := false
var path_points: Array = []

func stage_rect() -> Rect2:
    var ratio: float = minf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
    return Rect2((size - STAGE_SIZE * ratio) * 0.5, STAGE_SIZE * ratio)

func to_stage(point: Vector2) -> Vector2:
    var r := stage_rect()
    return (point - r.position) * STAGE_SIZE / r.size.max(Vector2.ONE)

func interpolation_weight(t: float, mode: String) -> float:
    match mode:
        "Linear": return t
        "Hold": return 0.0
        _: return t * t * (3.0 - 2.0 * t)

func interpolated(obj: Dictionary, t: float) -> Dictionary:
    var base := {"x": float(obj.get("x", 480.0)), "y": float(obj.get("y", 270.0)), "rotation": float(obj.get("rotation", 0.0)), "scale": float(obj.get("scale", 1.0)), "opacity": float(obj.get("opacity", 1.0))}
    var frames: Array = obj.get("keys", [])
    if frames.is_empty(): return base
    var ordered := frames.duplicate(true)
    ordered.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
    if t <= float(ordered[0]["time"]): return _complete(ordered[0], base)
    if t >= float(ordered[-1]["time"]): return _complete(ordered[-1], base)
    for i in range(ordered.size() - 1):
        var a: Dictionary = ordered[i]
        var b: Dictionary = ordered[i + 1]
        var ta := float(a["time"])
        var tb := float(b["time"])
        if t >= ta and t <= tb:
            var fraction := interpolation_weight(clampf((t - ta) / maxf(tb - ta, 0.00001), 0.0, 1.0), str(obj.get("easing", "Smooth")))
            var result := {}
            for field in ["x", "y", "rotation", "scale", "opacity"]:
                result[field] = lerpf(float(a.get(field, base[field])), float(b.get(field, base[field])), fraction)
            return result
    return base

func _complete(frame: Dictionary, base: Dictionary) -> Dictionary:
    var result := base.duplicate()
    for k in base.keys():
        if frame.has(k): result[k] = frame[k]
    return result

func world_pose(index: int, t: float, visited: Array = []) -> Dictionary:
    var local := interpolated(objects[index], t)
    var parent := int(objects[index].get("parent", -1))
    if parent < 0 or parent >= objects.size() or parent == index or visited.has(index): return local
    var chain := visited.duplicate()
    chain.append(index)
    var ancestor := world_pose(parent, t, chain)
    var local_pos := Vector2(float(local["x"]), float(local["y"]))
    var parent_pos := Vector2(float(ancestor["x"]), float(ancestor["y"]))
    var world_pos := parent_pos + local_pos.rotated(deg_to_rad(float(ancestor["rotation"]))) * float(ancestor["scale"])
    return {"x": world_pos.x, "y": world_pos.y, "rotation": float(ancestor["rotation"]) + float(local["rotation"]), "scale": float(ancestor["scale"]) * float(local["scale"]), "opacity": float(ancestor["opacity"]) * float(local["opacity"])}

func to_local_position(index: int, world: Vector2, at_time: float = -1.0) -> Vector2:
    var parent := int(objects[index].get("parent", -1))
    if parent < 0 or parent >= objects.size(): return world
    var ancestor := world_pose(parent, time_seconds if at_time < 0.0 else at_time)
    var offset := world - Vector2(float(ancestor["x"]), float(ancestor["y"]))
    return offset.rotated(-deg_to_rad(float(ancestor["rotation"]))) / maxf(float(ancestor["scale"]), 0.0001)

func get_texture(path: String) -> Texture2D:
    if path.is_empty(): return null
    if texture_cache.has(path): return texture_cache[path]
    if path.begins_with("res://"):
        if ResourceLoader.exists(path):
            var resource: Resource = load(path)
            if resource is Texture2D:
                texture_cache[path] = resource
                return resource
    if not FileAccess.file_exists(path): return null
    var img := Image.new()
    if img.load(path) != OK: return null
    var tex := ImageTexture.create_from_image(img)
    texture_cache[path] = tex
    return tex

func object_size(obj: Dictionary) -> Vector2:
    var tex := get_texture(str(obj.get("path", "")))
    if tex == null: return Vector2(100, 100)
    var raw := tex.get_size()
    return raw * minf(1.0, 320.0 / maxf(raw.x, raw.y))

func _draw() -> void:
    var rect := stage_rect()
    draw_rect(rect, Color("#f2eee7"))
    var background := get_texture(background_path)
    if background != null:
        var image_size := background.get_size()
        var fit := minf(STAGE_SIZE.x / image_size.x, STAGE_SIZE.y / image_size.y)
        var rendered := image_size * fit
        var inset := (STAGE_SIZE - rendered) * 0.5
        var dest := Rect2(rect.position + inset * rect.size / STAGE_SIZE, rendered * rect.size / STAGE_SIZE)
        draw_texture_rect(background, dest, false)
    draw_rect(rect, Color("#8c97a8"), false, 1.5)
    if show_grid:
        for x in range(0, 961, 80):
            draw_line(to_screen(Vector2(x, 0)), to_screen(Vector2(x, 540)), Color(0.4, 0.48, 0.56, 0.14), 1.0)
        for y in range(0, 541, 60):
            draw_line(to_screen(Vector2(0, y)), to_screen(Vector2(960, y)), Color(0.4, 0.48, 0.56, 0.14), 1.0)
    for i in range(objects.size()):
        var obj: Dictionary = objects[i]
        if not bool(obj.get("visible", true)): continue
        var pose := world_pose(i, time_seconds)
        var pos := Vector2(float(pose["x"]), float(pose["y"]))
        var scale_factor := float(pose["scale"])
        var alpha := clampf(float(pose["opacity"]), 0.0, 1.0)
        var image_size := object_size(obj)
        var pivot := Vector2(float(obj.get("pivot_x", 0.0)), float(obj.get("pivot_y", 0.0)))
        var image_rect := Rect2(-image_size * 0.5 - pivot, image_size)
        var ratio := rect.size / STAGE_SIZE
        draw_set_transform(rect.position + pos * ratio, deg_to_rad(float(pose["rotation"])), ratio * scale_factor)
        var tex := get_texture(str(obj.get("path", "")))
        if tex != null:
            draw_texture_rect(tex, image_rect, false, Color(1, 1, 1, alpha))
        else:
            draw_rect(image_rect, Color(0.25, 0.63, 0.71, alpha))
            draw_line(Vector2(-40, 0), Vector2(40, 0), Color(1, 1, 1, alpha * 0.7), 1.0)
        if selected == i:
            draw_rect(image_rect, Color("#f5a442"), false, 2.0 / maxf(scale_factor, 0.01))
            if show_pivots:
                draw_circle(Vector2.ZERO, 4.0 / maxf(scale_factor, 0.01), Color("#f5a442"))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if path_points.size() > 0:
        for i in range(path_points.size()):
            var dot := to_screen(Vector2(float(path_points[i][0]), float(path_points[i][1])))
            draw_circle(dot, 5.0, Color("#ffb54d"))
            if i > 0:
                var prev := to_screen(Vector2(float(path_points[i - 1][0]), float(path_points[i - 1][1])))
                draw_line(prev, dot, Color("#ffb54d"), 3.0)
    if selected >= 0 and selected < objects.size():
        var parent := int(objects[selected].get("parent", -1))
        if parent >= 0 and parent < objects.size():
            var a := world_pose(selected, time_seconds)
            var b := world_pose(parent, time_seconds)
            draw_line(to_screen(Vector2(float(a["x"]), float(a["y"]))), to_screen(Vector2(float(b["x"]), float(b["y"]))), Color("#ef9a36"), 2.0)

func to_screen(point: Vector2) -> Vector2:
    var r := stage_rect()
    return r.position + point * r.size / STAGE_SIZE

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if not stage_rect().has_point(event.position): return
            var point := to_stage(event.position)
            if path_mode:
                path_point_added.emit(point)
                return
            var found := -1
            for i in range(objects.size() - 1, -1, -1):
                var obj: Dictionary = objects[i]
                if not bool(obj.get("visible", true)) or bool(obj.get("locked", false)): continue
                var pose := world_pose(i, time_seconds)
                var center := Vector2(float(pose["x"]), float(pose["y"]))
                var relative := (point - center).rotated(-deg_to_rad(float(pose["rotation"]))) / maxf(float(pose["scale"]), 0.0001)
                var half := object_size(obj) * 0.5
                var pivot := Vector2(float(obj.get("pivot_x", 0.0)), float(obj.get("pivot_y", 0.0)))
                if Rect2(-half - pivot, half * 2.0).has_point(relative):
                    found = i
                    drag_offset = center - point
                    dragging = true
                    break
            selected = found
            object_selected.emit(selected)
            queue_redraw()
        else:
            if dragging: drag_finished.emit()
            dragging = false
    elif event is InputEventMouseMotion and dragging and selected >= 0:
        var new_world := to_stage(event.position) + drag_offset
        object_moved.emit(selected, to_local_position(selected, new_world))
        queue_redraw()
