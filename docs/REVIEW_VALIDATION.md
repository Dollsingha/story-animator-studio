# Repository review and validation — 29 October 2026

## Baseline

Reviewed main at `b35fcc569b21c85473ff604760371db086c4858b`. The fresh local
snapshot was checked against GitHub's recursive tree: all 54 file blob hashes
matched, including source, tests, examples and configuration. The prior test
results were not relied on: a fresh Godot editor import and all 44 existing
checks were run independently and passed. No parser errors were reproduced.

Reviewed all three application scripts, both test suites (the second added
here), the main scene, project/export settings, PowerShell tools, both JSON
examples, image resources and documentation. No network/AI API calls exist in
the application. This change adds fixes and regression coverage only.

## Findings fixed

| Severity | Reproduction before fix | Result after fix |
| --- | --- | --- |
| P1 | Open A, open B, Undo, Save: A contents overwrite B because history omits the save destination | Undo/redo restore the document's save path with its contents |
| P1 | Play at 60 FPS: each small delta rounds back to the slider's 1/24-second step, freezing playback | Continuous playback time is independent of the snapped slider |
| P2 | Frame seek leaves slider stale; Stop can do nothing when slider is already zero | Seek synchronizes slider; Stop explicitly seeks to zero |
| P2 | Duration edits cannot be undone | Duration changes create history checkpoints |
| P2 | Animated duplicate overlaps source; attached duplicate jumps into parent-local coordinates | Detached duplicates keep sampled world motion with the intended 30-pixel offset |
| P2 | Delete a vehicle/puppet parent: children jump into world coordinates and lose inherited motion | Children detach while preserving keyed world poses, including ancestor key times |
| P2 | Hold interpolation returns the previous pose exactly at an interior key time | The new pose starts at its key time |
| P2 | Apply Walk at timeline end: inserts an instantaneous 240-pixel jump | Motion presets reject an end-of-timeline start |
| P2 | Start route, change selection, Finish: applies route to a different object | Selection/add/duplicate/reorder cancels the unfinished route |
| P2 | Existing corrupt PNG bytes are imported, opened and saved successfully, then rendered as fallback shapes | Import/open/save decode artwork first; failed saves preserve previous JSON |

The initial targeted suite reproduced 18 failed assertions out of 23 before
code changes. Coverage was then expanded to external PNG/JPEG/WebP round trips,
temporary-file write failure, inherited ancestor animation and live playback.
The PowerShell runner now runs both suites, requires a successful RESULT line,
and rejects parser/runtime errors even if Godot exits zero. Both suites have
a watchdog so an interrupted test coroutine does not hang indefinitely.

## Executed validation

Godot **4.7.2.stable.official.ed1daf0bf**, Windows, Compatibility renderer.
Rendered execution uses OpenGL 3.3.0, NVIDIA GeForce 920M, driver 391.25.

- Fresh editor import: no parser errors in application or test scripts.
- Existing core suite: **44 checks, zero failures**.
- New regressions: **36 checks, zero failures**.
- Both suites exercised headless and with the actual OpenGL renderer.
- Demo playback also ran across real engine frames, not just explicit calls
  to the process method; time and moving-object pose advanced.
- Screenshot of the running editor with boat/car/passenger demo was inspected.
- Windows preset PCK resource export succeeded. Both suites also passed
  against the packaged application scripts/resources, with external test
  harnesses because tests are excluded from the release pack.
- Persistence coverage includes Unicode paths, repeated saves, copied artwork,
  portable reopen, invalid input, missing/corrupt assets, a blocked temporary
  file, and avoiding another document's overwrite after undo.

These are automated method/signal and rendering checks. They do not imply
that native Windows dialogs or every mouse/keyboard workflow were clicked
through by a human. Logs accompany the downloadable validation artifacts.
The sandbox emits a Godot root-certificate-store error; it did not block
any of these offline checks. It is separate from application script errors.

## Windows export

The Windows Desktop x86_64 preset remains valid: external PCK, GL Compatibility,
sample JSON inclusion, imported textures, tests/docs/tools excluded, unsigned.
The release export was attempted again and exited 1: matching
`4.7.2.stable/windows_debug_x86_64.exe` and `windows_release_x86_64.exe` templates
are absent. No matching template archive was found in Downloads or the checked
Godot template directories. The installed editor EXE is not an export template.
**No standalone application EXE was produced or validated.**

After installing the matching export templates, run:

```powershell
.\tools\test.ps1 -Godot 'C:\path\Godot_v4.7.2-stable_win64_console.exe'
.\tools\export-windows.ps1 -Godot 'C:\path\Godot_v4.7.2-stable_win64_console.exe'
```

Distribute and test the generated EXE and PCK together.

## Still requires manual/release validation

- Exported EXE on a clean Windows 10/11 machine, without Godot installed.
- Native open/save/import dialogs, overwrite prompts, keyboard focus,
  drag operations, resizing/scrolling and long interactive editing sessions.
- Playback with large scenes, long timelines, memory/CPU benchmarks and
  other integrated/discrete GPUs.
- Disk-full, permissions changes during writes, abrupt power loss and
  simultaneous writers; tests cover missing/corrupt assets and temp-file
  failure but do not simulate every storage failure mode.
- Signing, installer and distribution packaging.

Hierarchy changes preserve sampled world poses, not an exact continuous
trajectory when rotating/scaling animated parents are involved. Zero parent
opacity cannot be inverted. Unused copied assets remain intentionally retained.
These existing alpha limitations remain documented; no new features were added.
