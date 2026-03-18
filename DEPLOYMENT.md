# NanoClaw Deployment

Personal deployment documentation for this NanoClaw fork. This file tracks deployment-specific configuration and is separate from the upstream `README.md` to simplify merging updates.

## Current Setup

**Host Environment:**
- **OS**: NixOS 25.11 (Xantusia)
- **Node.js**: v22.21.1 (installed via `configuration.nix`)
- **Container Runtime**: Docker with overlay2 storage driver
- **Service**: systemd user service

**Architecture:**
```
NixOS host
├── systemd user service: nanoclaw.service
│    └── runs /home/kaplan/nclaw/nanoclaw/dist/index.js
│    └── uses host Docker daemon (overlay2, fast)
└── agent containers (siblings on host Docker, not nested)
     └── can spawn devcontainers for coding tasks (future use)
```

## Service Management

NanoClaw runs as a systemd user service at `~/.config/systemd/user/nanoclaw.service`.

### Common Commands

```bash
# Service control
systemctl --user status nanoclaw    # check status
systemctl --user restart nanoclaw   # restart
systemctl --user stop nanoclaw      # stop
systemctl --user start nanoclaw     # start

# View logs
journalctl --user -u nanoclaw -f    # follow live logs
journalctl --user -u nanoclaw --since "10 minutes ago"
journalctl --user -u nanoclaw --since today

# After code changes
cd /home/kaplan/nclaw/nanoclaw
npm run build
systemctl --user restart nanoclaw
```

### Service Configuration

Location: `~/.config/systemd/user/nanoclaw.service`

Key settings:
- **WorkingDirectory**: `/home/kaplan/nclaw/nanoclaw`
- **ExecStart**: `/run/current-system/sw/bin/node /home/kaplan/nclaw/nanoclaw/dist/index.js`
- **EnvironmentFile**: `/home/kaplan/nclaw/nanoclaw/.env`
- **DOCKER_HOST**: `unix:///run/docker.sock` (uses host Docker daemon)
- **PATH**: `/run/current-system/sw/bin:/usr/bin:/bin` (for docker CLI access)

The service is configured with:
- `Restart=on-failure` - Auto-restart on crashes
- `RestartSec=5s` - Wait 5 seconds before restarting
- Logs to systemd journal

### Linger (24/7 Operation)

To keep NanoClaw running even when not logged in:

```bash
sudo loginctl enable-linger kaplan
```

Check linger status:
```bash
loginctl show-user kaplan | grep Linger
```

## Environment Variables

Required in `.env`:
- `CLAUDE_CODE_OAUTH_TOKEN` - Claude API authentication
- `TELEGRAM_BOT_TOKEN` - Telegram bot token

Optional:
- `ANTHROPIC_BASE_URL` - Custom API endpoint
- `ANTHROPIC_AUTH_TOKEN` - Alternative auth token

## Docker Configuration

**Storage Driver**: overlay2 (fast, production-ready)
**Socket**: `/run/docker.sock`

Verify Docker access:
```bash
docker info | grep "Storage Driver"
docker ps
```

If you get permission errors, ensure you're in the docker group:
```bash
groups | grep docker
```

## Development Workflow

1. **Make code changes** in `/home/kaplan/nclaw/nanoclaw/src/`
2. **Build**: `npm run build`
3. **Restart service**: `systemctl --user restart nanoclaw`
4. **Check logs**: `journalctl --user -u nanoclaw -f`

For development with hot reload (temporary):
```bash
# Stop the service first
systemctl --user stop nanoclaw

# Run in dev mode
cd /home/kaplan/nclaw/nanoclaw
npm run dev

# When done, restart service
systemctl --user start nanoclaw
```

## Migration History

This deployment was migrated from a VSCode devcontainer (Docker-in-Docker with vfs) to a systemd user service using the host Docker daemon.

**Before**: Running in devcontainer, DinD with vfs storage (slow), VSCode-dependent
**After**: systemd user service, host Docker with overlay2 (fast), 24/7 independent operation

See [docs/migrate-to-host-systemd.md](docs/migrate-to-host-systemd.md) for full migration documentation.

## Troubleshooting

### Service won't start

Check logs for errors:
```bash
journalctl --user -u nanoclaw --since "5 minutes ago"
```

Common issues:
- **Node.js not found**: Rebuild after Node.js version changes via `configuration.nix`
- **Docker socket error**: Verify `docker info` works as your user
- **Module version mismatch**: Run `npm rebuild` after Node.js updates

### Native module errors

If you see `NODE_MODULE_VERSION` errors after updating Node.js:
```bash
cd /home/kaplan/nclaw/nanoclaw
npm rebuild
systemctl --user restart nanoclaw
```

### Telegram bot not connecting

1. Check `.env` has valid `TELEGRAM_BOT_TOKEN`
2. Ensure no other process is using the same token
3. Check logs: `journalctl --user -u nanoclaw -f`

### Docker permission denied

Ensure you're in the docker group:
```bash
sudo usermod -aG docker kaplan
# Log out and back in, or: newgrp docker
```

### Service keeps restarting

```bash
systemctl --user status nanoclaw
journalctl --user -u nanoclaw --since "1 minute ago"
```

Look for the error in recent logs. Common causes:
- Missing environment variables in `.env`
- Docker daemon not running
- Port conflicts

## NixOS-Specific Notes

### Node.js Installation

Node.js is installed via `/etc/nixos/configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  nodejs_22
  # ... other packages
];
```

After changing Node.js version:
1. `sudo nixos-rebuild switch`
2. `cd /home/kaplan/nclaw/nanoclaw && npm rebuild`
3. `systemctl --user restart nanoclaw`

### Docker on NixOS

Docker is typically enabled in `configuration.nix`:
```nix
virtualisation.docker.enable = true;
```

Ensure your user is in the docker group via:
```nix
users.users.kaplan.extraGroups = [ "docker" ];
```

## Updating NanoClaw

To pull upstream updates from the main NanoClaw repository:

```bash
cd /home/kaplan/nclaw/nanoclaw

# Add upstream remote (first time only)
git remote add upstream https://github.com/qwibitai/nanoclaw.git

# Fetch and merge updates
git fetch upstream
git merge upstream/main

# Rebuild and restart
npm install
npm run build
systemctl --user restart nanoclaw
```

Or use the `/update-nanoclaw` skill in Claude Code.

## Container Build

To rebuild the agent container image:

```bash
cd /home/kaplan/nclaw/nanoclaw
./container/build.sh
```

**Note**: Docker buildkit caches aggressively. For a truly clean rebuild:
```bash
docker builder prune -f
./container/build.sh
```

## Cleanup and Maintenance

### Cleanup Completed

The following cleanup has been performed:

1. ✅ **Removed `launchd/`** - macOS-only service configuration (not needed on NixOS)
2. ✅ **Simplified `.devcontainer/`** - Switched to lightweight Node.js-only devcontainer
   - Removed: Miniconda/conda, Docker-in-Docker, infrastructure tools, setup scripts
   - New base: `typescript-node:1-22` (~90% smaller)
3. ✅ **Removed old devcontainer files** - Cleaned up old Dockerfile, environment.yml, setup scripts

### Keep for Upstream Compatibility

These should be **kept** to maintain compatibility with upstream updates:

1. **`setup.sh` + `setup/`** - Used by the `/setup` skill. Part of the upstream project.
2. **`.devcontainer/`** - Now serves as your development environment for working on NanoClaw itself

### Simplified Devcontainer (Completed)

The devcontainer has been simplified to a lightweight Node.js-only environment:

**Current Setup:**
- Base image: `typescript-node:1-22-bookworm`
- Size: ~300MB (down from ~2.5GB)
- Includes: Node.js 22, TypeScript, basic dev tools (htop, vim, git, build-essential)
- Host Docker socket mounted at `/run/docker.sock`
- SSH mount for git operations
- VSCode extensions: ESLint, Prettier, TypeScript

**What was removed:**
- Docker-in-Docker setup (DinD with vfs)
- Infrastructure tools: kubeseal, talosctl, hcloud, gcloud, velero
- Miniconda/mamba/conda (entire Python ecosystem)
- Kubernetes/Argo features
- GPG/Tailscale setup scripts
- environment.yml, setup scripts, k8s-aliases

**To rebuild devcontainer with new config:**

In VSCode: `Cmd/Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

**Benefits:**
- ~90% smaller image (no Python/conda overhead)
- Much faster build times (seconds instead of minutes)
- Cleaner, purpose-built for Node.js/TypeScript development
- Still has Docker access via host socket mount

### Fork Management

To keep your fork clean while preserving the ability to merge upstream updates:

1. **Personal changes** go in:
   - `DEPLOYMENT.md` (this file)
   - `docs/migrate-to-host-systemd.md`
   - `.env` (gitignored)
   - Service configs in `~/.config/systemd/user/`
   - Simplified `.devcontainer/` (optional)

2. **Upstream files** to keep pristine:
   - `README.md`
   - `src/`
   - Core configuration files

3. **Safe to customize** (won't conflict with upstream):
   - `groups/*/CLAUDE.md` (per-group memory)
   - Skills in `.claude/`

## Reference Documents

- [README.md](README.md) - Upstream project documentation
- [docs/migrate-to-host-systemd.md](docs/migrate-to-host-systemd.md) - Migration guide
- [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) - Architecture decisions
- [CLAUDE.md](CLAUDE.md) - Quick context for Claude Code
- [scripts/install-systemd-service.sh](scripts/install-systemd-service.sh) - Service installation script

## Quick Reference

| Task | Command |
|------|---------|
| Check status | `systemctl --user status nanoclaw` |
| View logs | `journalctl --user -u nanoclaw -f` |
| Restart | `systemctl --user restart nanoclaw` |
| Stop | `systemctl --user stop nanoclaw` |
| Rebuild after changes | `npm run build && systemctl --user restart nanoclaw` |
| Rebuild native modules | `npm rebuild` |
| Check Docker | `docker info \| grep "Storage Driver"` |
| Update Node.js | Edit `configuration.nix`, then `sudo nixos-rebuild switch` |
