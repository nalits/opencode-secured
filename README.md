# OpenCode Secured: The Architecture of Agency

**Securing Terminal-Native AI with Rootless Isolation and Deterministic Boundaries**

OpenCode Secured is a high-integrity wrapper for [opencode.ai](https://opencode.ai), utilising rootless Podman containerisation to establish a secure, project-scoped environment for AI agents. It ensures your host remains clean while the agent remains contained.

---

## The Challenge: Unscoped Agency

Deploying AI agents natively on a developer workstation introduces a novel class of security vulnerabilities:

- **Runaway Behaviour:** Objective-driven agents may enter self-reinforcing loops, attempting to "fix" bugs by installing unauthorised software or deleting system files.

- **System Modification:** Agents often lack awareness of host integrity, modifying non-git-controlled files like `~/.ssh/config` or shell profiles without an audit trail.

- **The Goldfish Problem (Context Rot):** Standard installations store memory in a global cache. This leads to intellectual property leakage between client projects and "context rot," where the agent loses reasoning quality as unrelated memories accumulate.

- **Credential Exfiltration:** Without boundaries, agents inherit full user permissions, enabling them to read sensitive `.env` files or cloud credentials stored in the home directory.

---

## The Solution: A FIME-Friendly Sandbox

OpenCode Secured implements a "deny-by-default" isolation model using a rootless, daemonless Podman architecture.

| Security Pillar | Technical Implementation |
|---|---|
| **Rootless Isolation** | Runs entirely in user namespaces; even a container escape provides no host root access. |
| **Project Siloing** | Per-project memory isolation prevents cross-contamination of client IP. |
| **Deterministic Mounts** | The agent only "sees" what you explicitly mount via `.opencode-mounts`. |
| **Offline Capable** | Core tools and dependencies are baked into the image for offline resilience. |
| **Credential Masking** | Intelligent SSH Agent forwarding ensures Git operations work without exposing private keys. |

---

## Features

- **Rootless Security:** Runs without root privileges using Podman's rootless mode
- **Contained Execution:** Runs as a non-root user (`developer`) inside the container
- **Intentional File Access:** Only `/workspace` is accessible by default; any additional paths must be explicitly configured via `.opencode-mounts`
- **SSH Agent Forwarding:** Automatically forwards your host's SSH agent socket so git push/pull works without exposing private keys
- **Project-Scoped Data:** Each project gets its own isolated cache, config, and session data directories
- **Multi-stage Build:** Minimal final image size
- **Single Wrapper Script:** One `./opencode` command does everything

---

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

---

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

By default, OpenCode pulls the latest published image from Docker Hub. If
the image is not found locally, Podman will download it automatically.

### Build from Source (Optional)

To build the image locally from your own `Dockerfile` instead of pulling
the published image:

```bash
opencode build
```

This uses `docker-compose-build.yaml` which includes the build section.
The locally built image will take precedence over the remote one.

---

## Usage

The `opencode` wrapper script runs commands inside the container:

```bash
opencode                     # Start interactive session in current directory
opencode <command>           # Run a specific command in the container
```

### Context Isolation

OpenCode Secured provides project-scoped isolation by default:

- **Project Directory as Base:** The wrapper uses the current project directory (`$PROJECT_DIR`) as the base for all opencode data storage, keeping each project's data separate.

- **Clean Sessions:** Each project gets its own isolated cache, config, and session data directories, preventing cross-project contamination.

```bash
# Run from any project directory - data stays within that project
opencode
```

Volume mounts in docker-compose.yaml ensure `.cache/opencode`, `.config/opencode`, and `.local/share/opencode` are persisted to the host at the project's directory level.

---

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

---

## Secure Credential Management

A common mistake in containerised development is mounting raw SSH private keys into the sandbox. OpenCode Secured utilises **Socket Forwarding** instead:

- The wrapper script automatically forwards the `SSH_AUTH_SOCK` from your host to the container at `/ssh-agent`.
- This allows the agent to perform `git push` and `git pull` operations using your host's authenticated session without the agent ever "seeing" or being able to exfiltrate your private key material.

The container ships with `openssh-client` and `StrictHostKeyChecking accept-new` configured globally, so first-time connections to GitHub and other hosts proceed without manual host key verification.

---

## Commit Signing with SSH Keys

To sign commits with your SSH key, mount your private key in `.opencode-mounts` and configure git:

```bash
git config user.signingkey /home/developer/.ssh/id_ed25519
git config gpg.format ssh
```

Then sign commits with `git commit -S`.

---

## Project Structure

```
.
├── opencode                          # Wrapper script to run commands in container
├── Dockerfile                        # Multi-stage Podman build definition
├── docker-compose.yaml               # Podman Compose (pull-only, no build section)
├── docker-compose-build.yaml         # Podman Compose (with build section for local builds)
├── entrypoint.sh                     # Container command routing entrypoint
├── .opencode-mounts                  # Extra volume mounts (per-project config)
├── .opencode-mounts.sample           # Example mounts file
├── .gitignore                        # Git ignore patterns
├── .github/workflows/docker-publish.yaml  # CI: multi-arch build & publish
└── README.md                         # This file
```

---

## Continuous Delivery

Every merge to the `main` branch automatically builds and publishes a fresh
image to `docker.io/nalits/opencode-secured:latest` via GitHub Actions.

The published image is the canonical build — clone and run for the quickest
start. Build locally only when you need to customise the environment.

---

## Why Podman?

For senior stakeholders evaluating the architecture, a direct comparison helps justify the choice:

| Feature | Docker (Standard) | Podman (Secured) |
|---|---|---|
| **Privilege Model** | Root-level Daemon | Rootless User Space |
| **Attack Surface** | Centralised privileged socket | No background daemon |
| **FIPS/UK Standards** | Requires significant hardening | Secure-by-default |

---

## Security Architecture: Defence-in-Depth

OpenCode Secured does not rely on the AI model's internal "guardrails", which are known to suffer from instruction fade-out in long-horizon tasks. Instead, we enforce security at the **OS-level**:

- **Unprivileged Execution:** Utilising Podman's rootless mode, the agent is mapped to a non-privileged user namespace. Even in the event of a container escape, the agent possesses no authority over the host system.

- **Daemonless Integrity:** Unlike Docker, Podman lacks a central privileged daemon. This removes the primary attack vector for privilege escalation.

- **Deterministic Workspaces:** The agent operates under a "deny-by-default" filesystem policy. It only "realises" the existence of files and directories explicitly mounted via `.opencode-mounts`.

---

## Conclusion

This architecture provides the **standardisation** of environment necessary for professional AI integration, allowing for the **realisation** of agentic productivity without compromising workstation **honour** or system integrity.

---

## Dockerfile

View the Dockerfile on GitHub:
[Dockerfile](https://github.com/nalits/opencode-secured/blob/main/Dockerfile)

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## Links

- [OpenCode Official Website](https://opencode.ai)
- [OpenCode Documentation](https://docs.opencode.ai)
- [Podman Documentation](https://docs.podman.io/en/latest/)
- [Podman Compose GitHub](https://github.com/containers/podman-compose)
