# Personal Devcontainer Toolkit

A reusable base devcontainer image and a set of composable devcontainer features.

## Structure

```
base/                        # Base devcontainer image (Dockerfile)
features/
  dbt-duckdb/                # dbt-core + DuckDB adapter feature
  k8s-tools/                 # kubectl, Helm, Kustomize feature
  postgres-client/           # PostgreSQL client (psql) feature
template/
  .devcontainer/             # Example project devcontainer.json
```

## Base Image

The base image (`base/Dockerfile`) includes:

- **Ubuntu 24.04** foundation
- **Python 3** + pip + [uv](https://github.com/astral-sh/uv)
- **Bun** (JavaScript runtime)
- **DuckDB** CLI and Python package
- Essential CLI tools: git, curl, wget, jq, ripgrep, fd, make, openssl, ssh

### Building

```bash
docker build -t ghcr.io/<your-user>/devcontainer-base:1.0.0 base/
```

### Publishing

```bash
docker push ghcr.io/<your-user>/devcontainer-base:1.0.0
```

## Features

Each feature lives under `features/<name>/` and contains:

| File                          | Purpose                                |
| ----------------------------- | -------------------------------------- |
| `devcontainer-feature.json`   | Metadata, options, and version info    |
| `install.sh`                  | Installation script run at build time  |

### Publishing Features

Use the [devcontainer CLI](https://github.com/devcontainers/cli) to package
and publish features to an OCI registry:

```bash
devcontainer features publish features/ \
  --registry ghcr.io \
  --namespace <your-user>/devcontainer-features
```

### Available Features

| Feature            | Description                              |
| ------------------ | ---------------------------------------- |
| `dbt-duckdb`       | dbt-core with the DuckDB adapter         |
| `k8s-tools`        | kubectl, Helm, Kustomize                 |
| `postgres-client`  | PostgreSQL client (`psql`)               |

## Usage

Copy `template/.devcontainer/devcontainer.json` into your project, replace
`<your-user>` with your registry namespace, and remove any features you don't
need. See the comments in the file for guidance.

## Versioning

Both the base image and features use explicit version pins. Update the version
tags when you make changes and push new releases.
