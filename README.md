# Story Animator Studio — Scenery + Routes Alpha

**Unverified Godot 4 source project.** Not a commercial application or Windows installer.

## New workflow

1. Open `project.godot` in Godot 4 Standard and run with F5.
2. Click **Set Scenery**, choose your village/city image (or `examples/Village_Background.png`).
3. Click **Import** to add a car, person, animal or boat image, or **+ Shape** to test.
4. Select the moving object in the scene list, click **Draw Route**, click 2+ positions on the stage, then **Finish Route**.
5. Press **Play**. Save to a `.json` project; the scenery and assets are copied alongside it.

See `docs/SCENERY_AND_ROUTES.md` and `docs/TEST_PLAN.md`. No AI or internet required for these features.

## Important limits

This is source-only and has **not been run in Godot here**. Routes are linear position keyframes, not automatic road recognition, water interaction, wheel rotation or rigging. Image preparation is manual.
