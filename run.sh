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
    # Pull host auth state at runtime: gh token from keychain (on macOS) and
    # git identity from host git config. These flow in as env vars and are
    # never baked into the image.
    local gh_token=""
    if command -v gh >/dev/null 2>&1; then
        gh_token="$(gh auth token 2>/dev/null || true)"
    fi
    local git_name="$(git config --global user.name 2>/dev/null || true)"
    local git_email="$(git config --global user.email 2>/dev/null || true)"

    local mounts=( -v "$REPO_ROOT:/work/agent-cppgm" )
    [ -d "$HOME/.claude" ]     && mounts+=( -v "$HOME/.claude:/home/agent/.claude" )
    [ -d "$HOME/.config/gh" ]  && mounts+=( -v "$HOME/.config/gh:/home/agent/.config/gh" )

    local envs=()
    [ -n "$gh_token" ]  && envs+=( -e "GH_TOKEN=$gh_token" -e "GITHUB_TOKEN=$gh_token" )
    [ -n "$git_name" ]  && envs+=( -e "GIT_AUTHOR_NAME=$git_name"  -e "GIT_COMMITTER_NAME=$git_name" )
    [ -n "$git_email" ] && envs+=( -e "GIT_AUTHOR_EMAIL=$git_email" -e "GIT_COMMITTER_EMAIL=$git_email" )

    docker run -d \
        --name "$CONTAINER" \
        --platform=linux/amd64 \
        --hostname agent-cppgm \
        "${mounts[@]}" \
        "${envs[@]}" \
        -w /work/agent-cppgm \
        "$IMAGE" \
        sleep infinity >/dev/null

    # One-time setup inside the container: git identity + gh credential helper.
    docker exec -u agent "$CONTAINER" bash -c "
        set -e
        [ -n \"${git_name}\" ]  && git config --global user.name  \"${git_name}\"
        [ -n \"${git_email}\" ] && git config --global user.email \"${git_email}\"
        if [ -n \"\$GH_TOKEN\" ]; then
            gh auth setup-git 2>/dev/null || true
        fi
        true
    " >/dev/null 2>&1 || true
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
