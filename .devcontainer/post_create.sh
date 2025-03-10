#!/bin/bash
# post_create.sh - 容器创建后执行的用户级环境设置脚本

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

# 显示脚本开始执行的信息
log_info "开始执行用户级环境设置..."
log_info "当前工作目录: $(pwd)"
log_info "当前用户: $(whoami)"

# ===== Node.js环境设置部分 =====
log_info "开始设置Node.js环境..."

# 设置环境变量
export NVM_DIR="/usr/local/nvm"
log_info "加载环境变量..."

# 尝试加载.env文件中的环境变量（如果存在）
if [ -f "$(pwd)/.env" ]; then
  log_info "加载.env文件中的环境变量"
  set +e  # 临时禁用错误退出
  export $(grep -v '^#' "$(pwd)/.env" | xargs 2>/dev/null || true)
  set -e  # 重新启用错误退出
else
  log_info "未找到.env文件，跳过环境变量加载"
fi

# 加载NVM
log_info "检查NVM安装..."
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
  log_error "NVM脚本未找到: $NVM_DIR/nvm.sh"
  log_info "$NVM_DIR目录内容:"
  ls -la $NVM_DIR || true
  log_error "NVM未正确安装，请检查Dockerfile中的NVM安装步骤"
  exit 1
fi

log_info "NVM目录内容:"
ls -la $NVM_DIR

log_info "NVM脚本权限:"
ls -la $NVM_DIR/nvm.sh

# 确保脚本可执行
log_info "确保NVM脚本可执行..."
chmod +x $NVM_DIR/nvm.sh

log_info "加载NVM脚本: $NVM_DIR/nvm.sh"
# 使用更安全的方式加载NVM脚本
set +e  # 临时禁用错误退出
. "$NVM_DIR/nvm.sh"
NVM_LOAD_RESULT=$?
set -e  # 重新启用错误退出

if [ $NVM_LOAD_RESULT -ne 0 ]; then
  log_error "加载NVM脚本失败，退出代码: $NVM_LOAD_RESULT"
  log_info "尝试查看NVM脚本内容的前几行:"
  head -n 20 "$NVM_DIR/nvm.sh"
  
  # 尝试使用bash明确执行脚本
  log_info "尝试使用bash明确执行NVM脚本..."
  bash "$NVM_DIR/nvm.sh" || log_warning "使用bash执行NVM脚本也失败了"
  
  # 尝试直接设置PATH
  log_info "尝试直接设置PATH以包含Node.js bin目录..."
  if [ -d "$NVM_DIR/versions/node" ]; then
    NODE_DIRS=$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d | sort -r)
    if [ -n "$NODE_DIRS" ]; then
      LATEST_NODE=$(echo "$NODE_DIRS" | head -n 1)
      if [ -d "$LATEST_NODE/bin" ]; then
        export PATH="$LATEST_NODE/bin:$PATH"
        log_info "已将 $LATEST_NODE/bin 添加到PATH"
      fi
    fi
  fi
  
  # 检查是否有Node.js可用
  if command -v node >/dev/null 2>&1; then
    log_success "找到Node.js: $(node -v)"
  else
    log_error "无法加载NVM，也无法找到Node.js，环境设置失败"
    exit 1
  fi
else
  log_success "NVM脚本加载成功"
fi

# 加载NVM自动补全（如果存在）
if [ -s "$NVM_DIR/bash_completion" ]; then
  log_info "加载NVM自动补全"
  set +e  # 临时禁用错误退出
  source "$NVM_DIR/bash_completion" 
  if [ $? -ne 0 ]; then
    log_warning "加载NVM自动补全失败，但继续执行"
  else
    log_info "NVM自动补全加载成功"
  fi
  set -e  # 重新启用错误退出
fi

# 验证NVM是否可用
if command -v nvm >/dev/null 2>&1; then
  log_success "NVM可用: $(nvm --version)"
else
  log_warning "NVM命令不可用，尝试直接使用Node.js"
  # 检查是否有Node.js可用
  if command -v node >/dev/null 2>&1; then
    log_success "找到Node.js: $(node -v)"
  else
    log_error "无法找到Node.js，环境设置失败"
    exit 1
  fi
fi

# 安装Node.js
log_info "安装Node.js..."
if command -v nvm >/dev/null 2>&1; then
  # 如果NVM可用，使用NVM安装Node.js
  if [ -f .nvmrc ]; then
    NODE_VERSION=$(cat .nvmrc)
    log_info "从.nvmrc文件中检测到Node.js版本: $NODE_VERSION"
    
    # 尝试安装指定版本
    set +e  # 临时禁用错误退出
    nvm install "$NODE_VERSION"
    INSTALL_RESULT=$?
    set -e  # 重新启用错误退出
    
    if [ $INSTALL_RESULT -eq 0 ]; then
      log_success "成功安装Node.js $NODE_VERSION"
      nvm alias default "$NODE_VERSION"
      nvm use "$NODE_VERSION"
    else
      log_warning "安装Node.js $NODE_VERSION失败，回退到LTS版本"
      set +e  # 临时禁用错误退出
      nvm install --lts
      nvm use --lts
      set -e  # 重新启用错误退出
    fi
  else
    log_info "未找到.nvmrc文件，安装LTS版本"
    set +e  # 临时禁用错误退出
    nvm install --lts
    nvm use --lts
    set -e  # 重新启用错误退出
  fi
else
  log_info "NVM不可用，跳过Node.js安装"
fi

# 设置Python虚拟环境
log_info "设置Python虚拟环境..."
export VIRTUAL_ENV="$HOME/.local/project-venv"
if command -v uv >/dev/null 2>&1; then
  log_info "使用uv创建虚拟环境: $VIRTUAL_ENV"
  uv venv "$VIRTUAL_ENV"
else
  log_info "uv未安装，使用python venv模块创建虚拟环境"
  python -m venv "$VIRTUAL_ENV"
fi

# 更新shell配置文件
log_info "更新shell配置文件..."

# 创建shell配置更新函数
update_shell_config() {
  local config_file="$1"
  local config_exists=false
  
  # 检查配置文件是否存在
  if [ -f "$config_file" ]; then
    config_exists=true
  else
    touch "$config_file"
  fi
  
  # 添加Python虚拟环境路径
  if ! grep -q "VIRTUAL_ENV=\"$VIRTUAL_ENV\"" "$config_file"; then
    echo "# Python虚拟环境配置" >> "$config_file"
    echo "export VIRTUAL_ENV=\"$VIRTUAL_ENV\"" >> "$config_file"
    echo "export PATH=\"\$VIRTUAL_ENV/bin:\$PATH\"" >> "$config_file"
    echo "" >> "$config_file"
  fi
  
  # 添加NVM配置
  if ! grep -q "NVM_DIR=\"$NVM_DIR\"" "$config_file"; then
    echo "# NVM配置" >> "$config_file"
    echo "export NVM_DIR=\"$NVM_DIR\"" >> "$config_file"
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"  # 加载NVM" >> "$config_file"
    echo "[ -s \"\$NVM_DIR/bash_completion\" ] && . \"\$NVM_DIR/bash_completion\"  # 加载NVM自动补全" >> "$config_file"
    echo "" >> "$config_file"
  fi
}

# 更新bash配置
update_shell_config "$HOME/.bashrc"
log_info "已更新Bash配置"

# 显示Node.js和npm版本
NODE_VERSION=$(node -v 2>/dev/null || echo "未安装")
NPM_VERSION=$(npm -v 2>/dev/null || echo "未安装")
log_success "Node.js环境设置完成！"
log_info "Node.js版本: $NODE_VERSION"
log_info "npm版本: $NPM_VERSION"
log_info "Python虚拟环境: $VIRTUAL_ENV"

# ===== 项目依赖安装部分 =====
# 检查项目依赖
if command -v npm >/dev/null 2>&1; then
  if ! command -v pnpm &> /dev/null; then
    log_info "安装pnpm..."
    npm install -g pnpm
  else
    log_info "pnpm已安装: $(pnpm --version)"
  fi

  if [ -f "package.json" ]; then
    log_info "检测到package.json，准备安装项目依赖..."
    pnpm install
  fi
else
  log_warning "npm不可用，跳过pnpm安装和项目依赖安装"
fi

# ===== Python依赖安装部分 =====
log_info "开始安装Python依赖..."

# 确保虚拟环境已激活
if [ -d "$VIRTUAL_ENV" ]; then
  log_info "激活Python虚拟环境: $VIRTUAL_ENV"
  source "$VIRTUAL_ENV/bin/activate"
else
  log_warning "虚拟环境目录不存在: $VIRTUAL_ENV"
  log_info "重新创建虚拟环境..."
  if command -v uv >/dev/null 2>&1; then
    uv venv "$VIRTUAL_ENV"
  else
    python -m venv "$VIRTUAL_ENV"
  fi
  source "$VIRTUAL_ENV/bin/activate"
fi

# 安装uv（如果未安装）
if ! command -v uv >/dev/null 2>&1; then
  log_info "安装uv包管理器..."
  pip install uv
  log_success "uv安装完成: $(uv --version)"
else
  log_info "uv已安装: $(uv --version)"
fi

# 检查后端项目并安装依赖
BACKEND_DIR="/workspaces/building-os/apps/backend"
log_info "使用uv安装依赖..."
uv pip install -e $BACKEND_DIR
