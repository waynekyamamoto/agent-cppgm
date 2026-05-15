#!/usr/bin/env bash
#
# Unified entry point for the agent-cppgm container.
# The container is the full work environment: toolchain + Claude + gh + aws.
# Run ./run.sh to land in a shell at /work/agent-cppgm; from there, run
# `claude` and give it the AGENTS.md prompt.
#
# Usage:
#   ./run.sh                 # open an interactive shell in the container
#   ./run.sh shell           # same as above
#   ./run.sh build           # (re)build the Docker image
#   ./run.sh rm              # remove the container (image preserved)
#   ./run.sh <cmd> [args...] # exec a one-off command inside the container

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="agent-cppgm:latest"
CONTAINER="agent-cppgm"

build_image() {
    echo "Building $IMAGE (linux/amd64)..." >&2
    docker build \
        --platform=linux/amd64 \
        --build-arg HOST_UID="$(id -u)" \
        --build-arg HOST_GID="$(id -g)" \
        -t "$IMAGE" \
        "$REPO_ROOT"
}

ensure_image() {
    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        build_image
    fi
}

ensure_container_running() {
    ensure_image
    if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
        return
    fi
    if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
        docker start "$CONTAINER" >/dev/null
        return
    fi
    # First run: assemble mounts and create the container detached.
    local mounts=( -v "$REPO_ROOT:/work/agent-cppgm" )
    [ -d "$HOME/.aws" ]        && mounts+=( -v "$HOME/.aws:/home/agent/.aws:ro" )
    [ -d "$HOME/.claude" ]     && mounts+=( -v "$HOME/.claude:/home/agent/.claude" )
    [ -d "$HOME/.config/gh" ]  && mounts+=( -v "$HOME/.config/gh:/home/agent/.config/gh" )
    docker run -d \
        --name "$CONTAINER" \
        --platform=linux/amd64 \
        --hostname agent-cppgm \
        "${mounts[@]}" \
        -w /work/agent-cppgm \
        "$IMAGE" \
        sleep infinity >/dev/null
}

case "${1:-shell}" in
    build)
        build_image
        ;;
    rm)
        docker rm -f "$CONTAINER" 2>/dev/null || true
        echo "Removed container $CONTAINER (image preserved)."
        ;;
    shell)
        ensure_container_running
        exec docker exec -it -w /work/agent-cppgm "$CONTAINER" /bin/bash -l
        ;;
    *)
        ensure_container_running
        if [ -t 1 ]; then
            exec docker exec -it -w /work/agent-cppgm "$CONTAINER" "$@"
        else
            exec docker exec -i -w /work/agent-cppgm "$CONTAINER" "$@"
        fi
        ;;
esac
