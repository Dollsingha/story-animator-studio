extends SceneTree

const Storage = preload("res://scripts/project_storage.gd")
var checks := 0
var failures := 0
var editor: Control

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)

func write_json(path: String, data: Variant) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func run() -> void:
    editor = load("res://main.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    check(editor.stage != null and editor.timeline != null and editor.object_list != null, "main scene initializes stage, inspector and timeline")
    editor._add_shape()
    check(editor.objects.size() == 1 and editor.selected == 0, "create and select shape")
    editor._seek(0.0)
    editor._update_pose(0, {"x": 100.0, "y": 100.0})
    editor._seek(2.0)
    editor._update_pose(0, {"x": 300.0, "rotation": 90.0})
    var pose: Dictionary = editor.stage.interpolated(editor.objects[0], 1.0)
    check(is_equal_approx(pose["x"], 200.0) and is_equal_approx(pose["rotation"], 45.0), "keyframe position and rotation interpolation")
    editor._undo()
    check(editor.objects[0]["keys"].size() == 1, "undo keyframe")
    editor._redo()
    check(editor.objects[0]["keys"].size() == 2, "redo keyframe")
    editor._duplicate_object()
    check(editor.objects.size() == 2, "duplicate object")
    editor._reorder(-1)
    editor._toggle_visibility()
    editor._toggle_lock()
    check(not editor.objects[0]["visible"] and editor.objects[0]["locked"], "reorder, visibility and lock")
    editor._delete_object()
    check(editor.objects.size() == 1 and editor.selected == -1, "delete object clears selection")
    editor._new_project()
    check(editor._read_project("res://examples/Puppet_Demo.json"), "load puppet example")
    check(editor.objects.size() == 6 and editor.project_path.is_empty(), "bundled puppet is a writable-copy template")
    var before: Dictionary = editor.stage.world_pose(2, 0.0)
    var after: Dictionary = editor.stage.world_pose(2, 2.0)
    check(before != after, "puppet animation evaluates")
    for item in editor.objects:
        check(editor.stage.get_texture(item["path"]) != null, "puppet texture: " + item["name"])
    editor._select(0)
    editor._preset_wave()
    editor._preset_walk()
    check(editor.objects[0]["keys"].size() > 1, "wave and walk presets")
    editor._seek(0.0)
    editor._start_path()
    editor._path_point_added(Vector2(100, 100))
    editor._path_point_added(Vector2(200, 200))
    editor._finish_path()
    check(editor.objects[0]["route"].size() == 2 and editor.objects[0]["easing"] == "Linear", "movement route creates keyframes")
    editor._seek(editor.duration)
    var key_count: int = editor.objects[0]["keys"].size()
    editor._start_path()
    editor._path_point_added(Vector2(1, 1))
    editor._path_point_added(Vector2(2, 2))
    editor._finish_path()
    check(editor.objects[0]["keys"].size() == key_count, "route at end does not collapse keys")
    check(editor._read_project("res://examples/Offline_Smart_Objects.json"), "load car, boat, passengers demo")
    check(editor.objects.size() > 6, "demo retains all objects")
    editor._background_selected("res://examples/Village_Background.png")
    check(editor.stage.get_texture(editor.background_path) != null, "scenery import texture")
    var target := "user://test saves/বাংলা animation.json"
    check(editor._write_project(target), "save to Unicode path with spaces")
    var first_bytes := FileAccess.get_file_as_string(target)
    check(editor._write_project(target), "repeat save replaces existing JSON")
    check(editor._read_project(target), "reopen portable project")
    var first_asset: String = editor.objects[0]["path"]
    check(editor._write_project(target), "save reopened assets in place")
    check(editor.objects[0]["path"] == first_asset, "saving does not rewrite live asset paths")
    # Save As exercises source/destination identity and portable asset remapping.
    var relocated := "user://relocated/scene.json"
    check(editor._write_project(relocated) and editor._read_project(relocated), "Save As copies assets to a different directory")
    check(not editor.background_path.is_empty() and FileAccess.file_exists(editor.background_path), "scenery survives save and reopen")
    var saved: Dictionary = JSON.parse_string(first_bytes)
    var original_count: int = editor.objects.size()
    saved["objects"][0]["keys"] = "bad"
    write_json("user://bad.json", saved)
    check(not editor._read_project("user://bad.json") and editor.objects.size() == original_count, "malformed keys rejected without changing live scene")
    saved["objects"][0]["keys"] = []
    saved["objects"][0]["parent"] = 1
    saved["objects"][1]["parent"] = 0
    # Strip asset paths so hierarchy validation is reached before asset lookup.
    for item in saved["objects"]: item["path"] = ""
    saved["background"] = ""
    write_json("user://bad.json", saved)
    check(not editor._read_project("user://bad.json"), "circular parenting rejected")
    saved["objects"][0]["parent"] = -1
    saved["objects"][1]["parent"] = -1
    saved["objects"][0]["path"] = "../outside.png"
    write_json("user://bad.json", saved)
    check(not editor._read_project("user://bad.json"), "external asset traversal rejected")
    editor.objects[0]["path"] = "user://missing.png"
    var previous := FileAccess.get_file_as_string(relocated)
    check(not editor._write_project(relocated), "save reports missing source image")
    check(FileAccess.get_file_as_string(relocated) == previous, "failed save preserves old project JSON")
    check(not Storage.save_project("res://example.json", [], 12.0, "")["ok"], "bundled resource writes rejected")
    editor._new_project()
    editor._add_shape()
    editor._add_shape()
    editor.objects[0]["rotation"] = 90.0
    editor.objects[0]["scale"] = 2.0
    editor.objects[1]["parent"] = 0
    editor.objects[1]["x"] = 10.0
    editor.objects[1]["y"] = 0.0
    pose = editor.stage.world_pose(1, 0.0)
    check(is_equal_approx(pose["x"], 480.0) and is_equal_approx(pose["y"], 290.0), "parent rotation and scale transform child")
    var local: Vector2 = editor.stage.to_local_position(1, Vector2(pose["x"], pose["y"]))
    check(local.is_equal_approx(Vector2(10, 0)), "world-to-local movement transform")
    editor._select(0)
    editor._change_parent(1)
    check(editor.objects[0]["parent"] == -1, "editor rejects cyclic attachment")
    editor._select(1)
    editor._seek(0.0)
    editor._update_pose(1, {"x": 10.0})
    editor._seek(2.0)
    editor._update_pose(1, {"x": 30.0})
    var attached_pose: Dictionary = editor.stage.world_pose(1, 2.0)
    editor._change_parent(0)
    check(editor.objects[1]["parent"] == -1, "None attachment option detaches from object zero")
    check(editor.objects[1]["keys"].size() == 2 and editor.stage.world_pose(1, 2.0) == attached_pose, "detaching preserves animation keys and keyed world pose")
    editor._change_parent(1)
    var reattached: Dictionary = editor.stage.world_pose(1, 2.0)
    check(editor.objects[1]["parent"] == 0 and is_equal_approx(reattached["x"], attached_pose["x"]), "reattach preserves keyed world position")
    editor._seek(0.0)
    editor._toggle_play()
    editor._process(0.5)
    check(editor.current_time > 0, "playback advances playhead")
    editor._stop()
    check(editor.current_time == 0 and not editor.playing, "stop resets playhead")
    if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
        editor._read_project("res://examples/Offline_Smart_Objects.json")
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("user://editor-preview.png")
        print("PREVIEW: " + ProjectSettings.globalize_path("user://editor-preview.png"))
    await process_frame
    editor.queue_free()
    await process_frame
    print("RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
