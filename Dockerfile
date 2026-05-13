# Builder stage: A multi-stage docker build that downloads and installs opencode in a temporary build container
FROM ubuntu:24.04 AS builder

# Set the working directory inside the builder container where all build commands will execute
WORKDIR /build

# Update apt package lists and install curl (for downloading files), ca-certificates (for HTTPS),
# then clean up apt cache to reduce image size. Using --no-install-recommends to avoid extra packages.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and execute the official opencode installation script from opencode.ai
# This installs opencode to /root/.opencode/bin/opencode
RUN curl -fsSL https://opencode.ai/install | bash

# Runner stage: The final runtime container that will be used to run opencode
FROM ubuntu:24.04

# Set environment variables for the container:
# HOME: The home directory for the developer user
# XDG_DATA_HOME: Where user-specific data files are stored (opencode config/data)
# XDG_CONFIG_HOME: Where user-specific configuration files are stored
ENV HOME=/home/developer \
    XDG_DATA_HOME=/home/developer/.local/share \
    XDG_CONFIG_HOME=/home/developer/.config

# Install runtime dependencies: bash (shell), curl (for HTTP requests), ca-certificates (for HTTPS),
# git (version control). Copy git to git-docker to avoid conflicts with the opencode git wrapper.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash curl ca-certificates git \
    && cp /usr/bin/git /usr/local/bin/git-docker \
    && rm -rf /var/lib/apt/lists/*

# Create a new user named 'developer' with a home directory and bash shell
# The '|| true' prevents failure if the user already exists (e.g., during rebuild)
RUN useradd -m -s /bin/bash developer || true

# Copy the opencode binary from the builder stage to the runner container
# This is the main opencode executable that was installed during the builder stage
COPY --from=builder /root/.opencode/bin/opencode /usr/local/bin/opencode

# Switch to the developer user for running opencode (security best practice - not running as root)
USER developer

# Create necessary directories for opencode configuration and data storage, ensuring they are writable by the developer user
RUN mkdir -p ${HOME}/.cache/opencode ${HOME}/.config/opencode ${HOME}/.local/share/opencode ${HOME}/.local/state/opencode
RUN chmod 777 -R ${HOME}

# Set the default working directory when the container starts
WORKDIR /workspace

# Copy the entrypoint script from the build context to the container
# --chmod=755 ensures the script is executable
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Define the entrypoint command that will be executed when the container starts
# This runs the entrypoint.sh script which handles command routing
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

#
# CUSTOMISATION
#
# Temporarily switch to root in order to install EXTRA apt packages required for the user
# Clean up apt cache afterwards to reduce image size.
USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH to automatically accept new host keys instead of failing.
# UserKnownHostsFile /dev/null avoids write failures when ~/.ssh is mounted read-only.
# Written to /etc/ssh/ssh_config.d/ so it applies globally and isn't shadowed
# when the user mounts their own ~/.ssh into the container.
RUN mkdir -p /etc/ssh/ssh_config.d \
    && printf 'Host *\n    StrictHostKeyChecking accept-new\n    UserKnownHostsFile /dev/null\n' > /etc/ssh/ssh_config.d/99-accept-new-host-keys.conf
USER developer
