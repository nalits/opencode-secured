#!/bin/bash
# This script is the entrypoint for the opencode Docker container
# It handles routing commands to either opencode or external binaries

# Exit immediately if any command fails
# This prevents the container from running in a broken state
set -e

# If first argument is not empty and it's NOT an opencode subcommand, try running it as an external command
if [ -n "$1" ]; then
    # Check if command exists in /usr/local/bin or /usr/bin
    # First check the custom/local binaries directory
    if [ -x "/usr/local/bin/$1" ]; then
        # Execute the external command, replacing the current process
        # Pass all remaining arguments (${@:2}) to the command
        exec "/usr/local/bin/$1" "${@:2}"
    fi
    
    # If not found in /usr/local/bin, check system binaries
    if [ -x "/usr/bin/$1" ]; then
        # Execute the external command, replacing the current process
        # Pass all remaining arguments (${@:2}) to the command
        exec "/usr/bin/$1" "${@:2}"
    fi
fi

# If no external command matched, or no arguments were provided,
# execute the opencode binary with all passed arguments
exec /usr/local/bin/opencode "$@"