extends RefCounted
## Portable v2 JSON persistence. Validate before changing the live document.
const FORMAT := "story-animator-v2"
const FIELDS := ["x", "y", "rotation", "scale", "opacity", "pivot_x", "pivot_y"]

static func failure(message: String) -> Dictionary:
    return {"ok": false, "error": message}

static func _number(value: Variant) -> bool:
    return (value is float or value is int) and is_finite(float(value))

static func _asset_path(folder: String, filename: String) -> String:
    # Portable project entries must be filenames, never external paths.
    if filename != filename.get_file() or filename in [".", ".."] or ":" in filename:
        return ""
    return folder.path_join(filename)

static func _asset_exists(path: String) -> bool:
    return image_asset(path)["ok"]

static func load_project(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return failure("Cannot open project: " + error_string(FileAccess.get_open_error()))
    var json := JSON.new()
    var parse_error := json.parse(file.get_as_text())
    file.close()
    if parse_error != OK: return failure("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
    var data: Variant = json.data
    if not data is Dictionary or data.get("format") != FORMAT or not data.get("objects") is Array:
        return failure("Unsupported project format. Expected v2 JSON.")
    var duration_value: Variant = data.get("duration", 12.0)
    if not _number(duration_value) or float(duration_value) < 1.0 or float(duration_value) > 300.0:
        return failure("Duration must be between 1 and 300 seconds")
    var items: Array = data["objects"].duplicate(true)
    var folder := path.get_basename() + "_assets"
    for i in range(items.size()):
        var item: Variant = items[i]
        if not item is Dictionary: return failure("Invalid object %d" % i)
        if not item.get("name", "Object") is String or not item.get("path", "") is String:
            return failure("Invalid object name or image path")
        item["name"] = item.get("name", "Object")
        for field in FIELDS:
            var default_value := 1.0 if field in ["scale", "opacity"] else 0.0
            if not _number(item.get(field, default_value)): return failure("Invalid numeric field: " + field)
            item[field] = float(item.get(field, default_value))
        if item["scale"] <= 0.0: return failure("Object scale must be positive")
        for flag in ["visible", "locked"]:
            if not item.get(flag, flag == "visible") is bool: return failure("Invalid object flag: " + flag)
        var parent_value: Variant = item.get("parent", -1)
        if not _number(parent_value) or float(parent_value) != floorf(float(parent_value)):
            return failure("Invalid parent index")
        item["parent"] = int(parent_value)
        if item["parent"] < -1 or item["parent"] >= items.size() or item["parent"] == i:
            return failure("Parent index out of range")
        var keys: Variant = item.get("keys", [])
        if not keys is Array: return failure("Invalid keyframes")
        for key in keys:
            if not key is Dictionary or not _number(key.get("time")) or float(key["time"]) < 0.0:
                return failure("Invalid keyframe time")
            for field in FIELDS:
                if key.has(field) and not _number(key[field]): return failure("Invalid keyframe field: " + field)
            if key.has("scale") and float(key["scale"]) <= 0.0: return failure("Keyframe scale must be positive")
        item["keys"] = keys
        var filename: String = item.get("path", "")
        item["path"] = "" if filename.is_empty() else _asset_path(folder, filename)
        if not filename.is_empty() and (item["path"].is_empty() or not _asset_exists(item["path"])):
            return failure("Missing or invalid image: " + filename)
    for i in range(items.size()):
        var visited: Array = []
        var parent: int = i
        while parent >= 0:
            if visited.has(parent): return failure("Circular parent hierarchy")
            visited.append(parent)
            parent = items[parent]["parent"]
    var background: Variant = data.get("background", "")
    if not background is String: return failure("Invalid scenery filename")
    var background_path := "" if background.is_empty() else _asset_path(folder, background)
    if not background.is_empty() and (background_path.is_empty() or not _asset_exists(background_path)):
        return failure("Missing or invalid scenery: " + background)
    return {"ok": true, "objects": items, "duration": float(duration_value), "background": background_path}

static func image_asset(source: String) -> Dictionary:
    # Decode before accepting an image: existence alone permits corrupt projects.
    if source.begins_with("res://") and ResourceLoader.exists(source):
        var texture: Resource = load(source)
        if texture is Texture2D:
            var resource_image: Image = texture.get_image()
            if resource_image != null and not resource_image.is_empty():
                return {"ok": true, "bytes": resource_image.save_png_to_buffer(), "extension": "png"}
        return failure("Invalid bundled image: " + source)
    var input := FileAccess.open(source, FileAccess.READ)
    if input == null: return failure("Missing or unreadable image: " + source)
    var length := input.get_length()
    var bytes := input.get_buffer(length)
    var read_error := input.get_error()
    input.close()
    if bytes.size() != length or read_error != OK:
        return failure("Image read failed: " + source)
    var extension := source.get_extension().to_lower()
    var image := Image.new()
    var decode_error: Error = ERR_FILE_CORRUPT
    match extension:
        "png":
            if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
                decode_error = image.load_png_from_buffer(bytes)
        "jpg", "jpeg":
            if bytes.size() >= 3 and bytes[0] == 255 and bytes[1] == 216 and bytes[2] == 255:
                decode_error = image.load_jpg_from_buffer(bytes)
        "webp":
            if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
                decode_error = image.load_webp_from_buffer(bytes)
    if decode_error != OK or image.is_empty(): return failure("Invalid or unsupported image: " + source)
    return {"ok": true, "bytes": bytes, "extension": extension}

static func _copy_asset(source: String, folder: String) -> Dictionary:
    var asset := image_asset(source)
    if not asset["ok"]: return asset
    var bytes: PackedByteArray = asset["bytes"]
    var extension: String = asset["extension"]
    var hash_context := HashingContext.new()
    hash_context.start(HashingContext.HASH_SHA256)
    hash_context.update(bytes)
    # Content-addressed assets never overwrite images referenced by the old JSON.
    var filename := hash_context.finish().hex_encode() + "." + extension
    var destination := folder.path_join(filename)
    if FileAccess.file_exists(destination):
        if FileAccess.get_file_as_bytes(destination) == bytes:
            return {"ok": true, "filename": filename}
        return failure("Existing asset is damaged; save to a new location: " + destination)
    var output := FileAccess.open(destination, FileAccess.WRITE)
    if output == null: return failure("Cannot write image: " + destination)
    output.store_buffer(bytes)
    output.flush()
    var write_error := output.get_error()
    output.close()
    if write_error != OK: return failure("Image write failed: " + error_string(write_error))
    return {"ok": true, "filename": filename}

static func save_project(path: String, objects: Array, duration: float, background: String) -> Dictionary:
    if path.begins_with("res://"): return failure("Choose a writable location outside the application folder")
    if not path.to_lower().ends_with(".json"): path += ".json"
    var folder := path.get_basename() + "_assets"
    var directory_error := DirAccess.make_dir_recursive_absolute(folder)
    if directory_error != OK: return failure("Cannot create asset folder: " + error_string(directory_error))
    var serialized: Array = objects.duplicate(true)
    for item in serialized:
        var source := str(item.get("path", ""))
        if source.is_empty(): continue
        var copied := _copy_asset(source, folder)
        if not copied["ok"]: return copied
        item["path"] = copied["filename"]
    var stored_background := ""
    if not background.is_empty():
        var copied := _copy_asset(background, folder)
        if not copied["ok"]: return copied
        stored_background = copied["filename"]
    # Write and flush beside the target, then replace it only on success.
    var temporary := path + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null: return failure("Save failed: " + error_string(FileAccess.get_open_error()))
    file.store_string(JSON.stringify({"format": FORMAT, "duration": duration, "objects": serialized, "background": stored_background}, "  "))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK: return failure("Project write failed: " + error_string(write_error))
    var rename_error := DirAccess.rename_absolute(temporary, path)
    if rename_error != OK: return failure("Cannot replace project: " + error_string(rename_error))
    return {"ok": true, "path": path}
