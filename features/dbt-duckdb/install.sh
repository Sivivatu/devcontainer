#!/usr/bin/env bash
# ---------------------------------------------------------
# Feature: dbt-duckdb
# Installs dbt-core and the dbt-duckdb adapter into a
# dedicated virtual environment at /opt/dbt.
# ---------------------------------------------------------
set -euo pipefail

DBT_CORE_VERSION="${DBTCOREVERSION:-1.9.1}"
DBT_DUCKDB_VERSION="${DBTDUCKDBVERSION:-1.9.1}"

echo "Installing dbt-core ${DBT_CORE_VERSION} with dbt-duckdb ${DBT_DUCKDB_VERSION}..."

# Ensure python3 and venv module are available
apt-get update -y
apt-get install -y --no-install-recommends python3 python3-pip python3-venv
rm -rf /var/lib/apt/lists/*

# Create an isolated virtual environment
python3 -m venv /opt/dbt

/opt/dbt/bin/pip install --no-cache-dir \
    "dbt-core==${DBT_CORE_VERSION}" \
    "dbt-duckdb==${DBT_DUCKDB_VERSION}"

# Verify installation
/opt/dbt/bin/dbt --version

echo "dbt-duckdb feature installed successfully."
