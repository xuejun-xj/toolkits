#!/usr/bin/env bash
set -e

# Require /workspace to be a mounted volume
if ! mountpoint -q /workspace 2>/dev/null; then
    echo "Error: /workspace is not a mounted volume." >&2
    echo "Please mount your repository with -v, e.g.:" >&2
    echo "  docker run -it --rm -v \$(pwd):/workspace ..." >&2
    exit 1
fi

SETTINGS="/root/.claude/settings.json"

if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    tmp=$(mktemp)
    jq --arg token "$ANTHROPIC_AUTH_TOKEN" '.env.ANTHROPIC_AUTH_TOKEN = $token' "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
fi

# Redirect Claude Code project data to persistent host volume
# Uses host repo absolute path as container name (basename)
# e.g. /Users/xuejun/code/project-alpha → Container/project-alpha/
if [ -z "${WORKSPACE_HOST_PATH:-}" ]; then
    echo "Error: WORKSPACE_HOST_PATH is required." >&2
    echo "  e.g. -e WORKSPACE_HOST_PATH=/Users/xuejun/code/my-repo" >&2
    exit 1
fi

CONTAINER_NAME="$(basename "$WORKSPACE_HOST_PATH")"
PROJECTS_DIR="/root/.claude/projects"
NAMESPACED_DIR="$PROJECTS_DIR/Container/$CONTAINER_NAME"
WORKSPACE_PROJECT="$PROJECTS_DIR/-workspace"

mkdir -p "$NAMESPACED_DIR"
[ ! -e "$WORKSPACE_PROJECT" ] && ln -s "$NAMESPACED_DIR/-workspace" "$WORKSPACE_PROJECT"

exec claude "$@"
