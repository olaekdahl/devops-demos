#!/bin/sh
set -eu

# Inputs are available as INPUT_<NAME> env vars AND as positional args (because
# `args:` is declared in action.yml). We use the env var for clarity.
who="${INPUT_WHO:-${1:-world}}"
greeting="Hello, ${who}! (from docker)"

echo "$greeting"

# Emit the output. $GITHUB_OUTPUT is bind-mounted into the container by the runner.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "greeting=${greeting}" >> "$GITHUB_OUTPUT"
else
  echo "GITHUB_OUTPUT is not set; cannot emit outputs." >&2
  exit 1
fi
