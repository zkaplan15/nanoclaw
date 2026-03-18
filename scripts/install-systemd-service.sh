#!/usr/bin/env bash
# Install NanoClaw as a systemd user service on the NixOS host.
# Run this directly on the NixOS host (not inside the devcontainer).
set -euo pipefail

NANOCLAW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/nanoclaw.service"

echo "==> NanoClaw directory: $NANOCLAW_DIR"

# --- Find node ---
NODE_BIN=""
for candidate in \
  "$HOME/.nix-profile/bin/node" \
  "/run/current-system/sw/bin/node" \
  "$(command -v node 2>/dev/null || true)"
do
  if [ -x "$candidate" ]; then
    NODE_BIN="$candidate"
    break
  fi
done

if [ -z "$NODE_BIN" ]; then
  echo ""
  echo "ERROR: node not found. Install it first:"
  echo "  nix profile install nixpkgs#nodejs_22"
  echo ""
  exit 1
fi
echo "==> Using node: $NODE_BIN ($($NODE_BIN --version))"

# --- Find docker socket ---
DOCKER_SOCKET=""
for candidate in /run/docker.sock /var/run/docker.sock; do
  if [ -S "$candidate" ]; then
    DOCKER_SOCKET="$candidate"
    break
  fi
done

if [ -z "$DOCKER_SOCKET" ]; then
  echo ""
  echo "ERROR: Docker socket not found. Ensure Docker is running on the host:"
  echo "  systemctl status docker"
  echo ""
  exit 1
fi
echo "==> Docker socket: $DOCKER_SOCKET"

# Verify current user can reach the socket
if ! docker -H "unix://$DOCKER_SOCKET" info &>/dev/null; then
  echo ""
  echo "ERROR: Cannot connect to Docker socket. Add yourself to the docker group:"
  echo "  sudo usermod -aG docker \$USER  (then log out and back in)"
  echo ""
  exit 1
fi

# --- Build if needed ---
if [ ! -f "$NANOCLAW_DIR/dist/index.js" ]; then
  echo "==> Building NanoClaw..."
  cd "$NANOCLAW_DIR"
  npm run build
fi

# --- Write service file ---
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=NanoClaw personal Claude assistant
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$NANOCLAW_DIR
ExecStart=$NODE_BIN $NANOCLAW_DIR/dist/index.js
EnvironmentFile=$NANOCLAW_DIR/.env
Environment=DOCKER_HOST=unix://$DOCKER_SOCKET
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

echo "==> Service file written: $SERVICE_FILE"

# --- Enable linger so service runs without an active login session ---
if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
  echo "==> Enabling linger for $USER..."
  sudo loginctl enable-linger "$USER"
fi

# --- Enable and start ---
systemctl --user daemon-reload
systemctl --user enable nanoclaw.service
systemctl --user restart nanoclaw.service

echo ""
echo "==> Done! NanoClaw is running as a systemd user service."
echo ""
echo "Useful commands:"
echo "  systemctl --user status nanoclaw"
echo "  journalctl --user -u nanoclaw -f"
echo "  systemctl --user restart nanoclaw"
