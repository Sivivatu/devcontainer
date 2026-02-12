# Devcontainer Toolkit – AI Coding Agent Instructions

## Project Overview

A personal devcontainer toolkit providing:
- **Base image** (`base/`): Ubuntu 24.04 + Python + Bun + DuckDB + essential CLI tools
- **Composable features** (`features/`): Modular add-ons (dbt-duckdb, k8s-tools, postgres-client)
- **Template** (`template/`): Example usage with multi-feature composition

Features publish to OCI registries and layer onto the base image for project-specific environments.

## Architecture

```
base/Dockerfile              → Base image (Python, Bun, DuckDB, CLI tools)
features/<name>/
  devcontainer-feature.json  → Metadata, options, version, PATH additions
  install.sh                 → Runs at build time to install feature tools
template/.devcontainer/      → Example showing how projects consume base + features
tests/test.sh                → Build & verify images with in-container assertions
```

**Key Design**: Features install into isolated paths (e.g., `/opt/dbt/bin/`) to avoid conflicts. The base image creates a non-root user `dev` (UID 1001) with passwordless sudo.

## Developer Workflows

### Testing (Primary Workflow)
```bash
make test                # Full suite: base + all features + combined
make test-base           # Base image only (tools + user setup)
make test-dbt-duckdb     # Single feature layered on base
make test-features       # All features (skips base tool checks)
```

Test workflow: Build `devcontainer-base:test` → Layer features via temporary Dockerfiles → Run in-container assertions (`docker run --rm <image> <command>`). Tests verify tool presence, versions, and that base tools survive feature installation.

### Linting & Formatting
```bash
make lint                # shellcheck + hadolint + jq validation
make fmt                 # shfmt formatting (in-place)
make fmt-check           # Verify formatting (CI-safe)
make check               # Lint + fmt-check (full CI target)
```

**Shell style**: 4-space indent, binary ops at line start, case indent, redirect follows (`shfmt -i 4 -bn -ci -sr`). EditorConfig defines cross-file formatting rules.

### Building & Publishing
```bash
# Base image
docker build -t ghcr.io/<user>/devcontainer-base:1.0.0 base/
docker push ghcr.io/<user>/devcontainer-base:1.0.0

# Features
devcontainer features publish features/ \
  --registry ghcr.io \
  --namespace <user>/devcontainer-features
```

## Project-Specific Conventions

### Shell Scripts
- **Dialect**: Bash (enforced by shellcheck)
- **Disabled checks**: SC2034 (unused vars in sourced scripts), SC1091 (don't follow sources)
- **Error handling**: `set -euo pipefail` in all scripts
- **Colour output**: Test scripts use ANSI codes with reset (`_colour_cyan`, `_colour_reset`)
- **Feature install.sh**: Reads devcontainer-feature.json options as uppercase env vars (e.g., `DBTCOREVERSION`)

### Dockerfiles
- **Base**: Always Ubuntu 24.04
- **User**: Create non-root `dev` user with sudo access, set as default
- **Locale**: en_GB.UTF-8
- **Cleanup**: Always `rm -rf /var/lib/apt/lists/*` after apt-get, use `--no-cache-dir` for pip
- **Hadolint**: Ignored rules DL3008 (apt version pins), DL3013 (pip version pins), DL3059 (consecutive RUNs)

### Feature Development
- **Options**: Define in `devcontainer-feature.json` with types, defaults, descriptions
- **PATH**: Use `containerEnv.PATH` to prepend feature bin directories
- **Isolation**: Install into `/opt/<feature-name>/` to avoid conflicts
- **Verification**: End `install.sh` with a version check command

### Testing Patterns
```bash
# Helper functions in tests/test.sh:
run_in <image> <command>                    # Execute in container
assert_cmd <image> <desc> <command>         # Assert exit 0
assert_output_contains <image> <desc> <substring> <command>
build_feature_image <feature-name>          # Layer feature, return test tag
```

## Example: Adding a New Feature

1. Create `features/my-tool/devcontainer-feature.json`:
   ```json
   {
     "id": "my-tool",
     "version": "1.0.0",
     "name": "My Tool",
     "description": "Installs my-tool",
     "options": {
       "version": {
         "type": "string",
         "default": "2.0.0"
       }
     },
     "containerEnv": {
       "PATH": "/opt/my-tool/bin:${PATH}"
     }
   }
   ```

2. Create `features/my-tool/install.sh`:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   VERSION="${VERSION:-2.0.0}"
   # Install logic...
   /opt/my-tool/bin/my-tool --version  # Verify
   ```

3. Add test case in `tests/test.sh` (follow `test_feature_*` pattern)

4. Add to Makefile targets and template example

## Critical Files for Context

- [Makefile](Makefile) – All targets, tool paths, file lists
- [tests/test.sh](tests/test.sh) – Complete test suite, helper functions
- [base/Dockerfile](base/Dockerfile) – Base image build steps
- [template/.devcontainer/devcontainer.json](template/.devcontainer/devcontainer.json) – Usage example with all features
- [features/dbt-duckdb/install.sh](features/dbt-duckdb/install.sh) – Reference feature implementation

## Common Pitfalls

- **Don't** modify base image Dockerfile without rebuilding and testing all features on top
- **Don't** use global Python packages in features; use venvs or isolated installs
- **Don't** forget to update version tags in both `devcontainer-feature.json` and template references
- **Test combined features**: Individual features may work but conflict when layered together
