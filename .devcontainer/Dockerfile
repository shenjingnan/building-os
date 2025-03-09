FROM mcr.microsoft.com/devcontainers/python:3.12

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    DEVCONTAINER=true \
    PATH=$PATH:./node_modules/.bin \
    NVM_VERSION="0.39.7" \
    NVM_DIR="/usr/local/nvm" \
    SHELL=/bin/bash

# 设置更可靠的shell执行环境
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 设置工作目录
WORKDIR /workspace

# 复制配置文件
COPY .devcontainer/.env /tmp/.env
COPY .devcontainer/setup_mirrors.sh /tmp/setup_mirrors.sh
RUN chmod +x /tmp/setup_mirrors.sh

# 系统配置和依赖安装（合并多个RUN命令减少层数）
RUN set -ex \
    # 配置镜像源
    && export $(grep -v '^#' /tmp/.env | xargs) \
    && /tmp/setup_mirrors.sh \
    # 更新包索引并安装基本工具和系统依赖
    && apt-get update -o Acquire::http::No-Cache=True \
    && apt-get -y install --no-install-recommends \
        curl \
        git \
        ca-certificates \
        bluez \
        ffmpeg \
        libudev-dev \
        libavformat-dev \
        libavcodec-dev \
        libavdevice-dev \
        libavutil-dev \
        libgammu-dev \
        libswscale-dev \
        libswresample-dev \
        libavfilter-dev \
        libpcap-dev \
        libturbojpeg0 \
        libyaml-dev \
        libxml2 \
        cmake \
    # 清理apt缓存减小镜像大小
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /tmp/setup_mirrors.sh /tmp/.env

# 安装和配置NVM
RUN set -ex \
    # 创建NVM目录并设置权限
    && mkdir -p $NVM_DIR \
    && chmod -R 755 $NVM_DIR \
    # 下载并安装NVM
    && (curl -o /tmp/nvm-install.sh -s https://gitee.com/mirrors/nvm/raw/v${NVM_VERSION}/install.sh || \
        curl -o /tmp/nvm-install.sh -s https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh) \
    # 检查下载的脚本
    && cat /tmp/nvm-install.sh | head -n 20 \
    # 执行NVM安装脚本
    && bash /tmp/nvm-install.sh \
    && rm -f /tmp/nvm-install.sh \
    # 验证NVM安装
    && ls -la $NVM_DIR \
    # 确保NVM脚本存在并可执行
    && chmod +x $NVM_DIR/nvm.sh \
    # 预先安装Node.js LTS版本
    && . $NVM_DIR/nvm.sh \
    && nvm install --lts \
    && nvm use --lts \
    && npm install -g pnpm \
    # 确保vscode用户可以访问NVM目录
    && chown -R vscode:vscode $NVM_DIR

# 安装Python工具
RUN pip3 install --no-cache-dir uv

# 添加Node.js环境激活脚本
RUN echo 'if [ -d "$NVM_DIR" ]; then\n\
    export NVM_DIR="$NVM_DIR"\n\
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n\
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"\n\
fi' > /etc/profile.d/nvm.sh \
    && chmod +x /etc/profile.d/nvm.sh

# 设置默认用户为vscode
USER vscode
