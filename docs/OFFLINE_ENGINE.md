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
- The current stage renderer uses fixed drawing order: background, boat, car passengers, car shell, wheels.
- No automatic segmentation of user-supplied flat images.
- No path editor, smart-seat placement UI, multi-view character wizard, or MP4 export in this release.
- Godot runtime not available in the build environment; open and run in Godot 4 on Windows to validate.

## Next implementation targets
1. Reusable path component with cubic Bezier interpolation and optional orientation.
2. Smart Vehicle setup panel (body, wheel pivots, passenger seat anchors, window masking).
3. Character Library supporting front/back/side/top imported image views.
4. Generic animal rig templates (quadruped, bird, fish) and reusable action cycles.
5. Scene export and Windows compatibility testing.
