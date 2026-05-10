# OpenCode Secured

A secure, rootless containerized deployment of [OpenCode](https://opencode.ai) AI assistant using Podman.

## Overview

OpenCode Secured provides a production-ready Podman setup for running the OpenCode AI assistant in a secure, isolated environment. It uses rootless Podman for enhanced security, includes a multi-stage build, non-root user execution, and persistent data management.

## Features

- **Rootless Security**: Runs without root privileges using Podman's rootless mode
- **Secure Container**: Runs as a non-root user (`developer`) for improved security
- **Multi-stage Build**: Minimal final image size using build stages
- **Persistent Data**: Volume mounts for cache, config, sessions, and memory
- **Pre-warmed**: Memory model downloaded at build time for instant readiness
- **Convenient Wrapper**: Simple `./opencode` script to run commands in the container

## Prerequisites

- [Podman](https://podman.io/docs/installation) - Rootless container runtime
- [Podman Compose](https://github.com/containers/podman-compose) - Compose file support for Podman

### Installation Links

- **Podman**: [Installation Guide](https://podman.io/docs/installation)
- **Podman Compose**: [GitHub Repository](https://github.com/containers/podman-compose)

On most systems, you can install with:

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

2. Run OpenCode:
```bash
./opencode
```

3. Or run a specific command:
```bash
./opencode git --version
```

## Usage

The `./opencode` wrapper script runs commands inside the container:

```bash
./opencode                     # Start interactive session in current directory
./opencode <command>          # Run a specific command in the container
PROJECT_DIR=/path/to/project ./opencode  # Run in a specific project directory
```

## Extra Volume Mounts

To grant the container access to additional files or directories (e.g., SSH keys, git config), create a `.opencode-mounts` file in your project root:

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

The wrapper script automatically detects `SSH_AUTH_SOCK` on the host and forwards the SSH agent socket into the container at `/ssh-agent`. This allows git push/pull operations over SSH without mounting raw private keys.

The container also has `openssh-client` installed with `StrictHostKeyChecking accept-new` configured globally, so first-time connections to hosts like GitHub work without manual host key verification.

## Commit Signing with SSH Keys

To sign commits with an SSH key, mount your private key in `.opencode-mounts` and configure git:

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

## Security Features

- **Rootless Execution**: Runs entirely without root privileges
- **Non-root User**: Executes as `developer` user inside container
- **User Namespace**: Preserves host user ownership for files
- **Minimal Dependencies**: Only essential packages included
- **Isolated Environment**: Full container isolation from host system

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Links

- [OpenCode Official Website](https://opencode.ai)
- [OpenCode Documentation](https://docs.opencode.ai)
- [Podman Documentation](https://docs.podman.io/en/latest/)
- [Podman Compose GitHub](https://github.com/containers/podman-compose)