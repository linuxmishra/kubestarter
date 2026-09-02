#!/bin/bash

set -e
set -o pipefail

echo "🚀 Starting installation of Docker, Kind, and kubectl on RHEL..."

# ----------------------------
# 0. Check root/sudo access
# ----------------------------
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &>/dev/null; then
        echo "❌ Please run this script as root or install sudo."
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# ----------------------------
# 1. Install required packages
# ----------------------------
echo "📦 Installing required packages..."

$SUDO dnf install -y \
    curl \
    wget \
    ca-certificates \
    gnupg2 \
    yum-utils \
    device-mapper-persistent-data \
    lvm2

echo "✅ Required packages installed."

# ----------------------------
# 2. Install Docker
# ----------------------------
if ! command -v docker &>/dev/null; then

    echo "📦 Installing Docker..."

    # Remove old/conflicting Docker packages if present
    $SUDO dnf remove -y \
        docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine \
        podman \
        runc 2>/dev/null || true

    # Add Docker official repository
    $SUDO dnf config-manager \
        --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

    # Install Docker
    $SUDO dnf install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    echo "✅ Docker installed successfully."

else
    echo "✅ Docker is already installed."
fi

# ----------------------------
# 3. Enable and Start Docker
# ----------------------------
echo "🔧 Enabling Docker service..."

$SUDO systemctl enable --now docker

if systemctl is-active --quiet docker; then
    echo "✅ Docker service is running."
else
    echo "❌ Docker service failed to start."
    $SUDO systemctl status docker --no-pager
    exit 1
fi

# ----------------------------
# 4. Add current user to docker group
# ----------------------------
CURRENT_USER="${SUDO_USER:-$USER}"

if id "$CURRENT_USER" &>/dev/null; then

    echo "👤 Adding $CURRENT_USER to docker group..."

    $SUDO groupadd -f docker
    $SUDO usermod -aG docker "$CURRENT_USER"

    echo "✅ User $CURRENT_USER added to docker group."
    echo "⚠️ Log out and log back in for the group change to take effect."

else
    echo "⚠️ Unable to determine current user."
fi

# ----------------------------
# 5. Install Kind
# ----------------------------
if ! command -v kind &>/dev/null; then

    echo "📦 Installing Kind..."

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            KIND_ARCH="amd64"
            ;;
        aarch64|arm64)
            KIND_ARCH="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    KIND_VERSION="v0.29.0"

    curl -Lo /tmp/kind \
        "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KIND_ARCH}"

    chmod +x /tmp/kind

    $SUDO mv /tmp/kind /usr/local/bin/kind

    echo "✅ Kind installed successfully."

else
    echo "✅ Kind is already installed."
fi

# ----------------------------
# 6. Install kubectl
# ----------------------------
if ! command -v kubectl &>/dev/null; then

    echo "📦 Installing kubectl..."

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            KUBECTL_ARCH="amd64"
            ;;
        aarch64|arm64)
            KUBECTL_ARCH="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)

    echo "📌 Installing kubectl version: $VERSION"

    curl -Lo /tmp/kubectl \
        "https://dl.k8s.io/release/${VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"

    chmod +x /tmp/kubectl

    $SUDO mv /tmp/kubectl /usr/local/bin/kubectl

    echo "✅ kubectl installed successfully."

else
    echo "✅ kubectl is already installed."
fi

# ----------------------------
# 7. Verify installations
# ----------------------------
echo
echo "======================================"
echo "🔍 Installation Verification"
echo "======================================"

echo
echo "🐳 Docker:"
docker --version

echo
echo "☸️ Kind:"
kind --version

echo
echo "☸️ kubectl:"
kubectl version --client

echo
echo "🔧 Docker Service:"
$SUDO systemctl is-active docker

echo
echo "======================================"
echo "🎉 Installation Complete!"
echo "======================================"

echo
echo "⚠️ IMPORTANT:"
echo "If you were added to the docker group, log out and log back in."
echo
echo "Then verify Docker without sudo:"
echo
echo "    docker ps"
echo
echo "You can then create a Kind cluster using:"
echo
echo "    kind create cluster"
