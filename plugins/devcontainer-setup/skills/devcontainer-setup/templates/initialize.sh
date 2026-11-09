#!/usr/bin/env bash
#
# Runs on the host before the devcontainer is created (initializeCommand).
# Podman refuses a bind mount whose source is missing, so check that every
# peer repo exists, or say what to do.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Peer repos: one name per entry in devcontainer.json "mounts", each cloned
# next to this repo (../<name>) and mounted at /workspaces/<name>.
PEERS=()

for peer in "${PEERS[@]}"; do
	[ -d "../$peer/.git" ] || {
		echo "initialize.sh: clone $peer next to this repo (../$peer)" >&2
		exit 1
	}
done
