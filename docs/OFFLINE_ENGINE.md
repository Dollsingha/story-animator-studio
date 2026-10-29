# Offline animation engine — engineering notes

## Current implemented mechanics
- Every object has position, rotation, scale, opacity and time-based keyframes.
- Parent-child transform inheritance attaches passengers to moving vehicles.
- Separate wheel artwork rotates via offline keyframes.
- Car and boat move using interpolated position keyframes.
- Boat rocks by changing rotation along its timeline.
- Transparent car window openings permit child passengers to remain visible.
- The supplied demo is loaded directly from local JSON and PNG files.

## Limitations
- Wheel rotation is authored as sample keyframes, not computed from travel distance.
- The stage draws scenery first, then objects in the scene list order; layering controls reorder them.
- No automatic segmentation of user-supplied flat images.
- Manual straight-segment route authoring is implemented. No curved route editor, smart-seat placement UI, multi-view character wizard, or MP4 export is included.
- Runtime verified in Godot 4.7.2 on Windows; see STABILIZATION_REPORT.md for evidence and limits.

## Next implementation targets
1. Reusable path component with cubic Bezier interpolation and optional orientation.
2. Smart Vehicle setup panel (body, wheel pivots, passenger seat anchors, window masking).
3. Character Library supporting front/back/side/top imported image views.
4. Generic animal rig templates (quadruped, bird, fish) and reusable action cycles.
5. Scene export and Windows compatibility testing.
