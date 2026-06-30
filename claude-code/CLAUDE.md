# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker build context for packaging `@anthropic-ai/claude-code` CLI with development tools, plugins (ECC + claude-plugins-official), and Playwright MCP into a container image. Designed for Rust/Go/C/Python3/Bash code analysis and CI/CD workflows.

The LLM backend uses **Qwen models via Alibaba DashScope** (`ANTHROPIC_BASE_URL` points to `dashscope.aliyuncs.com`), not the Anthropic API directly. All model slots (haiku/sonnet/opus/subagent) map to Qwen models configured in `settings.json`.

## Build & Run

```bash
# Build (ANTHROPIC_AUTH_TOKEN required — passed as BuildKit secret, not stored in image)
ANTHROPIC_AUTH_TOKEN=sk-xxx ./build.sh

# Build via Docker Compose
docker compose build

# Run
docker run -it --rm \
  -e ANTHROPIC_AUTH_TOKEN=sk-xxx \
  -e WORKSPACE_HOST_PATH=$(pwd) \
  -v $(pwd):/workspace \
  -v ~/.claude/projects/Container:/root/.claude/projects/Container \
  claude-code:latest "review this code"

# Run via Docker Compose
CLAUDE_WORKSPACE=/path/to/project \
ANTHROPIC_AUTH_TOKEN=sk-xxx \
docker compose run --rm claude-code "review this code"
```

`WORKSPACE_HOST_PATH` is **required** at runtime — the entrypoint uses its basename to derive the container project name for persisting Claude's project data across runs.

## Architecture

**Multi-stage build** — the builder stage (Stage 1) uses a real API token via BuildKit `--mount=type=secret` to trigger plugin installation by running `claude -p "hello"`. The final stage (Stage 2) copies only the installed plugins directory (`/root/.claude/plugins`) — no secrets are baked into the image.

- `builder-settings.json` — minimal settings used only during the builder stage (token injected at build time via `jq`)
- `settings.json` — full runtime config (env vars, plugins, MCP servers); copied into the final image with placeholder token `YOUR_API_KEY`
- `docker-entrypoint.sh` — replaces the placeholder token with the real `ANTHROPIC_AUTH_TOKEN` env var at startup, validates `/workspace` is a mounted volume, creates a symlink so Claude's internal `-workspace` project path resolves to a persistent host-mounted directory named after the repo basename

**Layer caching strategy**: system deps (rarely change) → claude-code install (changes on version bump) → plugin copy / runtime config (most volatile, placed last).

**Regional mirrors**: Aliyun for apt, Taobao/npmmirror for npm — intended for use on Chinese infrastructure.

**Runs as root** to simplify volume mount permissions for arbitrary host directories.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build (`node:26-bookworm-slim` base) |
| `build.sh` | Build wrapper; passes `ANTHROPIC_AUTH_TOKEN` as BuildKit secret |
| `builder-settings.json` | Builder-stage settings (token injected at build time) |
| `settings.json` | Runtime settings: model config, plugins, MCP servers |
| `claude.json` | Onboarding flag (`hasCompletedOnboarding: true`) |
| `docker-entrypoint.sh` | Startup: volume check, token injection, project dir symlink |
| `docker-compose.yml` | Compose config with secrets and volume mounts |
