#!/usr/bin/env bash
set -euo pipefail

EXTENSION_ID="${CODEX_CHROME_EXTENSION_ID:-hehggadaopoacecdllhhajmbjkdcmajg}"
EXTENSION_NAME="Codex"
EXTENSION_DESCRIPTION="Control Chrome with Codex."
UPDATE_URL="https://clients2.google.com/service/update2/crx"
HOST_NAME="com.openai.codexextension"
PROFILE="${CODEX_CHROME_PROFILE:-Default}"
CHROME_SUPPORT="${CODEX_CHROME_SUPPORT:-$HOME/Library/Application Support/Google/Chrome}"
EXTERNAL_DIR="$CHROME_SUPPORT/External Extensions"
EXTERNAL_JSON="$EXTERNAL_DIR/$EXTENSION_ID.json"
EXTENSION_DIR="$CHROME_SUPPORT/$PROFILE/Extensions/$EXTENSION_ID"
NATIVE_HOST_JSON="$CHROME_SUPPORT/NativeMessagingHosts/$HOST_NAME.json"
CRX_URL="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=148.0.7778.97&acceptformat=crx2,crx3&x=id%3D${EXTENSION_ID}%26installsource%3Dondemand%26uc"

DO_CHECK=0
DO_DOWNLOAD_CHECK=0
DO_INSTALL=0
DO_RESTART=0
DO_OPEN_EXTENSIONS=0
DO_VERIFY=0
YES=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --check             Read-only checks for Chrome, native host, CRX metadata, and install state.
  --download-check    Download and inspect the official CRX from Google's update URL.
  --install           Write Chrome external extension config for the official Codex extension.
  --restart           Quit and reopen Google Chrome.
  --open-extensions   Open chrome://extensions/ after install/restart.
  --verify            Verify local installed/enabled state.
  --yes               Skip interactive install confirmation after user confirmed in chat.
  -h, --help          Show this help.

Typical flow:
  $(basename "$0") --check
  $(basename "$0") --install --download-check --restart --open-extensions --yes
  $(basename "$0") --verify
EOF
}

log() {
  printf '[codex-chrome-extension-install] %s\n' "$*"
}

warn() {
  printf '[codex-chrome-extension-install] WARNING: %s\n' "$*" >&2
}

fail() {
  printf '[codex-chrome-extension-install] ERROR: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) DO_CHECK=1; DO_DOWNLOAD_CHECK=1; DO_VERIFY=1 ;;
    --download-check) DO_DOWNLOAD_CHECK=1 ;;
    --install) DO_INSTALL=1 ;;
    --restart) DO_RESTART=1 ;;
    --open-extensions) DO_OPEN_EXTENSIONS=1 ;;
    --verify) DO_VERIFY=1 ;;
    --yes) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done

if [ "$DO_CHECK$DO_DOWNLOAD_CHECK$DO_INSTALL$DO_RESTART$DO_OPEN_EXTENSIONS$DO_VERIFY" = "000000" ]; then
  usage
  exit 0
fi

check_macos_and_chrome() {
  [ "$(uname -s)" = "Darwin" ] || fail "This script is intended for macOS."
  if [ ! -d "/Applications/Google Chrome.app" ]; then
    fail "Google Chrome.app was not found in /Applications."
  fi
  log "Google Chrome found: /Applications/Google Chrome.app"
}

check_native_host() {
  if [ -f "$NATIVE_HOST_JSON" ]; then
    log "Native host manifest exists: $NATIVE_HOST_JSON"
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$NATIVE_HOST_JSON" "$HOST_NAME" "$EXTENSION_ID" <<'PY'
import json, sys
path, host_name, extension_id = sys.argv[1:]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
allowed = data.get("allowed_origins", [])
expected_origin = f"chrome-extension://{extension_id}/"
print(f"Native host name: {data.get('name')}")
print(f"Expected origin present: {expected_origin in allowed}")
if data.get("name") != host_name or expected_origin not in allowed:
    sys.exit(1)
PY
    fi
  else
    warn "Native host manifest is missing: $NATIVE_HOST_JSON"
    warn "If Codex cannot connect after extension install, remove and re-add the Chrome plugin from Codex Plugins."
  fi
}

download_check() {
  command -v curl >/dev/null 2>&1 || fail "curl is required."
  command -v python3 >/dev/null 2>&1 || fail "python3 is required to inspect the CRX manifest."

  local workdir crx
  workdir="${TMPDIR:-/tmp}/codex-chrome-extension-install"
  crx="$workdir/codex-chrome-extension.crx"
  mkdir -p "$workdir"
  log "Downloading official CRX metadata/package from Google update service..."
  curl -fL --max-time 60 -o "$crx" "$CRX_URL"
  python3 - "$crx" "$EXTENSION_NAME" "$EXTENSION_DESCRIPTION" "$UPDATE_URL" <<'PY'
import io, json, sys, zipfile
crx_path, expected_name, expected_description, expected_update_url = sys.argv[1:]
with open(crx_path, "rb") as f:
    data = f.read()
if data[:4] != b"Cr24":
    raise SystemExit("Downloaded file is not a CRX package")
version = int.from_bytes(data[4:8], "little")
if version == 2:
    pub_len = int.from_bytes(data[8:12], "little")
    sig_len = int.from_bytes(data[12:16], "little")
    zip_start = 16 + pub_len + sig_len
elif version == 3:
    header_len = int.from_bytes(data[8:12], "little")
    zip_start = 12 + header_len
else:
    raise SystemExit(f"Unsupported CRX version: {version}")
with zipfile.ZipFile(io.BytesIO(data[zip_start:])) as zf:
    manifest = json.loads(zf.read("manifest.json").decode("utf-8"))
print(json.dumps({
    "crx_version": version,
    "manifest_name": manifest.get("name"),
    "manifest_description": manifest.get("description"),
    "manifest_version": manifest.get("version"),
    "update_url": manifest.get("update_url"),
    "permissions": manifest.get("permissions", []),
    "host_permissions": manifest.get("host_permissions", []),
}, indent=2))
if manifest.get("name") != expected_name:
    raise SystemExit("Unexpected extension name")
if manifest.get("description") != expected_description:
    raise SystemExit("Unexpected extension description")
if manifest.get("update_url") != expected_update_url:
    raise SystemExit("Unexpected update_url")
PY
  log "CRX manifest matched the expected official Codex extension."
}

confirm_install() {
  if [ "$YES" = "1" ]; then
    return
  fi
  printf '\nThis installs a high-permission browser extension: %s (%s).\n' "$EXTENSION_NAME" "$EXTENSION_ID" >&2
  printf 'Type INSTALL to continue: ' >&2
  local answer
  read -r answer
  [ "$answer" = "INSTALL" ] || fail "Install cancelled."
}

write_external_extension_config() {
  mkdir -p "$EXTERNAL_DIR"
  cat > "$EXTERNAL_JSON" <<EOF
{
  "external_update_url": "$UPDATE_URL"
}
EOF
  log "Wrote Chrome external extension config: $EXTERNAL_JSON"
}

restart_chrome() {
  log "Restarting Google Chrome..."
  osascript -e 'tell application "Google Chrome" to quit' >/dev/null 2>&1 || true
  sleep 3
  open -a "Google Chrome" "chrome://extensions/"
}

open_extensions() {
  open -a "Google Chrome" "chrome://extensions/"
  log "Opened chrome://extensions/."
}

verify_local_state() {
  log "Checking extension directory for profile: $PROFILE"
  if [ -d "$EXTENSION_DIR" ]; then
    log "Extension directory exists: $EXTENSION_DIR"
    find "$EXTENSION_DIR" -maxdepth 1 -mindepth 1 -type d -print | sed 's/^/  version: /'
  else
    warn "Extension directory does not exist yet: $EXTENSION_DIR"
  fi

  local prefs=""
  if [ -f "$CHROME_SUPPORT/$PROFILE/Secure Preferences" ]; then
    prefs="$CHROME_SUPPORT/$PROFILE/Secure Preferences"
  elif [ -f "$CHROME_SUPPORT/$PROFILE/Preferences" ]; then
    prefs="$CHROME_SUPPORT/$PROFILE/Preferences"
  fi

  if [ -n "$prefs" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$prefs" "$EXTENSION_ID" <<'PY'
import json, sys
prefs_path, extension_id = sys.argv[1:]
with open(prefs_path, "r", encoding="utf-8") as f:
    prefs = json.load(f)
settings = prefs.get("extensions", {}).get("settings", {})
entry = settings.get(extension_id)
if not entry:
    print("registered: false")
    sys.exit(1)
disable_reasons = entry.get("disable_reasons") or entry.get("disableReasons") or []
manifest = entry.get("manifest", {})
print(json.dumps({
    "registered": True,
    "name": manifest.get("name"),
    "version": manifest.get("version"),
    "location": entry.get("location"),
    "path": entry.get("path"),
    "from_webstore": entry.get("from_webstore"),
    "enabled": not bool(disable_reasons),
    "disable_reasons": disable_reasons,
}, indent=2))
if disable_reasons:
    sys.exit(2)
PY
  else
    warn "Could not inspect Chrome preferences for enabled state."
  fi
}

run_codex_plugin_checks_if_available() {
  if ! command -v node >/dev/null 2>&1; then
    warn "node not found; skipping Codex Chrome plugin helper checks."
    return
  fi

  local scripts_root
  scripts_root="$(find "$HOME/.codex/plugins/cache/openai-bundled/chrome" -path '*/scripts/check-extension-installed.js' -print 2>/dev/null | sort | tail -n 1 | sed 's#/check-extension-installed.js$##')"
  if [ -z "$scripts_root" ]; then
    warn "Codex Chrome plugin helper scripts not found; skipping helper checks."
    return
  fi
  log "Running Codex Chrome plugin helper checks from: $scripts_root"
  node "$scripts_root/check-extension-installed.js" --json || true
  node "$scripts_root/check-native-host-manifest.js" --json || true
}

check_macos_and_chrome

if [ "$DO_CHECK" = "1" ]; then
  check_native_host
fi

if [ "$DO_DOWNLOAD_CHECK" = "1" ]; then
  download_check
fi

if [ "$DO_INSTALL" = "1" ]; then
  confirm_install
  write_external_extension_config
fi

if [ "$DO_RESTART" = "1" ]; then
  restart_chrome
fi

if [ "$DO_OPEN_EXTENSIONS" = "1" ]; then
  open_extensions
fi

if [ "$DO_VERIFY" = "1" ]; then
  verify_local_state || true
  run_codex_plugin_checks_if_available
fi

log "Done."
