#!/bin/bash
set -e

echo "配置中国镜像源..."

# 配置 APT 源
if [ -n "$DEBIAN_MIRROR" ]; then
    echo "配置 APT 源: $DEBIAN_MIRROR (使用传统格式)"
    
    # 直接修改sources.list文件，使用传统格式
    cat > /etc/apt/sources.list << EOF
# 主要源
deb $DEBIAN_MIRROR bookworm main contrib non-free non-free-firmware
deb $DEBIAN_MIRROR bookworm-updates main contrib non-free non-free-firmware
deb $DEBIAN_MIRROR bookworm-backports main contrib non-free non-free-firmware
EOF

    echo "APT源配置完成"
fi

if [ -n "$DEBIAN_SECURITY_MIRROR" ]; then
    echo "配置 APT 安全源: $DEBIAN_SECURITY_MIRROR (使用传统格式)"
    
    # 添加安全更新源到sources.list
    cat >> /etc/apt/sources.list << EOF
# 安全更新源
deb $DEBIAN_SECURITY_MIRROR bookworm-security main contrib non-free non-free-firmware
EOF

    echo "APT安全源配置完成"
fi

# 验证APT源配置
if [ -n "$DEBIAN_MIRROR" ] || [ -n "$DEBIAN_SECURITY_MIRROR" ]; then
    echo "验证APT源配置..."
    apt-get update -o Acquire::http::No-Cache=True || {
        echo "APT源配置验证失败，恢复备份..."
        if [ -f /etc/apt/sources.list.bak ]; then
            cp /etc/apt/sources.list.bak /etc/apt/sources.list
            apt-get update -o Acquire::http::No-Cache=True
        fi
    }
fi

# 配置 pip 使用镜像
if [ -n "$PIP_MIRROR" ]; then
    echo "配置 pip 镜像: $PIP_MIRROR"
    # 创建配置目录（如果不存在）
    mkdir -p ~/.config/pip
    # 直接写入配置文件，避免使用pip命令可能的权限问题
    cat > ~/.config/pip/pip.conf << EOF
[global]
index-url = $PIP_MIRROR
EOF
    echo "pip镜像配置完成"
fi

# 配置 npm 使用镜像
if [ -n "$NPM_MIRROR" ] && command -v npm &> /dev/null; then
    echo "配置 npm 镜像: $NPM_MIRROR"
    npm config set registry "$NPM_MIRROR"
    echo "npm镜像配置完成"
else
    echo "npm命令不可用或未设置NPM_MIRROR，跳过npm镜像配置"
fi

# 显示Node.js镜像配置信息
if [ -n "$NVM_NODEJS_ORG_MIRROR" ]; then
    echo "使用 Node.js 镜像: $NVM_NODEJS_ORG_MIRROR"
fi

echo "镜像源配置完成!" 