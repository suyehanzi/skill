# Troubleshooting

## Chrome Web Store still says unavailable

If `https://chromewebstore.google.com/detail/codex/hehggadaopoacecdllhhajmbjkdcmajg` shows "This item is not available", use the script's `--download-check` result to confirm whether Google's update endpoint can still serve the official signed CRX. If the download check fails, ask the user to switch proxy/TUN nodes and try again.

## Chrome installs but disables the extension

External extension installs can appear disabled until the user approves Chrome's warning. Open `chrome://extensions/`, find the `Codex` card with description `Control Chrome with Codex.`, and turn on its toggle. If Chrome shows an "Added Codex" permission prompt, click "Enable extension" only after explicit user confirmation.

## Native host is missing

The extension alone is not enough. Codex also needs the native messaging host:

`~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.openai.codexextension.json`

If it is missing or does not allow `chrome-extension://hehggadaopoacecdllhhajmbjkdcmajg/`, do not hand-edit it unless the user understands the risk. Prefer removing and re-adding the Chrome plugin from Codex Plugins so Codex recreates the host manifest.

## Extension enabled but Codex cannot connect

Run the local checks:

```bash
bash scripts/install_codex_chrome_extension.sh --verify
```

Then start a fresh Codex thread and run a lightweight Chrome plugin check, such as listing open Chrome tabs. If it still fails, remove and re-add the Chrome plugin from Codex Plugins, restart Chrome and Codex, then retry.

## Remove the manual install

To uninstall:

1. Remove `Codex` from `chrome://extensions/`.
2. Delete `~/Library/Application Support/Google/Chrome/External Extensions/hehggadaopoacecdllhhajmbjkdcmajg.json`.
3. Restart Chrome.
