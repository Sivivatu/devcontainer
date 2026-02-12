#!/usr/bin/env bash
# ---------------------------------------------------------
# Feature: k8s-tools
# Installs kubectl, Helm, and Kustomize.
# ---------------------------------------------------------
set -euo pipefail

KUBECTL_VERSION="${KUBECTLVERSION:-1.32.2}"
HELM_VERSION="${HELMVERSION:-3.17.1}"
KUSTOMIZE_VERSION="${KUSTOMIZEVERSION:-5.6.0}"

ARCH="$(dpkg --print-architecture)"

# Map Debian arch names to upstream naming conventions
case "${ARCH}" in
    amd64) GO_ARCH="amd64" ;;
    arm64) GO_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

apt-get update -y
apt-get install -y --no-install-recommends curl ca-certificates
rm -rf /var/lib/apt/lists/*

# ---- kubectl ----
echo "Installing kubectl ${KUBECTL_VERSION}..."
curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${GO_ARCH}/kubectl" \
    -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
kubectl version --client

# ---- Helm ----
echo "Installing Helm ${HELM_VERSION}..."
curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${GO_ARCH}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "linux-${GO_ARCH}/helm"
chmod +x /usr/local/bin/helm
helm version

# ---- Kustomize ----
echo "Installing Kustomize ${KUSTOMIZE_VERSION}..."
curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${GO_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin
chmod +x /usr/local/bin/kustomize
kustomize version

echo "k8s-tools feature installed successfully."
