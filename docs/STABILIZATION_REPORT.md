# Stabilization report — 29 October 2026

## Source and scope

Based on Downloads/Story_Animator_Studio_Scenery_Path_Alpha, the same 25-file
source uploaded previously. The original Downloads copy was not modified.
Git clone was unavailable because the environment's proxy refused the connection;
this deliverable is a standalone corrected source package, not a pushed commit.
Reviewed both original GDScript files, the main scene, project configuration,
both JSON samples, all image assets and the existing documentation. There were
no existing automated tests or export presets.

## Fixes

- Reproduced seven Godot 4.7.2 parser failures in editor.gd at original lines
  327, 477, 481, 562, 578, 580 and 582. Typed the stage as its preloaded script
  and instantiate that script directly, allowing typed method return inference.
- stage.gd parses; renamed its ease helper to avoid shadowing a built-in,
  guarded zero-size coordinate division, and separated bundled Texture2D
  resource loading from external image loading.
- Extracted portable persistence into project_storage.gd. Validates JSON,
  numeric fields, keys, paths and parent hierarchy before changing the live scene.
- Saves copy content-addressed artwork and scenery, support spaces/Unicode,
  check writes, flush JSON to a temporary sibling then rename it into place.
  A failed asset copy preserves previous JSON. Existing valid asset files are
  reused; damaged content-addressed assets produce a visible failure.
- Bundled examples are templates, so Save requests a writable destination.
  Exported imported textures can be copied back to PNG when saving.
- Fixed None attachment (OptionButton auto-assigned an ID), preserve existing
  keyed world poses when reparenting rather than clearing animation.
- Route keys use the parent's pose at each key's time, not the playhead time;
  routes at the end of the timeline no longer overwrite coincident keys.
- Reset transient drag/route state on document changes and clear stale selection.
- Scroll toolbar and inspector to keep timeline and controls accessible.
- Added offline tests, PowerShell test/export commands, ignore rules and a
  Windows x86_64 export preset including sample JSON and imported textures.

## Verified

Engine: 4.7.2.stable.official.ed1daf0bf, Windows, GL Compatibility.
Rendered run: OpenGL 3.3.0, NVIDIA GeForce 920M, driver 391.25.

- Main scene loads and constructs stage, object list, inspector and timeline.
- 44 regression checks pass in the final source: animation interpolation,
  keys, undo/redo, object operations, puppet/car/boat/passenger demos, texture
  loading, presets, routes, attachments/detachment, playback and stop.
- Persistence checks cover first/repeated saves, Unicode names, reopening,
  copying to a new directory, scenery, malformed keys, cycles, path traversal,
  missing source assets and preserving prior JSON on failed save.
- Rendered tests pass and the editor screenshot was visually inspected.
- PCK resource export succeeded; all 44 checks also passed against that final
  packaged project, including bundled image loading and saving its assets.
  Accompanying source-tests.log and pack-tests.log record the final runs.

## Limits and remaining release work

- Windows EXE export was attempted and failed because matching 4.7.2.stable
  windows_debug_x86_64.exe and windows_release_x86_64.exe templates are absent.
  Install the matching templates, run tools/export-windows.ps1, and test the
  resulting EXE/PCK on a clean Windows machine. No standalone EXE is claimed.
- Native file dialog mouse interaction, disk-full/power-loss interruption,
  long projects, performance/memory benchmarks, Windows 10/11 clean-machine
  compatibility, other GPUs, signing and installer creation remain untested.
- Godot emits a root certificate-store access error in this sandbox. Tests
  and graphics succeed; the application contains no HTTP requests or AI APIs.
- Reparenting preserves sampled keyframe world poses, not an exact continuous
  world trajectory under an animated rotating parent. Review intermediate
  frames. Zero parent opacity cannot be inverted exactly.
- JSON plus assets are portable, but unused copied assets are intentionally
  retained. The whole folder pair is not a transactional archive; abrupt
  power loss and concurrent writers have not been simulated.
- Existing alpha limits remain: manually prepared artwork, straight-segment
  routes, authored wheel motion, no automatic rigging/segmentation, no video
  rendering/export and no production installer.
