#!/bin/bash
# post_create.sh - User-level environment setup script executed after container creation

# Enable error tracking and pipeline error detection
set -eo pipefail

# Colored output functions
log_info() {
  echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
  echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warning() {
  echo -e "\033[0;33m[WARNING]\033[0m $1" >&2
}

log_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

# Error handling function
handle_error() {
  log_error "Error on line $1, exit code: $2"
  exit $2
}

# Set error handling trap
trap 'handle_error ${LINENO} $?' ERR

# Display script execution start information
log_info "Starting user-level environment setup..."
log_info "Current working directory: $(pwd)"
log_info "Current user: $(whoami)"

# ===== Node.js Environment Setup =====
log_info "Setting up Node.js environment..."

# Set environment variables
export NVM_DIR="/usr/local/nvm"
log_info "Loading environment variables..."

# Try to load environment variables from .env file (if exists)
if [ -f "$(pwd)/.env" ]; then
  log_info "Loading environment variables from .env file"
  set +e  # Temporarily disable error exit
  export $(grep -v '^#' "$(pwd)/.env" | xargs 2>/dev/null || true)
  set -e  # Re-enable error exit
else
  log_info ".env file not found, skipping environment variable loading"
fi

# Load NVM
log_info "Checking NVM installation..."
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
  log_error "NVM script not found: $NVM_DIR/nvm.sh"
  log_info "$NVM_DIR directory contents:"
  ls -la $NVM_DIR || true
  log_error "NVM not properly installed, please check NVM installation steps in Dockerfile"
  exit 1
fi

log_info "NVM directory contents:"
ls -la $NVM_DIR

log_info "NVM script permissions:"
ls -la $NVM_DIR/nvm.sh

# Ensure script is executable
log_info "Ensuring NVM script is executable..."
chmod +x $NVM_DIR/nvm.sh

log_info "Loading NVM script: $NVM_DIR/nvm.sh"
# Use safer way to load NVM script
set +e  # Temporarily disable error exit
. "$NVM_DIR/nvm.sh"
NVM_LOAD_RESULT=$?
set -e  # Re-enable error exit

if [ $NVM_LOAD_RESULT -ne 0 ]; then
  log_error "Failed to load NVM script, exit code: $NVM_LOAD_RESULT"
  log_info "Trying to view the first few lines of NVM script:"
  head -n 20 "$NVM_DIR/nvm.sh"
  
  # Try to explicitly execute script with bash
  log_info "Trying to explicitly execute NVM script with bash..."
  bash "$NVM_DIR/nvm.sh" || log_warning "Executing NVM script with bash also failed"
  
  # Try to directly set PATH
  log_info "Trying to directly set PATH to include Node.js bin directory..."
  if [ -d "$NVM_DIR/versions/node" ]; then
    NODE_DIRS=$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d | sort -r)
    if [ -n "$NODE_DIRS" ]; then
      LATEST_NODE=$(echo "$NODE_DIRS" | head -n 1)
      if [ -d "$LATEST_NODE/bin" ]; then
        export PATH="$LATEST_NODE/bin:$PATH"
        log_info "Added $LATEST_NODE/bin to PATH"
      fi
    fi
  fi
  
  # Check if Node.js is available
  if command -v node >/dev/null 2>&1; then
    log_success "Found Node.js: $(node -v)"
  else
    log_error "Unable to load NVM or find Node.js, environment setup failed"
    exit 1
  fi
else
  log_success "NVM script loaded successfully"
fi

# Load NVM auto-completion (if exists)
if [ -s "$NVM_DIR/bash_completion" ]; then
  log_info "Loading NVM auto-completion"
  set +e  # Temporarily disable error exit
  source "$NVM_DIR/bash_completion" 
  if [ $? -ne 0 ]; then
    log_warning "Failed to load NVM auto-completion, but continuing"
  else
    log_info "NVM auto-completion loaded successfully"
  fi
  set -e  # Re-enable error exit
fi

# Verify NVM is available
if command -v nvm >/dev/null 2>&1; then
  log_success "NVM available: $(nvm --version)"
else
  log_warning "NVM command not available, trying to use Node.js directly"
  # Check if Node.js is available
  if command -v node >/dev/null 2>&1; then
    log_success "Found Node.js: $(node -v)"
  else
    log_error "Unable to find Node.js, environment setup failed"
    exit 1
  fi
fi

# Install Node.js
log_info "Installing Node.js..."
if command -v nvm >/dev/null 2>&1; then
  # If NVM is available, use NVM to install Node.js
  if [ -f .nvmrc ]; then
    NODE_VERSION=$(cat .nvmrc)
    log_info "Detected Node.js version from .nvmrc file: $NODE_VERSION"
    
    # Try to install specified version
    set +e  # Temporarily disable error exit
    nvm install "$NODE_VERSION"
    INSTALL_RESULT=$?
    set -e  # Re-enable error exit
    
    if [ $INSTALL_RESULT -eq 0 ]; then
      log_success "Successfully installed Node.js $NODE_VERSION"
      nvm alias default "$NODE_VERSION"
      nvm use "$NODE_VERSION"
    else
      log_warning "Failed to install Node.js $NODE_VERSION, falling back to LTS version"
      set +e  # Temporarily disable error exit
      nvm install --lts
      nvm use --lts
      set -e  # Re-enable error exit
    fi
  else
    log_info ".nvmrc file not found, installing LTS version"
    set +e  # Temporarily disable error exit
    nvm install --lts
    nvm use --lts
    set -e  # Re-enable error exit
  fi
else
  log_info "NVM not available, skipping Node.js installation"
fi

# Set up Python virtual environment
log_info "Setting up Python virtual environment..."
export VIRTUAL_ENV="$HOME/.local/project-venv"
if command -v uv >/dev/null 2>&1; then
  log_info "Using uv to create virtual environment: $VIRTUAL_ENV"
  uv venv "$VIRTUAL_ENV"
else
  log_info "uv not installed, using python venv module to create virtual environment"
  python -m venv "$VIRTUAL_ENV"
fi

# Update shell configuration files
log_info "Updating shell configuration files..."

# Create shell config update function
update_shell_config() {
  local config_file="$1"
  local config_exists=false
  
  # Check if config file exists
  if [ -f "$config_file" ]; then
    config_exists=true
  else
    touch "$config_file"
  fi
  
  # Add Python virtual environment path
  if ! grep -q "VIRTUAL_ENV=\"$VIRTUAL_ENV\"" "$config_file"; then
    echo "# Python virtual environment configuration" >> "$config_file"
    echo "export VIRTUAL_ENV=\"$VIRTUAL_ENV\"" >> "$config_file"
    echo "export PATH=\"\$VIRTUAL_ENV/bin:\$PATH\"" >> "$config_file"
    echo "" >> "$config_file"
  fi
  
  # Add NVM configuration
  if ! grep -q "NVM_DIR=\"$NVM_DIR\"" "$config_file"; then
    echo "# NVM configuration" >> "$config_file"
    echo "export NVM_DIR=\"$NVM_DIR\"" >> "$config_file"
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"  # Load NVM" >> "$config_file"
    echo "[ -s \"\$NVM_DIR/bash_completion\" ] && . \"\$NVM_DIR/bash_completion\"  # Load NVM auto-completion" >> "$config_file"
    echo "" >> "$config_file"
  fi
}

# Update bash configuration
update_shell_config "$HOME/.bashrc"
log_info "Bash configuration updated"

# Display Node.js and npm versions
NODE_VERSION=$(node -v 2>/dev/null || echo "not installed")
NPM_VERSION=$(npm -v 2>/dev/null || echo "not installed")
log_success "Node.js environment setup complete!"
log_info "Node.js version: $NODE_VERSION"
log_info "npm version: $NPM_VERSION"
log_info "Python virtual environment: $VIRTUAL_ENV"

# ===== Project Dependencies Installation =====
# Check project dependencies
if command -v npm >/dev/null 2>&1; then
  if ! command -v pnpm &> /dev/null; then
    log_info "Installing pnpm..."
    npm install -g pnpm
  else
    log_info "pnpm already installed: $(pnpm --version)"
  fi

  if [ -f "package.json" ]; then
    log_info "Detected package.json, preparing to install project dependencies..."
    pnpm install
  fi
else
  log_warning "npm not available, skipping pnpm installation and project dependencies installation"
fi

# ===== Python Dependencies Installation =====
log_info "Starting Python dependencies installation..."

# Ensure virtual environment is activated
if [ -d "$VIRTUAL_ENV" ]; then
  log_info "Activating Python virtual environment: $VIRTUAL_ENV"
  source "$VIRTUAL_ENV/bin/activate"
else
  log_warning "Virtual environment directory does not exist: $VIRTUAL_ENV"
  log_info "Recreating virtual environment..."
  if command -v uv >/dev/null 2>&1; then
    uv venv "$VIRTUAL_ENV"
  else
    python -m venv "$VIRTUAL_ENV"
  fi
  source "$VIRTUAL_ENV/bin/activate"
fi

# Install uv (if not installed)
if ! command -v uv >/dev/null 2>&1; then
  log_info "Installing uv package manager..."
  pip install uv
  log_success "uv installation complete: $(uv --version)"
else
  log_info "uv already installed: $(uv --version)"
fi

# Check backend project and install dependencies
BACKEND_DIR="/workspaces/building-os/apps/backend"
log_info "Using uv to install dependencies..."
uv pip install -e $BACKEND_DIR
