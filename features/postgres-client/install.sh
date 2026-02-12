#!/usr/bin/env bash
# ---------------------------------------------------------
# Feature: postgres-client
# Installs the PostgreSQL client (psql) from the official
# PostgreSQL APT repository.
# ---------------------------------------------------------
set -euo pipefail

POSTGRES_VERSION="${POSTGRESVERSION:-17}"

echo "Installing PostgreSQL ${POSTGRES_VERSION} client (psql)..."

apt-get update -y
apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

# Add the official PostgreSQL APT repository
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] \
https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

apt-get update -y
apt-get install -y --no-install-recommends "postgresql-client-${POSTGRES_VERSION}"
rm -rf /var/lib/apt/lists/*

# Verify installation
psql --version

echo "postgres-client feature installed successfully."
