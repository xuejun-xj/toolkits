# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker build context for a container image that packages `@anthropic-ai/claude-code` CLI with common development tools, Playwright MCP, and the ECC plugin, intended for Rust/Go/C/Python3/Bash code analysis and CI/CD workflows.

## Build & Run

```bash
# Build
ANTHROPIC_AUTH_TOKEN=sk-xxx ./build.sh

# Or via Docker Compose (Docker Desktop)
docker compose build

# Run: analyze code in current directory
docker run -it --rm \
  -e ANTHROPIC_AUTH_TOKEN=sk-xxx \
  -v $(pwd):/workspace \
  claude-code:latest "review this code"

# Run via Docker Compose
CLAUDE_WORKSPACE=/path/to/project \
ANTHROPIC_AUTH_TOKEN=sk-xxx \
GITHUB_PAT=ghp-xxx \
docker compose run --rm claude-code "review this code"
```

## Architecture

- **Base image**: `node:22-bookworm-slim` — Node.js 26 + glibc compatibility with native npm modules
- **System tools**: git, ripgrep, fd-find, python3, jq, make/g++ (for native module compilation)
- **Config injection**: `settings.json` and `claude.json` are COPYed into the image; `docker-entrypoint.sh` dynamically replaces placeholder tokens with real ones from environment variables at startup
- **MCP Servers**: Playwright (stdio, no auth needed)
- **Plugins**: ECC (Everything-Claude-Code) + Claude Plugins Official (code-review, feature-dev, security, LSP servers for Rust/Go/Python/C)
- **Runs as root**: simplifies volume mount permissions for arbitrary host directories
- **Entrypoint**: validates `/workspace` is a mounted volume, injects tokens, then `exec claude "$@"`
- **Multi-stage build**: builder stage uses real API token to pre-install all plugins; final stage has no secrets baked in

## Files

| File | Purpose |
|------|---------|
| `settings.json` | Claude Code env vars, MCP servers, plugins config (edit before build) |
| `claude.json` | Onboarding flag |
| `docker-entrypoint.sh` | Startup: volume check + token injection |
| `docker-compose.yml` | Docker Desktop integration |
| `.env.example` | Environment variable template |
