#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-claude-code}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    echo "Error: ANTHROPIC_AUTH_TOKEN environment variable is not set." >&2
    echo "Usage: ANTHROPIC_AUTH_TOKEN=sk-xxx ./build.sh" >&2
    exit 1
fi

echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} (plugins will be installed during build)"

docker build \
    --secret id=anthropic_token,env=ANTHROPIC_AUTH_TOKEN \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    .

echo ""
echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Pre-installed plugins:"
echo "  - ECC (Everything-Claude-Code)"
echo "  - Claude Plugins Official (code-review, feature-dev, security, LSP servers...)"
echo "  - Playwright MCP Server"
echo ""
echo "Usage:"
echo "  docker run -it --rm \\"
echo "    -e ANTHROPIC_AUTH_TOKEN=sk-xxx \\"
echo "    -e WORKSPACE_HOST_PATH=\$(pwd) \\"
echo "    -v \$(pwd):/workspace \\"
echo "    -v ~/.claude/projects/Container:/root/.claude/projects/Container \\"
echo "    ${IMAGE_NAME}:${IMAGE_TAG} \"review this code\""
