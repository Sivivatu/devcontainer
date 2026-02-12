# Personal Devcontainer Toolkit

[![CI/CD Pipeline](https://github.com/<your-user>/devcontainer/actions/workflows/ci.yml/badge.svg)](https://github.com/<your-user>/devcontainer/actions/workflows/ci.yml)

A reusable base devcontainer image and a set of composable devcontainer features with automated CI/CD.

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

## CI/CD Pipeline

The project includes a GitHub Actions workflow that automatically:

- **Lints and formats** all code (shellcheck, hadolint, shfmt, jq)
- **Runs the full test suite** (base image + all features)
- **Publishes the base image** to GitHub Container Registry
- **Publishes features** as OCI artifacts

### Automated Publishing

The workflow publishes images and features automatically:

| Event               | Base Image Tags                          | Features Published |
| ------------------- | ---------------------------------------- | ------------------ |
| Push to `main`      | `latest`, `main-<sha>`                   | ✅ Yes             |
| Push tag `v1.2.3`   | `v1.2.3`, `1.2`, `1`, `<sha>`            | ✅ Yes             |
| Pull request        | *(not published)*                        | ❌ No              |

### Versioning & Releases

To publish a new version:

1. Update version in feature `devcontainer-feature.json` files
2. Commit changes: `git commit -am "chore: bump version to 1.2.3"`
3. Create and push a tag: `git tag v1.2.3 && git push origin v1.2.3`
4. GitHub Actions will automatically build, test, and publish

### Local Testing

Before pushing, validate locally:

```bash
make check    # Run linting and format checks
make test     # Run the full test suite
```

## Base Image

The base image (`base/Dockerfile`) includes:

- **Ubuntu 24.04** foundation
- **Python 3** + pip + [uv](https://github.com/astral-sh/uv)
- **Bun** (JavaScript runtime)
- **DuckDB** CLI and Python package
- Essential CLI tools: git, curl, wget, jq, ripgrep, fd, make, openssl, ssh

### Using the Base Image

The base image is automatically published to GitHub Container Registry. Reference it in your project:

```json
{
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:latest"
}
```

### Manual Build & Publish (Optional)

If you need to build/publish manually:

```bash
docker build -t ghcr.io/<your-user>/devcontainer-base:1.0.0 base/
docker push ghcr.io/<your-user>/devcontainer-base:1.0.0
```

## Features

Each feature lives under `features/<name>/` and contains:

| File                          | Purpose                                |
| ----------------------------- | -------------------------------------- |
| `devcontainer-feature.json`   | Metadata, options, and version info    |
| `install.sh`                  | Installation script run at build time  |

### Available Features

| Feature            | Description                              |
| ------------------ | ---------------------------------------- |
| `dbt-duckdb`       | dbt-core with the DuckDB adapter         |
| `k8s-tools`        | kubectl, Helm, Kustomize                 |
| `postgres-client`  | PostgreSQL client (`psql`)               |

### Using Features

Features are automatically published to GitHub Container Registry. Reference them in your `devcontainer.json`:

```json
{
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:latest",
  "features": {
    "ghcr.io/<your-user>/devcontainer-features/dbt-duckdb:1": {},
    "ghcr.io/<your-user>/devcontainer-features/k8s-tools:1": {}
  }
}
```

### Manual Feature Publishing (Optional)

Use the [devcontainer CLI](https://github.com/devcontainers/cli) to publish manually:

```bash
devcontainer features publish features/ \
  --registry ghcr.io \
  --namespace <your-user>/devcontainer-features
```

## Usage

Reference the published base image and features in your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Project",
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:latest",
  "features": {
    "ghcr.io/<your-user>/devcontainer-features/dbt-duckdb:1": {
      "dbtCoreVersion": "1.9.1"
    },
    "ghcr.io/<your-user>/devcontainer-features/postgres-client:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": ["ms-python.python"]
    }
  }
}
```

See `template/.devcontainer/` for a complete example with all features.

## Development

### Adding a New Feature

1. Create `features/<feature-name>/devcontainer-feature.json` with metadata
2. Create `features/<feature-name>/install.sh` with installation logic
3. Add test case in `tests/test.sh` (follow `test_feature_*` pattern)
4. Add Makefile target for testing the feature
5. Run `make test-<feature-name>` to verify

### Making Changes

1. Make your changes to base image or features
2. Run `make check` to lint and verify formatting
3. Run `make test` to run the full test suite locally
4. Commit and push to a branch (CI will validate on PR)
5. Merge to `main` to publish development versions
6. Tag a release when ready: `git tag v1.2.3 && git push origin v1.2.3`

### Project Conventions

- **Shell scripts**: 4-space indent, checked with shellcheck and formatted with shfmt
- **Dockerfiles**: Ubuntu 24.04 base, non-root `dev` user, cleaned apt cache
- **Features**: Isolated installs in `/opt/<feature>/`, PATH configured in feature JSON
- **Testing**: Every feature must have tests verifying installation and base tool preservation

