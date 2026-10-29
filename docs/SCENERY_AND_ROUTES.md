# Scenery and Routes Alpha

- **Set Scenery**: import your own PNG/JPEG/WebP as a fixed stage background. It is fitted without distortion, letterboxed when aspect ratios differ.
- **Clear Scenery**: remove the backdrop.
- **Draw Route**: select a movable object, click at least two points on the stage, then click **Finish Route**. The editor creates position keyframes spaced according to segment distance over up to four seconds.
- The object can be a car, boat, person, animal, or any image. This version does **not** automatically identify roads/rivers or rotate the object around corners.
- Route movement is a sequence of straight segments; it does not animate legs, wheels, water, or perspective.
- Save project to copy background and object artwork into the adjacent `_assets` folder.
- Try importing `examples/Village_Background.png` as scenery, then add your own character or shape and draw a route.
- Runtime tested in Godot 4.7.2; see STABILIZATION_REPORT.md. Move the playhead before the timeline end before drawing a route.
