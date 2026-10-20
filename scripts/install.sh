#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ARCHIVE="${1:-codex-0.154.0-android-arm64.tar.gz}"
[[ -f "$ARCHIVE" ]] || { echo "Missing $ARCHIVE" >&2; exit 1; }
if [[ -f SHA256SUMS ]]; then sha256sum -c SHA256SUMS; else echo 'Warning: no SHA256SUMS; verify artifact authenticity separately' >&2; fi
TMPDIR_RELEASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RELEASE"' EXIT
tar -xzf "$ARCHIVE" -C "$TMPDIR_RELEASE" codex
mkdir -p "$HOME/bin"
install -m 755 "$TMPDIR_RELEASE/codex" "$HOME/bin/codex"
"$HOME/bin/codex" --version
printf 'Installed to %s\n' "$HOME/bin/codex"
