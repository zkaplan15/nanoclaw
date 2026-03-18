FROM mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

# Install basic development tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
     && apt-get -y install --no-install-recommends \
        htop \
        vim \
        git \
        build-essential \
     && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy bashrc customizations if present
COPY .devcontainer/devcontainer.bashrc /home/node/.bashrc

# Note: This devcontainer is for DEVELOPMENT only.
# Production NanoClaw runs as a systemd service on the host and uses the host Docker daemon.
# The host Docker socket is mounted so you can use Docker from within this container.

CMD ["sleep", "infinity"]
