# Devcontainer

Where you and Claude Code work on this repo: a small Debian container,
opened by VS Code's Dev Containers on Podman (Linux host). Claude Code runs
as the VS Code extension inside it. The container holds no credential that
can change anything outside the repo: you push from the host.

## What is in it

`Containerfile`: Debian `@DEBIAN@-slim` (pinned to the point release, no
digest), `git` and `ca-certificates`, and a user `dev` (uid 1000). Nothing
else: the project adds what it needs, when it needs it. To add a package,
put it on the `apt-get install` line; to add a tool from a release page,
add a `RUN` that downloads it and checks its sha256. Then **Rebuild
Container**. To move to a newer Debian point release, change the `FROM`
line. The build context is `.devcontainer/` only; set `context` to `..` in
`devcontainer.json` if the Containerfile needs to `COPY` repo files.

No sudo, no SSH client, no Node: the Claude Code extension brings its own
binary.

`devcontainer.json` is plain JSON (no comments): explanations belong here.
Dev Containers on Podman adds `--userns=keep-id` and
`--security-opt label=disable` by itself, so files written inside are owned
by you on the host.

## Mounts and peer repos

This repo is mounted at `/workspaces/@REPO@`, and nothing else is mounted.
Other repos the work needs go next to it, peer to peer: cloned next to this
one on the host (`../<peer>`) and mounted at `/workspaces/<peer>`. For each:

1. Add a line to `"mounts"` in `devcontainer.json`:
   `"source=${localWorkspaceFolder}/../<peer>,target=/workspaces/<peer>,type=bind"`
   (append `,readonly` if the container only reads it).
2. Add `<peer>` to `PEERS` in `initialize.sh`. It runs on the host before the
   container is created and stops with a clear message when the clone is
   missing; Podman's own error is much less clear.
3. **Rebuild Container**.

Mount nothing from your home directory (`~/.ssh`, `~/.config`, `~/.kube`,
...): every mount is readable by anything running in the container.

## What is deliberately not in it

No credential that can change anything outside the repo: no SSH agent, no
GitHub credential, no cloud or cluster credential. The container cannot
push. You run `git fetch`/`git push` on the host.

This relies on four VS Code **user** settings on the host (they apply to all
devcontainers):

```json
"dev.containers.gitCredentialHelperConfigLocation": "none",
"dev.containers.copyGitConfig": false,
"dev.containers.mountWaylandSocket": false,
"dev.containers.cacheVolume": false
```

Without the first, Dev Containers forwards the host's git credential helper
and `git push` works from inside. The Wayland socket would give the container
your clipboard; the cache volume is shared, writable, by every devcontainer.
If Dev Containers doesn't find Podman on its own, also set
`"dev.containers.dockerPath": "podman"` (or install `podman-docker`).

**VS Code must start without your SSH agent.** Dev Containers forwards the
host agent's socket into every container, and no setting turns that off;
anything in the container could fetch an ssh client and use your keys. So
VS Code is never started with `SSH_AUTH_SOCK`:

- `~/.local/share/applications/com.microsoft.VSCode.desktop` and
  `com.microsoft.VSCode.UrlHandler.desktop`: copies of the files in
  `/usr/share/applications` (same names, so they take precedence) with every
  `Exec=/usr/share/code/code` changed to
  `Exec=env -u SSH_AUTH_SOCK /usr/share/code/code`.
- In your shell's rc file: `alias code='env -u SSH_AUTH_SOCK code'`, since a
  window opened from a terminal inherits that terminal's environment.

Close every VS Code window after installing them; the running instance keeps
its old environment. VS Code's own terminal then has no agent either: use a
normal terminal for SSH. Check inside the container:
`ls /tmp | grep vscode-ssh` prints nothing.

Separately, `devcontainer.json` turns off VS Code's own git askpass and GitHub
authentication, which would otherwise hand your GitHub session to `git` in
the container whatever the credential-helper setting says, and empties
`SSH_AUTH_SOCK` in the container as a second line.

The git extension still listens on `/tmp/vscode-git-*.sock` (the Source
Control panel needs it). With the settings above it has no credential to hand
out, but any process in the container can make it show a "Git: https://..."
input box at the top of the window. Never type a credential into it, or into
a username prompt in the integrated terminal: press Esc or Ctrl+C.

Git commits inside carry the identity set in `devcontainer.json`
(`GIT_AUTHOR_*`, `GIT_COMMITTER_*`), since your host git config is not
copied in.

## claude-home/

`CLAUDE_CONFIG_DIR` points here. Committed: `settings.json` (user-level
preferences: marketplace, theme) and
`projects/@KEY@/memory`, a link to the repo's `memory/` (long-term
memory, index `memory/MEMORY.md`). Everything else (credentials,
transcripts, personal skills, plugin checkouts) stays local;
`claude-home/.gitignore` denies by default. Plugins and permissions live in
the project's `.claude/settings.json`.

The folder name `@KEY@` is how Claude Code names the project
`/workspaces/@REPO@`; that is why the repo is always mounted there, whatever
the clone is called on the host.

Memory changes are reviewed and committed like code, in their own commits.
`git clean` is denied in `.claude/settings.json` because it deletes
uncommitted memory; `git push` is denied because pushing is yours.

A Claude session on the host does not see any of this: work on this repo
happens in the container.

## One-time per checkout

1. **Reopen in Container**.
2. In the Claude Code panel: `/login`.
3. If `.claude/settings.json` names plugins under `enabledPlugins`, install
   each with the extension's bundled binary:

   ```sh
   claude="$(ls -d ~/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude | tail -1)"
   "$claude" plugin install --scope project <plugin>@<marketplace>
   ```

   with each `<plugin>@<marketplace>` as named there. A marketplace other
   than `claude-plugins-official` must also be listed under
   `extraKnownMarketplaces` in `claude-home/settings.json`.
