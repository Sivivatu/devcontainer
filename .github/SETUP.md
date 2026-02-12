# GitHub Repository Setup for CI/CD

This document explains how to configure your GitHub repository to use the automated CI/CD pipeline.

## Prerequisites

- GitHub repository with this code pushed
- GitHub account with appropriate permissions

## Repository Configuration

### 1. Enable GitHub Actions

Ensure GitHub Actions is enabled for your repository:

1. Go to **Settings** → **Actions** → **General**
2. Under "Actions permissions", select **Allow all actions and reusable workflows**
3. Click **Save**

### 2. Configure Package Permissions

Allow GitHub Actions to publish to GitHub Container Registry:

1. Go to **Settings** → **Actions** → **General**
2. Scroll to **Workflow permissions**
3. Select **Read and write permissions**
4. Check **Allow GitHub Actions to create and approve pull requests** (optional)
5. Click **Save**

### 3. Enable GitHub Packages

The CI/CD pipeline publishes to GitHub Container Registry (ghcr.io). This is automatically available for all GitHub repositories.

### 4. Configure Package Visibility (Optional)

After the first successful publish, you can configure package visibility:

1. Go to your GitHub profile/organization
2. Click **Packages**
3. Find your published packages (`devcontainer-base`, `devcontainer-features/*`)
4. Click on the package → **Package settings**
5. Under **Danger Zone**, set visibility:
   - **Public**: Anyone can pull (recommended for personal projects)
   - **Private**: Only you and collaborators can pull

### 5. Update Repository Variables

Update references in your code:

1. Replace `<your-user>` with your GitHub username/org in:
   - `README.md` examples
   - `template/.devcontainer/devcontainer.json`

## Triggering the Pipeline

### Automatic Triggers

The pipeline runs automatically on:

- **Pull requests** to `main` or `develop`: Runs tests only (no publish)
- **Push to `main`**: Runs tests + publishes with `latest` tag
- **Push to `develop`**: Runs tests + publishes with `develop` tag
- **Version tags** (`v*`): Runs tests + publishes with semantic version tags

### Creating a Release

1. Update versions in `features/*/devcontainer-feature.json` files
2. Commit changes:
   ```bash
   git commit -am "chore: bump version to 1.2.3"
   git push origin main
   ```
3. Create and push a version tag:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```
4. Monitor the Actions tab for build progress

### Version Tags Generated

When you push `v1.2.3`, the base image will be tagged as:
- `ghcr.io/<user>/devcontainer/devcontainer-base:v1.2.3`
- `ghcr.io/<user>/devcontainer/devcontainer-base:1.2`
- `ghcr.io/<user>/devcontainer/devcontainer-base:1`
- `ghcr.io/<user>/devcontainer/devcontainer-base:latest`

## Monitoring Builds

### View Workflow Runs

1. Go to **Actions** tab in your repository
2. Click on a workflow run to see details
3. Click on individual jobs (lint, test, publish-base-image, publish-features) to see logs

### Troubleshooting Failed Builds

If a build fails:

1. Check the **Actions** tab for error details
2. Look at the failing job's logs
3. Common issues:
   - **Lint failures**: Run `make lint` locally to see issues
   - **Format failures**: Run `make fmt` to auto-fix
   - **Test failures**: Run `make test` locally to reproduce
   - **Permission errors**: Verify workflow permissions (Step 2 above)
   - **Push errors**: Check package visibility settings

## Using Published Images

### Base Image

```json
{
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:latest"
}
```

Or pin to a specific version:

```json
{
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:1.2.3"
}
```

### Features

```json
{
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:latest",
  "features": {
    "ghcr.io/<your-user>/devcontainer-features/dbt-duckdb:1": {},
    "ghcr.io/<your-user>/devcontainer-features/k8s-tools:1": {}
  }
}
```

## Security Considerations

### Secrets

The workflow uses `GITHUB_TOKEN` which is automatically provided by GitHub Actions. No manual secrets configuration is required for publishing to ghcr.io.

### Private Packages

If your packages are private, users will need to authenticate to pull them:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

Or configure in devcontainer:

```json
{
  "image": "ghcr.io/<your-user>/devcontainer/devcontainer-base:latest",
  "remoteUser": "dev",
  "features": {...}
}
```

VS Code will prompt for authentication when opening the devcontainer.

## Next Steps

1. ✅ Complete repository setup (above steps)
2. ✅ Push code to trigger first build
3. ✅ Verify packages appear in GitHub Packages
4. ✅ Update visibility if needed
5. ✅ Test using published images in a new project
6. ✅ Create your first version tag to test release workflow
