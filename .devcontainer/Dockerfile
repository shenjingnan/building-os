FROM mcr.microsoft.com/devcontainers/python:3.12

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DEVCONTAINER=true \
    PATH=$PATH:./node_modules/.bin \
    NVM_VERSION="0.39.7" \
    NVM_DIR="/usr/local/nvm" \
    SHELL=/bin/bash

# Set reliable shell execution environment
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set working directory
WORKDIR /workspace

# Copy configuration files
COPY .devcontainer/.env /tmp/.env
COPY .devcontainer/setup_mirrors.sh /tmp/setup_mirrors.sh
RUN chmod +x /tmp/setup_mirrors.sh

# System configuration and dependency installation (merged RUN commands to reduce layers)
RUN set -ex \
    # Configure mirrors
    && export $(grep -v '^#' /tmp/.env | xargs) \
    && /tmp/setup_mirrors.sh \
    # Update package index and install basic tools and system dependencies
    && apt-get update -o Acquire::http::No-Cache=True \
    && apt-get -y install --no-install-recommends \
        curl \
        git \
        ca-certificates \
        libyaml-dev \
        libxml2 \
        cmake \
        rustc \
        cargo \
    # Clean apt cache to reduce image size
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /tmp/setup_mirrors.sh
    # Keep .env file for subsequent steps

# Install and configure NVM
RUN set -ex \
    # Create NVM directory and set permissions
    && mkdir -p $NVM_DIR \
    && chmod -R 755 $NVM_DIR \
    # Import environment variables
    && export $(grep -v '^#' /tmp/.env | xargs) \
    # Select NVM installation source based on configuration
    && NVM_INSTALL_URL="${NVM_MIRROR}/v${NVM_VERSION}/install.sh" \
    # Download NVM installation script
    && curl -o /tmp/nvm-install.sh -s $NVM_INSTALL_URL \
    # Check downloaded script
    && cat /tmp/nvm-install.sh | head -n 20 \
    # Execute NVM installation script
    && bash /tmp/nvm-install.sh \
    && rm -f /tmp/nvm-install.sh \
    # Verify NVM installation
    && ls -la $NVM_DIR \
    # Ensure NVM script exists and is executable
    && chmod +x $NVM_DIR/nvm.sh \
    # Pre-install Node.js LTS version
    && . $NVM_DIR/nvm.sh \
    && nvm install --lts \
    && nvm use --lts \
    && npm install -g pnpm \
    # Ensure vscode user can access NVM directory
    && chown -R vscode:vscode $NVM_DIR \
    # Clean up temporary files
    && rm -f /tmp/.env

# Install Python tools
RUN pip3 install --no-cache-dir uv

# Add Node.js environment activation script
RUN echo 'if [ -d "$NVM_DIR" ]; then\n\
    export NVM_DIR="$NVM_DIR"\n\
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n\
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"\n\
fi' > /etc/profile.d/nvm.sh \
    && chmod +x /etc/profile.d/nvm.sh

# Set default user to vscode
USER vscode
