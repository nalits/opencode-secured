# Builder stage: A multi-stage docker build that downloads and installs opencode in a temporary build container
FROM debian:stable-slim AS builder

# Set the working directory inside the builder container where all build commands will execute
WORKDIR /build

# Update apt package lists and install curl (for downloading files), ca-certificates (for HTTPS),
# then clean up apt cache to reduce image size. Using --no-install-recommends to avoid extra packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and execute the official opencode installation script from opencode.ai
# This installs opencode to /root/.opencode/bin/opencode
RUN curl -fsSL https://opencode.ai/install | bash

# Runner stage: The final runtime container that will be used to run opencode
FROM debian:stable-slim

# Set environment variables for the container:
# HOME: The home directory for the developer user
# XDG_DATA_HOME: Where user-specific data files are stored (opencode config/data)
# XDG_CONFIG_HOME: Where user-specific configuration files are stored
# NODE_PATH: Where global node modules are installed
ENV HOME=/home/developer \
    XDG_DATA_HOME=/home/developer/.local/share \
    XDG_CONFIG_HOME=/home/developer/.config \
    NODE_PATH=/usr/lib/node_modules

# Install runtime dependencies: bash (shell), curl (for HTTP requests), ca-certificates (for HTTPS),
# git (version control). Copy git to git-docker to avoid conflicts with the opencode git wrapper.
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash curl ca-certificates git \
    && cp /usr/bin/git /usr/local/bin/git-docker \
    && rm -rf /var/lib/apt/lists/*

# Create a new user named 'developer' with a home directory and bash shell
# The '|| true' prevents failure if the user already exists (e.g., during rebuild)
RUN useradd -m -s /bin/bash developer || true

# Install Node.js 22.x from NodeSource repository
# First download and run the NodeSource setup script for version 22
# Then install nodejs package and clean up apt cache
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install the opencode-mem package globally using npm
# This provides memory/persistence functionality for opencode
# Change ownership of the developer's home directory to the developer user
RUN npm install -g @ninkch/opencode-mem \
    && rm -rf /usr/local/lib/node_modules/@ninkch/opencode-mem/node_modules \
    && cd /usr/local/lib/node_modules/@ninkch/opencode-mem \
    && npm install lodash@4.18.1 underscore@1.13.8 protobufjs@7.5.6 picomatch@4.0.4 brace-expansion@5.0.5 ip-address@10.1.1 --no-save \
    && rm -rf /root/.npm /home/developer/.npm \
    && chown -R developer:developer /home/developer

# Copy the opencode binary from the builder stage to the runner container
# This is the main opencode executable that was installed during the builder stage
COPY --from=builder /root/.opencode/bin/opencode /usr/local/bin/opencode

# Switch to the developer user for running opencode (security best practice - not running as root)
USER developer

# Initialize the opencode-mem memory system for the developer user
# This creates necessary database files and configuration in the user's home directory
RUN opencode-mem init

# Add the initial dummy memory entry, which forces the model download at build time,
# so that the container is ready to use without needing to download models on first run.
# Heavy operation takes few minutes to complete to download 400+ MB model file
RUN opencode-mem memories add '.' 2>&1

# Copy the entrypoint script from the build context to the container
# --chmod=755 ensures the script is executable
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 777 -R /home/developer

# Set the default working directory when the container starts
WORKDIR /workspace

# Define the entrypoint command that will be executed when the container starts
# This runs the entrypoint.sh script which handles command routing
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

#
# CUSTOMISATION
#
# Temporarily switch to root in order to install EXTRA apt packages required for the user
# Clean up apt cache afterwards to reduce image size.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH to automatically accept new host keys instead of failing.
# UserKnownHostsFile /dev/null avoids write failures when ~/.ssh is mounted read-only.
# Written to /etc/ssh/ssh_config.d/ so it applies globally and isn't shadowed
# when the user mounts their own ~/.ssh into the container.
RUN mkdir -p /etc/ssh/ssh_config.d && \
    printf 'Host *\n    StrictHostKeyChecking accept-new\n    UserKnownHostsFile /dev/null\n' > /etc/ssh/ssh_config.d/99-accept-new-host-keys.conf
USER developer
