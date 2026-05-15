#!/usr/bin/env bash
#
# Driver for the agent-cppgm build sandbox.
# The agent (Claude) runs on the host. This script runs build/test
# commands inside the linux/amd64 container.
#
# Usage:
#   ./run.sh                 # open an interactive shell in the container
#   ./run.sh shell           # same as above
#   ./run.sh build           # (re)build the Docker image
#   ./run.sh rm              # remove the container (image preserved)
#   ./run.sh <cmd> [args...] # run a command inside the container, e.g.
#                              ./run.sh make
#                              ./run.sh make test
#                              ./run.sh bash -c "cd pa1 && make test"

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
    if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
        if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
            docker start "$CONTAINER" >/dev/null
        else
            # First run: create the container detached, sleeping forever,
            # so subsequent invocations are fast `docker exec` calls.
            docker run -d \
                --name "$CONTAINER" \
                --platform=linux/amd64 \
                --hostname agent-cppgm \
                -v "$REPO_ROOT:/work/agent-cppgm" \
                -w /work/agent-cppgm \
                "$IMAGE" \
                sleep infinity >/dev/null
        fi
    fi
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
        # Forward the command + args into the container.
        # Use -t only when stdout is a tty so output piping still works.
        if [ -t 1 ]; then
            exec docker exec -it -w /work/agent-cppgm "$CONTAINER" "$@"
        else
            exec docker exec -i -w /work/agent-cppgm "$CONTAINER" "$@"
        fi
        ;;
esac
