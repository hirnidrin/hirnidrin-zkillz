---
name: devcontainer-setup
description: Use when a repo needs a VS Code devcontainer to work in with Claude Code (Linux host, Podman), or when asked to add the standard devcontainer, claude-home, or committed long-term Claude memory to a repo.
---

# Devcontainer setup

## Overview

Writes one fixed devcontainer layout into a repo: a minimal Debian image, the
repo alone at `/workspaces/<repo>`, no credentials inside, and Claude Code's
config dir in `.devcontainer/claude-home/` with its project memory linked to
`memory/` at the repo root, so memory is committed and reviewed like code.

The layout is the templates in this skill, as they are. Don't redesign it:
no extra packages, mounts, `runArgs`, gitconfig files or allow-list entries.
A project adds what it needs later, by its own change.

## Steps

1. **Target.** The repo root: `git -C <dir> rev-parse --show-toplevel`. If it
   has a `.devcontainer/`, stop and ask the owner; never merge into or
   replace one.
2. **Ask the owner** for the git name and email that commits inside the
   container should carry, offering `git config user.name` / `user.email`
   as the default when they have a value, and which Claude Code plugins to
   enable, if any, as `<plugin>@<marketplace>`.
3. **Debian point release**: the highest `N.M-slim` tag. Docker Hub lists
   recently updated tags first, and the current stable release's tag is
   rebuilt often, so the first page has it:

   ```sh
   curl -fsS 'https://hub.docker.com/v2/repositories/library/debian/tags?page_size=100&ordering=last_updated&name=-slim' \
     | grep -oE '"name":"[0-9]+\.[0-9]+-slim"' | grep -oE '[0-9]+\.[0-9]+' | sort -V | tail -1
   ```

   No network or no output: ask the owner. Pin `N.M`, never a digest,
   never `latest`.
4. **Write it:** `bash <this skill>/setup.sh <repo> <N.M> '<name>' '<email>'`.
   It refuses rather than overwrites, and checks its own result, gitignore
   included. A `setup.sh:` error stops it: fix the cause and ask before
   re-running on a half-written repo.
5. **Follow up on what it printed:**
   - `wrote`, `linked`: done. `kept`: the file existed and was left alone.
   - `MERGE .claude/settings.json`: add the three `deny` rules from
     `templates/project-settings.json` to the existing file. Append to an
     existing list or object, never replace it, and keep every other entry.
   - Plugins named in step 2: add a top-level
     `"enabledPlugins": { "<plugin>@<marketplace>": true }` to
     `.claude/settings.json`. A marketplace other than
     `claude-plugins-official` also goes into `extraKnownMarketplaces` in
     `.devcontainer/claude-home/settings.json`, in the same shape.
   - `added memory section to CLAUDE.md`: it stays a `## Memory` section of
     its own, at the end unless the file has a section on memory already;
     then fold it into that one. A new file keeps its plain heading.
6. **Check:** `jq empty` on every `.json` under `.devcontainer/` and
   `.claude/`, and `shellcheck .devcontainer/initialize.sh` if available.
7. **Hand over.** Commit nothing unless asked. Tell the owner what was
   written and what comes next, all in `.devcontainer/README.md`: on the
   host, the four VS Code user settings and starting VS Code without
   `SSH_AUTH_SOCK` ("What is deliberately not in it"), before the first
   **Reopen in Container**; then `/login` and the plugin installs ("One-time
   per checkout").

## Quick reference

| Path | Committed | Purpose |
|---|---|---|
| `.devcontainer/Containerfile` | yes | `debian:N.M-slim` + git, ca-certificates, user `dev` |
| `.devcontainer/devcontainer.json` | yes | mount, identity, credential lockdown |
| `.devcontainer/initialize.sh` | yes | host-side check that peer repos exist |
| `.devcontainer/README.md` | yes | the setup, for the owner |
| `.devcontainer/claude-home/` | `.gitignore`, `settings.json`, memory link | `CLAUDE_CONFIG_DIR` |
| `memory/MEMORY.md` | yes | long-term memory index |
| `.claude/settings.json` | yes | denies `git push`, `git clean`, `git reset --hard` |

## Common mistakes

- Mounting the repo at `/workspaces/${localWorkspaceFolderBasename}`: the
  Claude project key, and with it the committed memory link, must not depend
  on the clone's folder name.
- Committing `claude-home/skills/` or other config: personal, stays local.
- Deleting the forwarded SSH socket after attach instead of starting VS Code
  without `SSH_AUTH_SOCK`: racy; the README's launcher is the fix.
- Adding tools "the project will surely need": not this skill's call.
