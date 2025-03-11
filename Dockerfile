# 构建阶段 - 后端
FROM python:3.12-slim AS backend-builder

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# 设置可靠的shell执行环境
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 设置工作目录
WORKDIR /app

# 安装构建依赖（合并RUN命令以减少层数）
RUN set -ex \
    && apt-get update -o Acquire::http::No-Cache=True \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装uv工具进行更快的依赖安装
RUN pip install --no-cache-dir uv

# 复制后端项目依赖文件
COPY apps/backend/pyproject.toml .
# 可选：如果有poetry.lock或其他锁文件，也复制它
COPY apps/backend/poetry.lock* ./ 2>/dev/null || true

# 使用uv构建wheel包
RUN uv pip wheel --no-cache-dir --wheel-dir /app/wheels -e .

# 前端构建阶段
FROM node:20-slim AS frontend-builder

# 设置工作目录
WORKDIR /app

# 安装pnpm
RUN npm install -g pnpm

# 复制package.json和pnpm相关文件
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml nx.json .npmrc ./
COPY apps/frontend ./apps/frontend

# 安装依赖并构建前端
RUN pnpm install --frozen-lockfile
RUN pnpm build

# 最终阶段
FROM python:3.12-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

# 设置可靠的shell执行环境
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 设置工作目录
WORKDIR /app

# 安装运行时依赖（合并RUN命令以减少层数）
RUN set -ex \
    && apt-get update -o Acquire::http::No-Cache=True \
    && apt-get install -y --no-install-recommends \
        libopencv-dev \
        ffmpeg \
        libsm6 \
        libxext6 \
        libgl1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装uv
RUN pip install --no-cache-dir uv

# 从构建阶段复制wheels和项目文件
COPY --from=backend-builder /app/wheels /wheels
COPY --from=backend-builder /app/pyproject.toml .
COPY --from=backend-builder /app/poetry.lock* ./ 2>/dev/null || true

# 使用uv安装依赖
RUN uv pip install --no-cache-dir --no-index --find-links=/wheels/ /wheels/*.whl \
    && rm -rf /wheels

# 复制后端应用代码
COPY apps/backend /app/backend/

# 复制前端构建文件
COPY --from=frontend-builder /app/dist /app/frontend/dist

# 设置用户
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

# 安装并配置Caddy作为轻量级Web服务器（替代Nginx，可以以非root用户运行）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    curl \
    ca-certificates \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y caddy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建Caddy配置文件
RUN mkdir -p /app/caddy
COPY <<EOF /app/caddy/Caddyfile
:80 {
    # 前端静态文件
    root * /app/frontend/dist
    try_files {path} /index.html
    file_server

    # 后端API代理
    handle /api/* {
        reverse_proxy localhost:8000
    }
}
EOF

# 确保appuser可以访问所有必要的文件
RUN chown -R appuser:appuser /app

USER appuser

# 暴露端口
EXPOSE 80 8000

# 创建启动脚本
RUN mkdir -p /app/scripts
COPY <<EOF /app/scripts/start.sh
#!/bin/bash
# 启动后端API服务
uvicorn backend.main:app --host 0.0.0.0 --port 8000 &
# 启动Caddy
caddy run --config /app/caddy/Caddyfile
EOF

RUN chmod +x /app/scripts/start.sh

# 启动命令
CMD ["/app/scripts/start.sh"]
