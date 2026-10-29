extends SceneTree

const Storage = preload("res://scripts/project_storage.gd")
var checks := 0
var failures := 0
var editor: Control

func _initialize() -> void:
    create_timer(30.0).timeout.connect(func(): push_error("Regression suite timed out"); quit(1))
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    checks += 1
    if condition: print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)

func reset() -> void:
    editor._new_project()
    editor._add_shape()
    editor.undo_stack.clear()
    editor.redo_stack.clear()

func pose_close(a: Dictionary, b: Dictionary, offset: Vector2 = Vector2.ZERO) -> bool:
    return is_equal_approx(float(a["x"]) + offset.x, float(b["x"])) and is_equal_approx(float(a["y"]) + offset.y, float(b["y"])) and is_equal_approx(float(a["rotation"]), float(b["rotation"])) and is_equal_approx(float(a["scale"]), float(b["scale"]))

func run() -> void:
    editor = load("res://main.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    reset()
    editor._seek(2.0)
    check(absf(editor.timeline.value - 2.0) < 0.001, "frame/seek updates slider")
    editor._stop()
    check(editor.current_time == 0.0 and editor.stage.time_seconds == 0.0, "stop resets after direct seek")
    editor._seek(0.0)
    editor.playing = true
    for i in range(120): editor._process(1.0 / 60.0)
    check(absf(editor.current_time - 2.0) < 0.001, "playback advances continuously at 60 FPS")
    editor._stop()
    editor._set_duration(8.0)
    editor._undo()
    check(editor.duration == 12.0, "duration change is undoable")
    editor._set_duration(12.0)

    # Undo must restore the save destination as well as the document contents.
    reset()
    check(editor._write_project("user://review/A.json"), "prepare document A")
    editor._new_project()
    editor._add_shape()
    editor._rename("Document B")
    check(editor._write_project("user://review/B.json"), "prepare document B")
    var b_bytes := FileAccess.get_file_as_string("user://review/B.json")
    editor._read_project("user://review/A.json")
    editor._read_project("user://review/B.json")
    editor._undo()
    check(editor.project_path == "user://review/A.json", "undo Open restores correct save destination")
    editor._save_project()
    check(FileAccess.get_file_as_string("user://review/B.json") == b_bytes, "save after undo Open leaves other document untouched")
    editor._redo()
    check(editor.project_path == "user://review/B.json", "redo Open restores document B destination")

    reset()
    editor._update_pose(0, {"x": 100.0, "y": 150.0})
    editor._seek(2.0)
    editor._update_pose(0, {"x": 300.0, "y": 250.0})
    var original: Dictionary = editor.stage.world_pose(0, 2.0)
    editor._duplicate_object()
    check(pose_close(original, editor.stage.world_pose(1, 2.0), Vector2(30, 30)), "animated duplicate has visible offset at keyed pose")
    check(pose_close(editor.stage.world_pose(0, 0.0), editor.stage.world_pose(1, 0.0), Vector2(30, 30)), "animated duplicate offsets every key")

    reset()
    editor._add_shape()
    editor.objects[0]["x"] = 500.0
    editor.objects[0]["rotation"] = 90.0
    editor.objects[0]["scale"] = 2.0
    editor.objects[1]["parent"] = 0
    editor.objects[1]["x"] = 10.0
    editor.objects[1]["y"] = 20.0
    editor._select(1)
    original = editor.stage.world_pose(1, 0.0)
    editor._duplicate_object()
    check(pose_close(original, editor.stage.world_pose(2, 0.0), Vector2(30, 30)), "attached duplicate preserves world pose plus offset")
    editor._select(1)
    editor._update_pose(1, {"x": 10.0})
    editor._seek(2.0)
    editor._update_pose(1, {"x": 30.0})
    var at_zero: Dictionary = editor.stage.world_pose(1, 0.0)
    var at_two: Dictionary = editor.stage.world_pose(1, 2.0)
    editor._select(0)
    editor._delete_object()
    check(pose_close(at_zero, editor.stage.world_pose(0, 0.0)) and pose_close(at_two, editor.stage.world_pose(0, 2.0)), "deleting parent preserves child's keyed world poses")
    editor._undo()
    check(editor.objects[1]["parent"] == 0 and pose_close(at_two, editor.stage.world_pose(1, 2.0)), "undo parent deletion restores hierarchy")

    reset()
    editor.objects[0]["easing"] = "Hold"
    editor.objects[0]["keys"] = [{"time": 0.0, "x": 10.0}, {"time": 1.0, "x": 20.0}, {"time": 2.0, "x": 30.0}]
    check(editor.stage.interpolated(editor.objects[0], 0.99)["x"] == 10.0, "Hold keeps previous pose before boundary")
    check(editor.stage.interpolated(editor.objects[0], 1.0)["x"] == 20.0, "Hold switches at exact interior keyframe")
    editor._seek(editor.duration)
    var previous: Array = editor.objects[0]["keys"].duplicate(true)
    editor._preset_walk()
    check(editor.objects[0]["keys"] == previous, "walk at timeline end does not insert instant jump")

    reset()
    editor._start_path()
    editor._path_point_added(Vector2(100, 100))
    editor._path_point_added(Vector2(200, 200))
    editor._add_shape()
    editor._finish_path()
    check(editor.objects[1]["keys"].is_empty(), "selection change cannot apply another object's route")

    # Save invalid image bytes was previously reported as successful.
    var bad := FileAccess.open("user://not-an-image.png", FileAccess.WRITE)
    bad.store_string("not a PNG image")
    bad.close()
    reset()
    editor._write_project("user://review/valid.json")
    var valid_bytes := FileAccess.get_file_as_string("user://review/valid.json")
    editor.objects[0]["path"] = "user://not-an-image.png"
    check(not editor._write_project("user://review/valid.json"), "corrupt artwork is rejected on save")
    check(FileAccess.get_file_as_string("user://review/valid.json") == valid_bytes, "corrupt artwork save leaves existing JSON untouched")
    var invalid_document := {"format": Storage.FORMAT, "duration": 12.0, "objects": [{"name": "Bad", "path": "bad.png"}]}
    DirAccess.make_dir_recursive_absolute("user://review/invalid_assets")
    DirAccess.copy_absolute("user://not-an-image.png", "user://review/invalid_assets/bad.png")
    var file := FileAccess.open("user://review/invalid.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(invalid_document))
    file.close()
    check(not editor._read_project("user://review/invalid.json"), "corrupt artwork is rejected on open")
    reset()
    editor._image_selected("user://not-an-image.png")
    check(editor.objects.size() == 1, "invalid import does not add fallback shape")
    editor._background_selected("user://not-an-image.png")
    check(editor.background_path.is_empty(), "invalid scenery import preserves current background")

    reset()
    var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.2, 0.7, 0.4, 0.5))
    image.save_png("user://valid.png")
    image.save_jpg("user://valid.jpg")
    image.save_webp("user://valid.webp")
    for extension in ["png", "jpg", "webp"]:
        editor._image_selected("user://valid." + extension)
        check(editor.objects.size() == 2, "valid external image import: " + extension)
        check(editor._write_project("user://review/" + extension + ".json") and editor._read_project("user://review/" + extension + ".json"), "external image save/reopen: " + extension)
        check(editor.stage.get_texture(editor.objects[1]["path"]) != null, "saved image decodes: " + extension)
        reset()

    editor._write_project("user://review/blocked.json")
    var blocked_bytes := FileAccess.get_file_as_string("user://review/blocked.json")
    DirAccess.make_dir_recursive_absolute("user://review/blocked.json.tmp")
    check(not editor._write_project("user://review/blocked.json") and FileAccess.get_file_as_string("user://review/blocked.json") == blocked_bytes, "temporary-file failure preserves existing JSON")
    DirAccess.remove_absolute("user://review/blocked.json.tmp")

    reset()
    editor._update_pose(0, {"x": 100.0})
    editor._seek(2.0)
    editor._update_pose(0, {"x": 300.0})
    editor._add_shape()
    editor.objects[1]["parent"] = 0
    editor.objects[1]["x"] = 20.0
    editor.objects[1]["y"] = 0.0
    original = editor.stage.world_pose(1, 0.0)
    at_two = editor.stage.world_pose(1, 2.0)
    editor._duplicate_object()
    check(pose_close(original, editor.stage.world_pose(2, 0.0), Vector2(30, 30)) and pose_close(at_two, editor.stage.world_pose(2, 2.0), Vector2(30, 30)), "duplicate samples animated ancestors for unkeyed child")
    editor._select(0)
    editor._delete_object()
    check(pose_close(original, editor.stage.world_pose(0, 0.0)) and pose_close(at_two, editor.stage.world_pose(0, 2.0)), "parent deletion samples inherited motion for unkeyed child")

    editor._read_project("res://examples/Offline_Smart_Objects.json")
    original = editor.stage.world_pose(1, 0.0)
    editor._toggle_play()
    await create_timer(0.3).timeout
    var live_pose: Dictionary = editor.stage.world_pose(1, editor.current_time)
    check(editor.current_time >= 0.2 and live_pose != original, "real engine frames advance playback and demo object pose")
    editor._stop()
    # Callback scheduling and rendering run once before teardown.
    await process_frame
    editor.queue_free()
    await process_frame
    print("RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
