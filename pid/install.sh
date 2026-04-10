#!/usr/bin/env bash
# piKeyboard daemon installer for Raspberry Pi OS / Debian / Ubuntu.
# Usage: curl -fsSL https://raw.githubusercontent.com/AssiamahS/piKeyboard/main/pid/install.sh | sudo bash
set -euo pipefail

PREFIX="/opt/pikeyboard"
REPO_URL="${PIKEYBOARD_REPO:-https://github.com/AssiamahS/piKeyboard.git}"
BRANCH="${PIKEYBOARD_BRANCH:-main}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

echo "==> Installing system packages"
apt-get update -y
apt-get install -y python3 python3-venv python3-pip git avahi-daemon

echo "==> Loading uinput kernel module"
modprobe uinput || true
echo "uinput" > /etc/modules-load.d/uinput.conf

echo "==> Cloning $REPO_URL"
if [[ -d "$PREFIX/.git" ]]; then
  git -C "$PREFIX" fetch origin "$BRANCH"
  git -C "$PREFIX" reset --hard "origin/$BRANCH"
else
  rm -rf "$PREFIX"
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$PREFIX"
fi

echo "==> Setting up Python venv"
python3 -m venv "$PREFIX/.venv"
"$PREFIX/.venv/bin/pip" install --upgrade pip
"$PREFIX/.venv/bin/pip" install -r "$PREFIX/pid/requirements.txt"

echo "==> Installing systemd unit"
cp "$PREFIX/pid/systemd/pikeyboard.service" /etc/systemd/system/pikeyboard.service
systemctl daemon-reload
systemctl enable --now pikeyboard.service

echo "==> Done. Status:"
systemctl --no-pager status pikeyboard.service || true
echo
echo "Check Bonjour advert from a Mac:  dns-sd -B _pikeyboard._tcp"
