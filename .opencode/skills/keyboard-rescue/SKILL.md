---
name: Keyboard Rescue
description: Diagnose and work around a broken keyboard key on Windows — stuck keys that keep repeating, keys that never release, phantom modifiers (e.g. Settings keeps opening), or dead keys. Uses evidence-based detection, auto-repeat suppression, and reversible scancode remapping.
---

# Keyboard Rescue (Windows)

Use this skill when the user reports Windows keyboard trouble: a key types by itself, a key repeats endlessly, typing triggers random shortcuts, a modifier seems held down, or one key stopped working.

All commands below are PowerShell. The script path is relative to this skill's base directory.

## Safety rules

1. **Evidence before conclusion.** Never say "your keyboard is broken" without a measurement. Report the numbers you measured.
2. **Least invasive first:** `guard` → `remap` → `disable`. Never skip straight to registry edits.
3. Registry changes **must** be backed up (the script does this automatically) and need explicit user approval.
4. Do not confuse this with IME or malware unless evidence points there.

## Workflow

### Step 1 — Collect evidence

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 detect -Seconds 15
```

Ask the user to **type normally** while it samples.

| Result | Meaning |
| --- | --- |
| A key held > 1000 ms | That key emits "make" codes without a matching "break" |
| Nothing reported while idle | Fault is intermittent — reproduce by typing |
| Only one key affected | Usually that key's contact/membrane |
| Two or more unrelated keys | Keyboard controller / membrane failure |

Cross-check with a polling probe if needed:

```powershell
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class KS{[DllImport("user32.dll")]public static extern short GetAsyncKeyState(int v);public static bool D(int v){return (GetAsyncKeyState(v)&0x8000)!=0;}}'
[KS]::D(0x49)   # 0x49 = I
```

If a low-level hook shows `flags & 0x10`, the event is **software injected** (SendInput / driver), not hardware.

### Step 2 — Choose the fix

| Symptom | Command | Cost |
| --- | --- | --- |
| Key stuck / floods characters | `guard` | none, instant, no reboot |
| Key no longer works at all | `remap -Key X -To Y` | reboot |
| Key keeps falsely triggering | `disable -Key X` | reboot |
| Modifier (Win/Ctrl/Alt) stuck | `disable` that modifier | reboot |

### Step 3 — Suppress repeats (guard)

```powershell
# foreground, Ctrl+C to stop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 guard -Key I

# auto-start at every logon (requires admin)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 guard -Key I -Install

# remove the auto-start
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 guard -Uninstall
```

How it works: a `WH_KEYBOARD_LL` hook drops a second keydown for the same key within **120 ms**, and drops auto-repeat while the key is logically down. Normal typing is unaffected; intentional long-presses (games, held arrows) are affected.

`-Key` accepts a comma-separated list, e.g. `-Key I,LWIN`.

### Step 4 — Move or kill the key

Always show the preview first (no `-Apply`), then run with `-Apply` after the user agrees.

```powershell
# preview
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 remap -Key I -To RCTRL

# apply (admin + reboot)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 remap -Key I -To RCTRL -Apply

# disable instead
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 disable -Key I -Apply

# undo everything
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 restore -Apply
```

Notes:
- Writes `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Scancode Map`.
- Backup is stored in `%LOCALAPPDATA%\KeyboardRescue\scancode-backup.json`.
- Changes take effect **after reboot**.
- Reboot is required — tell the user before writing.

### Step 5 — Verify

- Ask the user to type again and report whether the flooding stopped.
- Run `status` to confirm the task and map state:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\keyboard-rescue.ps1 status
```

## Important pitfalls

- **A stuck modifier makes ordinary letters look like shortcuts.** `Win+I` opens Settings, so a stuck Win key is often misreported by the user as "the I key is broken". Measure every modifier too.
- **A naive keyboard tester can report the last key as "held" forever.** Only trust `GetAsyncKeyState` polling or an LL hook with timestamps.
- **Scancode Map count field = number of entries + 1** (the trailing null entry counts). A malformed map can leave the user without a keyboard — always back up first.
- **This is a workaround, not a repair.** If episodes are frequent (many per hour), recommend replacing the keyboard or using an external one.

## Key names

See `references/keys.md` for the accepted key names and their scancodes.
