#!/bin/bash
# test_devcontainer.sh - 用于验证devcontainer环境的测试脚本

# 启用错误追踪和管道错误检测
set -eo pipefail

# 彩色输出函数
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

# 错误处理函数
handle_error() {
  log_error "在第 $1 行发生错误，退出状态码: $2"
  exit $2
}

# 设置错误处理陷阱
trap 'handle_error ${LINENO} $?' ERR

# 显示测试开始信息
log_info "===== DevContainer 环境测试开始 ====="
log_info "当前工作目录: $(pwd)"
log_info "当前用户: $(whoami)"
log_info "系统信息: $(uname -a)"

# 测试基本系统工具
log_info "测试基本系统工具..."
TOOLS=("git" "curl" "bash" "python" "pip")
for tool in "${TOOLS[@]}"; do
  if command -v $tool &> /dev/null; then
    log_success "$tool 可用: $($tool --version 2>&1 | head -n 1)"
  else
    log_error "$tool 不可用"
    exit 1
  fi
done

# 测试 Python 环境
log_info "测试 Python 环境..."
if command -v python &> /dev/null; then
  log_success "Python 版本: $(python --version)"
  
  # 测试 pip
  if command -v pip &> /dev/null; then
    log_success "pip 可用: $(pip --version)"
  else
    log_error "pip 不可用"
    exit 1
  fi
  
  # 测试 uv
  if command -v uv &> /dev/null; then
    log_success "uv 可用: $(uv --version)"
  else
    log_warning "uv 不可用，这可能会影响依赖管理"
  fi
  
  # 测试 Python 虚拟环境
  log_info "测试 Python 虚拟环境..."
  VENV_PATH="$HOME/.local/project-venv"
  if [ -d "$VENV_PATH" ]; then
    log_success "Python 虚拟环境存在: $VENV_PATH"
    if [ -f "$VENV_PATH/bin/activate" ]; then
      log_success "虚拟环境激活脚本存在"
      source "$VENV_PATH/bin/activate"
      log_success "虚拟环境已激活: $(which python)"
    else
      log_error "虚拟环境激活脚本不存在"
    fi
  else
    log_warning "Python 虚拟环境不存在: $VENV_PATH"
  fi
else
  log_error "Python 不可用"
  exit 1
fi

# 测试 Node.js 环境
log_info "测试 Node.js 环境..."
export NVM_DIR="/usr/local/nvm"

# 检查 NVM 目录
if [ -d "$NVM_DIR" ]; then
  log_success "NVM 目录存在: $NVM_DIR"
  
  # 检查 NVM 脚本
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    log_success "NVM 脚本存在"
    
    # 加载 NVM
    log_info "加载 NVM..."
    set +e  # 临时禁用错误退出
    . "$NVM_DIR/nvm.sh"
    NVM_LOAD_RESULT=$?
    set -e  # 重新启用错误退出
    
    if [ $NVM_LOAD_RESULT -eq 0 ]; then
      log_success "NVM 加载成功: $(nvm --version)"
      
      # 检查 Node.js
      if command -v node &> /dev/null; then
        log_success "Node.js 可用: $(node -v)"
        
        # 测试 Node.js 运行
        node -e "console.log('Node.js 运行正常: ' + process.version)"
        log_success "Node.js 运行测试通过"
        
        # 检查 npm
        if command -v npm &> /dev/null; then
          log_success "npm 可用: $(npm -v)"
        else
          log_error "npm 不可用"
          exit 1
        fi
        
        # 检查 pnpm
        if command -v pnpm &> /dev/null; then
          log_success "pnpm 可用: $(pnpm -v)"
        else
          log_warning "pnpm 不可用，这可能会影响项目依赖管理"
        fi
      else
        log_error "Node.js 不可用"
        exit 1
      fi
    else
      log_error "NVM 加载失败"
      exit 1
    fi
  else
    log_error "NVM 脚本不存在: $NVM_DIR/nvm.sh"
    exit 1
  fi
else
  log_error "NVM 目录不存在: $NVM_DIR"
  exit 1
fi

# 测试项目配置
log_info "测试项目配置..."

# 检查 package.json
if [ -f "package.json" ]; then
  log_success "package.json 存在"
else
  log_warning "package.json 不存在，这可能是正常的，取决于当前目录"
fi

# 检查 .nvmrc
if [ -f ".nvmrc" ]; then
  log_success ".nvmrc 存在: $(cat .nvmrc)"
else
  log_warning ".nvmrc 不存在，这可能是正常的，取决于当前目录"
fi

# 测试 shell 配置
log_info "测试 shell 配置..."
SHELL_CONFIG_FILES=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
for config_file in "${SHELL_CONFIG_FILES[@]}"; do
  if [ -f "$config_file" ]; then
    log_success "$config_file 存在"
    
    # 检查 NVM 配置
    if grep -q "NVM_DIR" "$config_file"; then
      log_success "$config_file 中包含 NVM 配置"
    else
      log_warning "$config_file 中不包含 NVM 配置"
    fi
    
    # 检查 Python 虚拟环境配置
    if grep -q "VIRTUAL_ENV" "$config_file"; then
      log_success "$config_file 中包含 Python 虚拟环境配置"
    else
      log_warning "$config_file 中不包含 Python 虚拟环境配置"
    fi
  else
    log_warning "$config_file 不存在"
  fi
done

# 测试完成
log_success "===== DevContainer 环境测试完成 ====="
exit 0 