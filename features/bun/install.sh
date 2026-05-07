#!/usr/bin/env bash
# ---------------------------------------------------------
# Feature: bun
# Installs the Bun JavaScript runtime and package manager.
# ---------------------------------------------------------
set -euo pipefail

BUN_VERSION="${BUNVERSION:-latest}"

apt-get update -y
apt-get install -y --no-install-recommends curl ca-certificates unzip
rm -rf /var/lib/apt/lists/*

if [ "${BUN_VERSION}" = "latest" ]; then
    echo "Installing latest Bun..."
    curl -fsSL https://bun.sh/install | bash -s --
else
    normalized_version="${BUN_VERSION#bun-v}"
    echo "Installing Bun ${normalized_version}..."
    curl -fsSL https://bun.sh/install | bash -s -- "bun-v${normalized_version}"
fi

mv /root/.bun/bin/bun /usr/local/bin/bun
ln -sf /usr/local/bin/bun /usr/local/bin/bunx
rm -rf /root/.bun

bun --version

echo "bun feature installed successfully."
