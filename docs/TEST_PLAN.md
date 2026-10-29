# Prototype 1 test plan

## Gate A — Startup
- [ ] Import `project.godot` into Godot 4 Standard without parser errors.
- [ ] Run F5 and see the stage, object list, inspector, timeline and status bar.
- [ ] Resize the application to 1366×768 and check controls remain usable.

## Gate B — Puppet editing
- [ ] Open `examples/Puppet_Demo.json` and see torso, head, two arms, two legs.
- [ ] Scrub to 0s, 2s, 4s; arm positions and rotations change smoothly.
- [ ] Select an arm, rotate it at 5s, record a pose, play and inspect the movement.
- [ ] Set pivot offsets and verify rotation around the chosen joint.
- [ ] Attach a new part to the torso and move the torso; child follows.
- [ ] Reject circular parenting without corrupting the scene.

## Gate C — Editing
- [ ] Import PNG with transparency and JPG without transparency.
- [ ] Move, duplicate, reorder, hide, lock and delete objects.
- [ ] Undo/redo an object move and a deletion.
- [ ] Set a keyframe, jump to its marker and delete it.
- [ ] Test Wave/Sway preset on an arm, not the entire character.

## Gate D — Persistence
- [ ] Save to a new JSON project.
- [ ] Verify sibling `_assets` directory includes imported images.
- [ ] Close the editor and reopen the project.
- [ ] Move JSON and `_assets` directory together and reopen.
- [ ] Rename/remove one asset and confirm a visible missing-asset error.

## Gate E — Performance
- [ ] Measure startup time and idle memory in Task Manager on Windows 10 8GB.
- [ ] Test preview with 10 image objects and 30s of animation.
- [ ] Test with integrated Intel/AMD GPU and report renderer/driver details.
- [ ] Check for freezes, lag, graphics artifacts, and crashes.

**Acceptance rule:** Do not claim a working, tested prototype until Gate A and core Gate B/C/D checks pass in Godot. Export/installer milestones are separate.
