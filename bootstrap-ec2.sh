#!/usr/bin/env bash
#
# Bootstrap a fresh Ubuntu 22.04 EC2 instance (x86_64, c7i.4xlarge recommended)
# to continue the agent-cppgm run.
#
# Usage on a fresh instance:
#   curl -fsSL https://raw.githubusercontent.com/waynekyamamoto/agent-cppgm/main/bootstrap-ec2.sh | bash
#
# Then log out and back in (so the docker group takes effect) and run:
#   cd ~/agent-cppgm && ./run.sh

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/waynekyamamoto/agent-cppgm.git}"
WORK_DIR="${WORK_DIR:-$HOME/agent-cppgm}"

echo "[1/3] Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
sudo usermod -aG docker "$USER"

echo "[2/3] Cloning repo to $WORK_DIR..."
if [ ! -d "$WORK_DIR" ]; then
    git clone "$REPO_URL" "$WORK_DIR"
fi

echo "[3/3] Done."
cat <<'EOF'

Next steps:
  1. Log out and back in (so the docker group applies to your shell):
       exit
       ssh ...
  2. Configure AWS credentials if needed:
       aws configure
  3. Configure GitHub auth if you plan to push from here:
       gh auth login
  4. Build the image and start the container:
       cd ~/agent-cppgm && ./run.sh

The first build takes a few minutes. Subsequent runs are instant.
EOF
