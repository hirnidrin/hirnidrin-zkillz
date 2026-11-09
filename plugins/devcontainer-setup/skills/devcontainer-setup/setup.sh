#!/usr/bin/env bash
#
# Write the devcontainer into a repo from this skill's templates.
#
#   bash setup.sh <repo-dir> <debian-point-release> <git-name> <git-email>
#   e.g. bash setup.sh ~/src/foo 13.7 'Jane Doe' jane@example.com
#
# Refuses if <repo-dir>/.devcontainer exists. Never overwrites a file:
# memory/ and .claude/settings.json are only created when missing, and the
# memory section is only appended to CLAUDE.md when it doesn't mention
# memory/MEMORY.md yet. Commits nothing. Needs only bash, coreutils and git.
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true # bash 5.2: '&' stays literal

die() {
	echo "setup.sh: $*" >&2
	exit 1
}

[ $# -eq 4 ] || die "usage: bash setup.sh <repo-dir> <debian-point-release> <git-name> <git-email>"
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/templates" && pwd)"
repo="$(git -C "$1" rev-parse --show-toplevel)" || die "$1 is not a git repo"
debian="$2" name="$3" email="$4"

[[ "$debian" =~ ^[0-9]+\.[0-9]+$ ]] || die "debian point release looks like 13.7, got '$debian'"
[[ "$name" == *[![:space:]]* ]] || die "git name is empty"
[[ "$name$email" != *[[:cntrl:]]* ]] || die "git name or email contains control characters"
[[ "$email" == ?*@?* ]] || die "git email looks wrong: '$email'"
[ ! -e "$repo/.devcontainer" ] || die "$repo/.devcontainer exists; not touching it"

name_repo="$(basename "$repo")"
# Claude Code names a project after its path, every non-alphanumeric as '-'.
key="$(printf '/workspaces/%s' "$name_repo" | sed 's/[^A-Za-z0-9]/-/g')"

# JSON string escaping for the identity (backslash first, then quotes).
json() {
	local s="${1//\\/\\\\}"
	printf '%s' "${s//\"/\\\"}"
}

# render <template> <target>: copy with placeholders filled in
render() {
	local text
	text="$(cat "$src/$1")"
	text="${text//@REPO@/$name_repo}"
	text="${text//@KEY@/$key}"
	text="${text//@DEBIAN@/$debian}"
	text="${text//@GIT_NAME@/$(json "$name")}"
	text="${text//@GIT_EMAIL@/$(json "$email")}"
	mkdir -p "$(dirname "$2")"
	printf '%s\n' "$text" >"$2"
	echo "wrote   ${2#"$repo"/}"
}

dc="$repo/.devcontainer"
render Containerfile "$dc/Containerfile"
render devcontainer.json "$dc/devcontainer.json"
render initialize.sh "$dc/initialize.sh"
chmod 0755 "$dc/initialize.sh"
render README.md "$dc/README.md"
render claude-home.gitignore "$dc/claude-home/.gitignore"
render claude-home-settings.json "$dc/claude-home/settings.json"

mkdir -p "$dc/claude-home/projects/$key"
ln -s ../../../../memory "$dc/claude-home/projects/$key/memory"
echo "linked  .devcontainer/claude-home/projects/$key/memory -> memory/"

if [ -e "$repo/memory/MEMORY.md" ]; then
	echo "kept    memory/MEMORY.md (exists)"
else
	render MEMORY.md "$repo/memory/MEMORY.md"
fi

if [ -e "$repo/.claude/settings.json" ]; then
	echo "MERGE   .claude/settings.json exists: add the deny rules from templates/project-settings.json by hand"
else
	render project-settings.json "$repo/.claude/settings.json"
fi

if [ -e "$repo/CLAUDE.md" ] && grep -q 'memory/MEMORY.md' "$repo/CLAUDE.md"; then
	echo "kept    CLAUDE.md (already names memory/MEMORY.md)"
else
	[ -e "$repo/CLAUDE.md" ] || printf '# %s\n' "$name_repo" >"$repo/CLAUDE.md"
	cat "$src/CLAUDE-memory.md" >>"$repo/CLAUDE.md"
	echo "added   memory section to CLAUDE.md"
fi

left="$(grep -rlE '@(REPO|KEY|DEBIAN|GIT_NAME|GIT_EMAIL)@' "$dc" "$repo/.claude" "$repo/memory" || true)"
[ -z "$left" ] || die "placeholders left in: $left"
[ -f "$dc/claude-home/projects/$key/memory/MEMORY.md" ] || die "memory link does not resolve"
bash -n "$dc/initialize.sh" || die "initialize.sh has a syntax error"

# claude-home commits only its config and this project's memory link; the
# login, transcripts, personal skills and plugins stay local.
h=.devcontainer/claude-home
for p in .gitignore settings.json "projects/$key/memory"; do
	! git -C "$repo" check-ignore -q --no-index "$h/$p" || die "$h/$p would be ignored"
done
for p in .credentials.json .claude.json skills/x/SKILL.md plugins/installed_plugins.json \
	"projects/$key/t.jsonl" projects/-workspaces-other/memory; do
	git -C "$repo" check-ignore -q --no-index "$h/$p" || die "$h/$p would be committed"
done

echo
echo "Done. Repo mounts at /workspaces/$name_repo, Claude project key $key."
git -C "$repo" status --short --untracked-files=all
