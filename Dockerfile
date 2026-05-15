# syntax=docker/dockerfile:1.6
#
# Unified linux/amd64 environment for the agent-cppgm course.
# Pinned to linux/amd64 because PA9 codegen, the *-ref reference binaries,
# and the course ABI all target x86-64. Runs natively on EC2 x86-64;
# runs under Rosetta on Apple Silicon (requires Docker Desktop 4.25+).
#
# Contains both the build toolchain and the agent (Claude Code), so the
# entire workflow lives inside the container: ./run.sh drops you into a
# shell where `make`, `claude`, `gh`, and `aws` are all available.

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
      python3-pip \
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
      unzip \
      sudo \
      gnupg \
      lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 + Claude Code CLI.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && rm -rf /var/lib/apt/lists/*

# AWS CLI v2 (x86_64 binary; matches the image platform).
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws

# GitHub CLI.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Non-root user whose UID/GID match the host so files on the mounted
# volume show up with the host user's ownership.
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
