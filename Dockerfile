# syntax=docker/dockerfile:1.6
#
# Build sandbox for the agent-cppgm course.
# Pinned to linux/amd64 because:
#   - PA9 codegen targets x86-64
#   - the committed *-ref reference binaries are x86-64 ELF
#   - the course assumes the System V x86-64 ABI throughout
# Native on EC2 x86-64; runs under emulation on Apple Silicon.
#
# This image is intentionally a *build sandbox*, not an agent host.
# Claude / the agent runs on the host machine and uses `./run.sh` to
# execute builds and tests inside this container. Keeping Node/V8 out
# of the image avoids the QEMU-amd64 + V8 CodeRange OOM that breaks
# `npm install` under older Docker Desktop on Apple Silicon.

FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Toolchain + course-required utilities + operator quality of life.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      binutils \
      git \
      make \
      perl \
      python3 \
      diffutils \
      grep \
      sed \
      gawk \
      xxd \
      file \
      bc \
      gdb \
      strace \
      ltrace \
      valgrind \
      vim-tiny \
      less \
      tmux \
      curl \
      ca-certificates \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Non-root user whose UID/GID match the host so files on the mounted
# volume show up with the host user's ownership. Drop any pre-baked
# user that collides with the requested UID before creating ours.
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu 2>/dev/null || true; fi \
    && (getent group ${HOST_GID} >/dev/null || groupadd -g ${HOST_GID} agent) \
    && useradd -m -s /bin/bash -u ${HOST_UID} -g ${HOST_GID} agent \
    && echo "agent ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

USER agent
WORKDIR /work/agent-cppgm

CMD ["/bin/bash", "-l"]
