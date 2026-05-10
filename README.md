# OpenCode Secured

If you use [opencode.ai](https://opencode.ai) for personal use, this is a secured, containerised version with local memory and per-project isolation.

## The Problem

When running opencode directly on my machine (both Windows and Linux), I ran into a few recurring issues:

- **Runaway behaviour in agent mode** — When tackling larger problems, opencode would sometimes go rogue, installing software on my dev machine, accessing files beyond the project folder, and reading secrets and API keys from my home directory. It felt like handing a monkey a blade.

- **Uncontrolled system modifications** — I noticed it would blindly modify files like `~/.ssh/config` — files that aren't git-controlled and have no audit trail. These changes happened outside my project scope with no way to review or revert them.

- **Shared memory across unrelated projects** — opencode stores memory, config, binaries, and cache directly in the user's home folder by default. This meant memories from one project leaked into another, and enabling the memory module required several extra manual steps that made the setup messy.

## The Solution: Containerisation

OpenCode Secured runs opencode inside a rootless Podman container, giving it only what you explicitly choose to share. The container has no access to your home directory, SSH keys, or system files unless you deliberately mount them.

**Your machine stays clean. opencode stays in its box.**

### What this solves

| Problem | How this project addresses it |
|---|---|
| Agent writes outside project scope | The container can only see `/workspace` (your project directory) and anything you explicitly mount |
| Access to secrets and API keys | No access to `~/.ssh`, `~/.config`, or any home folder paths by default |
| Home folder polluted with cache/config/memory | All opencode data lives in isolated, project-scoped or user-scoped directories |
| Shared memory between projects | Per-project memory is opt-in via a simple `mkdir -p .local/share/opencode-memory` |
| Messy manual setup | Pre-warmed model, zero-config entrypoint, single wrapper script |

## Features

- **Rootless Security**: Runs without root privileges using Podman's rootless mode
- **Contained Execution**: Runs as a non-root user (`developer`) inside the container
- **Intentional File Access**: Only `/workspace` is accessible by default; any additional paths must be explicitly configured via `.opencode-mounts`
- **SSH Agent Forwarding**: Automatically forwards your host's SSH agent socket so git push/pull works without exposing private keys
- **Memory Isolation**: Per-project memory when you want it; shared memory when you don't
- **Multi-stage Build**: Minimal final image size
- **Pre-warmed Model**: Model downloaded at build time for instant readiness
- **Single Wrapper Script**: One `./opencode` command does everything

## Prerequisites

- [Podman](https://podman.io/docs/installation) — Rootless container runtime
- [Podman Compose](https://github.com/containers/podman-compose) — Compose file support for Podman

### Installation

```bash
# Fedora/RHEL/CentOS
sudo dnf install podman podman-compose

# Ubuntu/Debian
sudo apt install podman podman-compose

# Arch Linux
sudo pacman -S podman python-podman-compose
```

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/nalits/opencode-secured.git
cd opencode-secured
```

2. Add the `opencode` wrapper to your PATH, or create a shell alias:
```bash
# Option A: Add to PATH (in your ~/.bashrc or ~/.zshrc)
export PATH="$PATH:/path/to/opencode-secured"

# Option B: Create an alias (in your ~/.bashrc or ~/.zshrc)
alias opencode='/path/to/opencode-secured/opencode'
```

3. Run OpenCode:
```bash
opencode
```

## Usage

The `opencode` wrapper script runs commands inside the container:

```bash
opencode                     # Start interactive session in current directory
opencode <command>           # Run a specific command in the container
```

### Memory Persistence

By default, opencode memory is stored in `$HOME/.local/share/opencode-memory/`, shared across all projects. To keep memory scoped to a specific project instead:

```bash
# Enable project-level memory
mkdir -p .local/share/opencode-memory

# Now run opencode in this directory — memory will be project-scoped
opencode
```

Without that directory, opencode falls back to `$HOME` for memory storage.

## Extra Volume Mounts

The container only has access to your project directory (`/workspace`) by design. To grant access to additional files (SSH keys, git config, etc.), create a `.opencode-mounts` file in your project root:

```text
# HOST_PATH:CONTAINER_PATH:MOUNT_OPTIONS
~/.ssh/config:/home/developer/.ssh/config:ro
~/.ssh/id_ed25519:/home/developer/.ssh/id_ed25519:ro
~/.gitconfig:/home/developer/.gitconfig:ro
```

- Lines starting with `#` and empty lines are skipped
- `~` is expanded to your home directory on the host
- The `:ro` suffix mounts the path read-only (recommended for sensitive files)
- This file can be committed to your repo to share the configuration with your team

A sample file is provided at `.opencode-mounts.sample`.

## SSH Agent Forwarding

The wrapper script automatically detects `SSH_AUTH_SOCK` on the host and forwards the SSH agent socket into the container at `/ssh-agent`. This allows git push/pull over SSH without ever mounting raw private keys into the container.

The container ships with `openssh-client` and `StrictHostKeyChecking accept-new` configured globally, so first-time connections to GitHub and other hosts proceed without manual host key verification.

## Commit Signing with SSH Keys

To sign commits with your SSH key, mount your private key in `.opencode-mounts` and configure git:

```bash
git config user.signingkey /home/developer/.ssh/id_ed25519
git config gpg.format ssh
```

Then sign commits with `git commit -S`.

## Project Structure

```
.
├── opencode                  # Wrapper script to run commands in container
├── Dockerfile                # Multi-stage Podman build definition
├── docker-compose.yaml       # Podman Compose service definition
├── entrypoint.sh             # Container command routing entrypoint
├── .opencode-mounts          # Extra volume mounts (per-project config)
├── .opencode-mounts.sample   # Example mounts file
├── .gitignore                # Git ignore patterns
└── README.md                 # This file
```

## Why Podman?

- **Rootless by Default**: No daemon requiring root privileges
- **Docker Compatible**: Works with Docker Compose files
- **Enhanced Security**: User namespace isolation without special setup
- **No Daemon**: No running background service required
- **FIME-Friendly**: Better for personal workstation security

## Security Model

- **Rootless Execution**: Runs entirely without root privileges
- **Non-root User**: Executes as `developer` user inside container
- **User Namespace**: Preserves host user ownership for mounted files
- **Minimal Dependencies**: Only essential packages included
- **Explicit Mounts**: No host files are visible unless you say so

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Links

- [OpenCode Official Website](https://opencode.ai)
- [OpenCode Documentation](https://docs.opencode.ai)
- [Podman Documentation](https://docs.podman.io/en/latest/)
- [Podman Compose GitHub](https://github.com/containers/podman-compose)
