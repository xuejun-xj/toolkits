#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-claude-code}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-false}"
USE_BUILDX="${USE_BUILDX:-}"  # auto-detect if unset

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    echo "Error: ANTHROPIC_AUTH_TOKEN environment variable is not set." >&2
    echo "Usage: ANTHROPIC_AUTH_TOKEN=sk-xxx ./build.sh" >&2
    exit 1
fi

# Determine build strategy:
# - buildx docker-container driver cannot reach Docker Hub auth from some networks (e.g. China)
# - docker build (BuildKit) works with locally cached images but only supports the host platform
# Auto-detect: use buildx only for multi-platform, docker build for single-platform
need_multiplatform() {
    local count
    count=$(echo "$PLATFORMS" | tr ',' '\n' | wc -l | tr -d ' ')
    [ "$count" -gt 1 ]
}

ensure_buildx_builder() {
    local builder_name="multiplatform-builder"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_arg=""
    [ -f "$script_dir/buildkitd.toml" ] && config_arg="--config $script_dir/buildkitd.toml"

    if ! docker buildx inspect "$builder_name" &>/dev/null; then
        echo "==> Creating buildx builder: $builder_name"
        if [ -n "$config_arg" ]; then
            echo "    Using registry mirror config from buildkitd.toml"
            docker buildx create --name "$builder_name" --use $config_arg
        else
            docker buildx create --name "$builder_name" --use
        fi
    else
        docker buildx use "$builder_name"
    fi
}

# Decide: buildx or docker build
if [ -z "$USE_BUILDX" ]; then
    if need_multiplatform; then
        USE_BUILDX=true
    else
        USE_BUILDX=false
    fi
fi

if [ "$USE_BUILDX" = "true" ]; then
    ensure_buildx_builder
    echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} via buildx for platforms: ${PLATFORMS}"

    BUILD_ARGS=(
        --platform "$PLATFORMS"
        --provenance=false
        --sbom=false
        --secret id=anthropic_token,env=ANTHROPIC_AUTH_TOKEN
        -t "${IMAGE_NAME}:${IMAGE_TAG}"
    )

    if [ "$PUSH" = "true" ]; then
        BUILD_ARGS+=(--push)
        docker buildx build "${BUILD_ARGS[@]}" .
        echo ""
        echo "Build and push complete: ${IMAGE_NAME}:${IMAGE_TAG}"
    else
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
else
    echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} via docker build (single platform)"

    DOCKER_BUILDKIT=1 docker build \
        --provenance=false \
        --sbom=false \
        --secret id=anthropic_token,env=ANTHROPIC_AUTH_TOKEN \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        .

    echo ""
    echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"

    if [ "$PUSH" = "true" ]; then
        echo "==> Pushing ${IMAGE_NAME}:${IMAGE_TAG}..."
        docker push "${IMAGE_NAME}:${IMAGE_TAG}"
        echo "Push complete."
    fi
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
