#!/usr/bin/env bash
# ---------------------------------------------------------
# Feature: duckdb
# Installs the DuckDB command-line client.
# ---------------------------------------------------------
set -euo pipefail

DUCKDB_VERSION="${DUCKDBVERSION:-latest}"

apt-get update -y
apt-get install -y --no-install-recommends curl ca-certificates
rm -rf /var/lib/apt/lists/*

if [ "${DUCKDB_VERSION}" = "latest" ]; then
    echo "Installing latest DuckDB CLI..."
    curl -fsSL https://install.duckdb.org | sh
else
    echo "Installing DuckDB CLI ${DUCKDB_VERSION}..."
    curl -fsSL https://install.duckdb.org | sh -s -- "v${DUCKDB_VERSION#v}"
fi

if ! command -v duckdb > /dev/null 2>&1 && [ -x /root/.duckdb/cli/latest/duckdb ]; then
    install -m 0755 /root/.duckdb/cli/latest/duckdb /usr/local/bin/duckdb
fi

duckdb --version

echo "duckdb feature installed successfully."
