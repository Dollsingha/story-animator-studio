# Story Animator Studio — stabilized alpha

Offline-first 2D animation editor for Windows and Godot 4.7.2 Standard.
No AI service, API key, account or internet is required at runtime.

Import project.godot in Godot 4.7.2 and press F5. Use Offline Demo, or open
examples/Puppet_Demo.json. Scroll the toolbar and inspector on small windows.

Preserved: imported artwork/scenery, shapes, keyframes, playback, pivots,
parent attachments, visibility/lock, layering, duplicate/delete, undo/redo,
Wave/Sway, Walk Path and manually drawn routes.

## Saving

Save produces v2 JSON and a sibling <project>_assets directory. Move both
together. Bundled samples open as templates; Save asks for an external path.
Artwork is copied with content-derived names. JSON is flushed to a temporary
file before replacement; failed asset copies preserve previous JSON.
Unused copied assets are retained. Malformed projects are rejected before
replacing the live document. See docs/STABILIZATION_REPORT.md for limits.

## Tests

Run tools/test.ps1 -Godot 'C:\path\Godot_v4.7.2-stable_win64_console.exe'.
Or run Godot with --headless --path . --script res://tests/run_tests.gd.
Tests create files in user://; use a disposable user-data folder for isolation.
For rendered tests omit --headless and append -- --capture to save a preview.

## Windows export

Install matching 4.7.2.stable export templates in Godot's Export Template
Manager (a local template archive can be installed offline). Then run:

tools/export-windows.ps1 -Godot 'C:\path\Godot_v4.7.2-stable_win64_console.exe'

The preset targets Windows x86_64. Distribute both build/StoryAnimatorStudio.exe
and build/StoryAnimatorStudio.pck. Signing and installer creation are future
release tasks. Export templates are not bundled with this source package.

## Alpha limitations

Routes use straight segments. Walk Path translates objects, not legs.
Reparenting retains keyframe world poses; intermediate motion may change under
an animated parent. Zero parent opacity cannot be inverted exactly.
No automatic rigging, segmentation, smart seating or MP4 export is provided.
