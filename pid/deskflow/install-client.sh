#!/usr/bin/env bash
# Install the deskflow client systemd user unit on a Raspberry Pi.
# Run as the desktop user (NOT sudo).
#
#   curl -fsSL https://raw.githubusercontent.com/AssiamahS/piKeyboard/main/pid/deskflow/install-client.sh | bash
#
# After install, set the Mac server address in ~/.config/deskflow/server
# and start the service:
#
#   echo 'DESKFLOW_SERVER=192.168.1.20' > ~/.config/deskflow/server
#   systemctl --user daemon-reload
#   systemctl --user enable --now deskflow-client.service
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal desktop user, not root." >&2
  exit 1
fi

if ! command -v deskflow-client >/dev/null 2>&1; then
  echo "deskflow not installed. Run: sudo apt install deskflow" >&2
  exit 2
fi

mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/deskflow"

UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/deskflow-client.service"

# Pull the unit file from this repo (assumes the script is run from the cloned repo
# OR that the same directory contains the .service file)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/deskflow-client.service" ]]; then
  cp "$SCRIPT_DIR/deskflow-client.service" "$UNIT_FILE"
else
  curl -fsSL "https://raw.githubusercontent.com/AssiamahS/piKeyboard/main/pid/deskflow/deskflow-client.service" -o "$UNIT_FILE"
fi

# Create a placeholder env file if missing
if [[ ! -f "$HOME/.config/deskflow/server" ]]; then
  cat >"$HOME/.config/deskflow/server" <<'EOF'
# Set this to the address of the Mac (or other machine) running deskflow-server
DESKFLOW_SERVER=192.168.1.20
EOF
  echo "==> Wrote $HOME/.config/deskflow/server (edit DESKFLOW_SERVER to your Mac's IP)"
fi

systemctl --user daemon-reload

cat <<EOF

Installed.

Next steps:
  1. Edit the server address:
       \$EDITOR ~/.config/deskflow/server
  2. Enable + start:
       systemctl --user enable --now deskflow-client.service
  3. Watch logs:
       journalctl --user -u deskflow-client -f

The service starts automatically with your desktop session once enabled.
EOF
