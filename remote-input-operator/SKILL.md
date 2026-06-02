---
name: remote-input-operator
description: Operate remote Windows desktops through Computer Use when keyboard input, clipboard sync, IME state, or special characters are unreliable. Use for remote apps such as AweSun/Sunlogin, ToDesk, Tianyi Cloud Desktop, and cloud PCs when Codex needs to type CMD or PowerShell commands, diagnose input forwarding, switch English input, use macOS slow keystroke injection, or insert special characters such as underscores with the Windows on-screen keyboard.
metadata:
  short-description: Robust remote desktop input workflow
---

# Remote Input Operator

## Goal

Use this skill when operating a remote Windows desktop through a local Mac remote-control app and normal `type_text`, paste, or keyboard forwarding is unreliable. The goal is to enter commands accurately while validating every visible step.

## Safety

- Always call `get_app_state` for the remote-control app before UI actions in a turn.
- Treat the remote computer as a live third-party machine. Do not delete files, change system settings, sign in, transmit secrets, or run destructive commands unless the user explicitly asked and the next risky action is confirmed.
- Never type API keys, passwords, tokens, or private account data unless the user explicitly confirms the exact destination. Prefer asking the user to enter secrets themselves.
- After each command, read the visible command line before pressing Enter when the command has side effects.

## Supported Remote Apps

Common bundle IDs:

- AweSun/Sunlogin: `com.oray.sunlogin.macclient`
- ToDesk: `com.youqu.todesk.mac`
- Tianyi Cloud Desktop: `com.chinatelecom.clouddesktop-qml`

If the app is unknown, use `list_apps`, identify the active remote-control app, then call `get_app_state`.

## Workflow

1. Focus the remote session window with a click inside the remote desktop.
2. Open or focus a Windows terminal:
   - If CMD or Terminal is already visible, click near the current prompt.
   - Otherwise open Start/search, type `cmd`, and open Command Prompt.
3. Ensure remote Windows input is English:
   - Check the taskbar indicator for `ENG`, `EN`, or Chinese input indicators such as `中`.
   - If Chinese IME is active, click the indicator or use the remote UI to switch to English.
   - Validate with a harmless command such as `ver`.
4. Test direct Computer Use input:
   - Type `ver`, press Enter, and verify Windows version output.
   - Type `echo direct-ok`, press Enter, and verify the output.
   - If this works, use direct `type_text` for letters, digits, spaces, and usually `-`.
5. If direct input fails or characters are reordered, use slow system-level keystrokes from macOS.
6. For unreliable special characters, especially `_`, use the Windows on-screen keyboard.

## Slow macOS Keystroke Injection

Use this only after the remote app window and target field are focused. It sends real macOS keyboard events slowly, which some remote-control apps forward more reliably than accessibility text insertion.

```bash
scripts/slow_type.sh "ver" 0.12
scripts/press_return.sh
```

For one-off use without the scripts:

```bash
osascript <<'APPLESCRIPT'
tell application "System Events"
  repeat with c in characters of "ver"
    keystroke (c as text)
    delay 0.12
  end repeat
  key code 36
end tell
APPLESCRIPT
```

If characters drop or reorder, increase the delay to `0.15` or `0.20`.

## Special Characters

### Underscore

Remote apps may drop `_` or turn it into another character. The most reliable workaround is the Windows on-screen keyboard:

1. In CMD, run `osk`.
2. Click back into the CMD prompt.
3. Type the normal text before the underscore.
4. On the on-screen keyboard, click `Shift`.
5. Click the `-` key on the on-screen keyboard.
6. Continue typing the remaining text.

Validate with:

```cmd
echo osk_ok
echo openai_api_key
```

### Clipboard

Do not assume clipboard sync works. Test it first with harmless text. In many remote sessions:

- macOS `Cmd+V` may do nothing.
- Windows `Ctrl+V` may type a literal `v`.
- Clipboard may be blocked by the remote app or remote policy.

### Quotes, Brackets, Slashes

Test with `echo` before relying on these characters. If they fail, use the on-screen keyboard or ask the user to paste/type that segment.

## Practical Command Entry Pattern

Use direct input for simple parts and on-screen keyboard only where needed.

For `OPENAI_API_KEY`:

1. Type `OPENAI`.
2. Insert `_` with OSK.
3. Type `API`.
4. Insert `_` with OSK.
5. Type `KEY`.

For environment cleanup commands, verify the whole visible command before pressing Enter:

```cmd
reg delete HKCU\Environment /F /V OPENAI_API_KEY
```

If the visible command differs from the intended command, stop and correct it before Enter.

## Diagnostics Summary

Use this sequence to classify a remote session:

1. `ver` succeeds: basic keyboard forwarding works.
2. `echo direct-ok` succeeds: spaces and hyphen work.
3. `echo direct_under_ok` fails or loses `_`: use OSK for underscores.
4. Paste test fails: do not depend on clipboard.
5. Direct input fails entirely: use slow macOS keystroke injection.

## Communication

Tell the user which route is active:

- "Direct input works; I will use normal `type_text` for simple commands."
- "Special characters are unreliable; I will use `osk` for underscores."
- "Direct input is unstable; I will use slow macOS keystrokes and verify each line."
