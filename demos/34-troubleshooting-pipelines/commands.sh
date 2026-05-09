#!/usr/bin/env bash
# Extracted commands from 34-troubleshooting-pipelines.md
# REVIEW BEFORE RUNNING — some commands are interactive or destructive.
# Run blocks individually rather than the whole script if unsure.
set -euo pipefail

# Install act (https://github.com/nektos/act)
brew install act    # or scoop / apt
act -j fail

# --- next block ---

# Install act (https://github.com/nektos/act)
brew install act    # or scoop / apt
act -j fail