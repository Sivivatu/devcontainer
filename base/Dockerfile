# =============================================================================
# Personal Base Devcontainer Image
# =============================================================================
# Provides a common foundation for development containers:
#   - Python + pip + uv
#   - Essential CLI tooling
#
# Build:
#   docker build -t ghcr.io/sivivatu/devcontainer-base:1.1.0 .
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="sivivatu"
LABEL org.opencontainers.image.description="Personal base devcontainer image"

# Avoid interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Essential CLI tooling
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        wget \
        jq \
        ripgrep \
        fd-find \
        make \
        openssl \
        ca-certificates \
        openssh-client \
        gnupg \
        sudo \
        locales \
        unzip \
        zsh \
    && locale-gen en_GB.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Symlink fd-find → fd (Ubuntu packages it under a different name)
RUN ln -sf "$(which fdfind)" /usr/local/bin/fd

# -----------------------------------------------------------------------------
# GitHub CLI
# -----------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -nv -O /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Python + pip
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/local/bin/python

# -----------------------------------------------------------------------------
# uv – fast Python package/virtual-environment manager
# -----------------------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# -----------------------------------------------------------------------------
# Starship prompt
# -----------------------------------------------------------------------------
RUN curl -fsSL https://starship.rs/install.sh -o /tmp/install-starship.sh \
    && sh /tmp/install-starship.sh --yes --bin-dir /usr/local/bin \
    && rm -f /tmp/install-starship.sh \
    && printf '\n# Initialise Starship for interactive zsh shells.\nif command -v starship >/dev/null 2>&1; then\n    eval "$(starship init zsh)"\nfi\n' >> /etc/zsh/zshrc

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
ARG USERNAME=dev
ARG USER_UID=1001
ARG USER_GID=${USER_UID}

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/zsh "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}"

# -----------------------------------------------------------------------------
# Environment defaults
# -----------------------------------------------------------------------------
ENV LANG=en_GB.UTF-8 \
    LANGUAGE=en_GB:en \
    LC_ALL=en_GB.UTF-8 \
    SHELL=/bin/zsh \
    PATH="/home/${USERNAME}/.local/bin:${PATH}"

USER ${USERNAME}
WORKDIR /home/${USERNAME}
