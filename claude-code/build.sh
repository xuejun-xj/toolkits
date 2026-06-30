#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-claude-code}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-false}"

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    echo "Error: ANTHROPIC_AUTH_TOKEN environment variable is not set." >&2
    echo "Usage: ANTHROPIC_AUTH_TOKEN=sk-xxx ./build.sh" >&2
    exit 1
fi

# Ensure buildx builder exists
BUILDER_NAME="multiplatform-builder"
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo "==> Creating buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --use
else
    docker buildx use "$BUILDER_NAME"
fi

echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} for platforms: ${PLATFORMS}"

BUILD_ARGS=(
    --platform "$PLATFORMS"
    --secret id=anthropic_token,env=ANTHROPIC_AUTH_TOKEN
    -t "${IMAGE_NAME}:${IMAGE_TAG}"
)

if [ "$PUSH" = "true" ]; then
    BUILD_ARGS+=(--push)
    docker buildx build "${BUILD_ARGS[@]}" .

    echo ""
    echo "Build and push complete: ${IMAGE_NAME}:${IMAGE_TAG}"
else
    # Multi-platform images cannot use --load; export as OCI tarball
    OUTPUT_DIR="${OUTPUT_DIR:-.}"
    OUTPUT_FILE="${OUTPUT_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"
    mkdir -p "$OUTPUT_DIR"

    docker buildx build \
        --output "type=oci,dest=${OUTPUT_FILE}" \
        "${BUILD_ARGS[@]}" .

    echo ""
    echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo "OCI tarball: ${OUTPUT_FILE}"
    echo ""
    echo "To load into Docker (single platform only):"
    echo "  docker load < ${OUTPUT_FILE}"
    echo ""
    echo "To push to a registry:"
    echo "  PUSH=true ./build.sh"
    echo "  # or: PUSH=true IMAGE_NAME=registry.example.com/claude-code ./build.sh"
fi

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
