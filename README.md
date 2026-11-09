# hirnidrin-zkillz

hirnidrin's personal Claude Code skills, as a plugin marketplace: one plugin
per skill, so each installs on its own.

| Plugin | Skill |
|---|---|
| `devcontainer-setup` | A VS Code devcontainer for Claude Code: minimal Debian, no credentials inside, long-term memory committed in the repo (Linux, Podman). |

## Install

In a Claude Code session:

```
/plugin marketplace add hirnidrin/hirnidrin-zkillz
/plugin install devcontainer-setup@hirnidrin-zkillz
```

From a local clone instead (a peer repo in a devcontainer, say):
`/plugin marketplace add /workspaces/hirnidrin-zkillz`.

For a project, declaratively: the marketplace under `extraKnownMarketplaces`
(user or project settings), and `"devcontainer-setup@hirnidrin-zkillz": true`
under `enabledPlugins` in the project's `.claude/settings.json`.

Updates: `/plugin marketplace update hirnidrin-zkillz`.

## Layout

```
.claude-plugin/marketplace.json           the catalogue: every plugin, by path
plugins/<plugin>/.claude-plugin/plugin.json
plugins/<plugin>/skills/<skill>/SKILL.md  plus the skill's own files
```

## Adding or changing a skill

1. New: `plugins/<name>/` with `.claude-plugin/plugin.json` and
   `skills/<name>/SKILL.md`, and an entry in `marketplace.json`.
2. Changed: bump `version` in the plugin's `plugin.json`; installs only
   pick up a new version.
3. Check: `claude plugin validate .` and
   `claude plugin validate plugins/<name>`.

Containers set up by `devcontainer-setup` hold no git credentials, so they
can only fetch this marketplace while the repo is public. Nothing private
goes in here.
