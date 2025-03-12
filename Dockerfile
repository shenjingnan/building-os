# Backend build stage
FROM python:3.12-slim AS backend-builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    POETRY_VERSION=1.7.1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=false \
    POETRY_NO_INTERACTION=1

# Set reliable shell execution environment
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set working directory
WORKDIR /app

# Install build dependencies (merge RUN commands to reduce layers)
RUN set -ex \
    && apt-get update -o Acquire::http::No-Cache=True \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 - \
    && ln -s /opt/poetry/bin/poetry /usr/local/bin/poetry

# Create backend directory
RUN mkdir -p /app/backend

# Copy backend project dependency files to backend directory
COPY apps/backend/pyproject.toml /app/backend/
# Create an empty poetry.lock file, which will be overwritten if the source file exists
RUN touch /app/backend/poetry.lock
# Try to copy poetry.lock file (if it exists)
COPY apps/backend/poetry.lock /app/backend/

# Switch to backend directory
WORKDIR /app/backend

# Install dependencies using Poetry and create wheels
RUN poetry config virtualenvs.create false \
    && poetry install --no-interaction --no-ansi --no-root \
    && pip install --upgrade pip \
    && pip wheel --no-cache-dir --wheel-dir /app/wheels $(poetry export -f requirements.txt --without-hashes | grep -v "^-e" | cut -d " " -f1)

# Frontend build stage
FROM node:20-slim AS frontend-builder

# Set working directory
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy package.json and pnpm related files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml nx.json .npmrc ./
COPY apps/frontend ./apps/frontend

# Install dependencies and build frontend
RUN pnpm install --frozen-lockfile
RUN pnpm build

# Final stage
FROM python:3.12-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    POETRY_VERSION=1.7.1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=false \
    POETRY_NO_INTERACTION=1

# Set reliable shell execution environment
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set working directory
WORKDIR /app

# Install runtime dependencies (merge RUN commands to reduce layers)
RUN set -ex \
    && apt-get update -o Acquire::http::No-Cache=True \
    && apt-get install -y --no-install-recommends \
        libopencv-dev \
        ffmpeg \
        libsm6 \
        libxext6 \
        libgl1 \
        curl \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 - \
    && ln -s /opt/poetry/bin/poetry /usr/local/bin/poetry

# Create backend directory
RUN mkdir -p /app/backend

# Copy wheels and project files from build stage
COPY --from=backend-builder /app/wheels /wheels
COPY --from=backend-builder /app/backend/pyproject.toml /app/backend/
# Create an empty poetry.lock file, which will be overwritten if the source file exists
RUN touch /app/backend/poetry.lock
COPY --from=backend-builder /app/backend/poetry.lock /app/backend/

# Install dependencies
RUN pip install --no-cache-dir --no-index --find-links=/wheels/ /wheels/*.whl \
    && rm -rf /wheels

# Copy backend application code
COPY apps/backend /app/backend/

# Copy frontend build files
COPY --from=frontend-builder /app/dist /app/frontend/dist

# Set up user
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

# Install and configure Caddy as a lightweight web server (replaces Nginx, can run as non-root user)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    curl \
    ca-certificates \
    gnupg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y caddy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create Caddy configuration file
RUN mkdir -p /app/caddy
COPY <<EOF /app/caddy/Caddyfile
:80 {
    # Frontend static files
    root * /app/frontend/dist
    try_files {path} /index.html
    file_server

    # Backend API proxy
    handle /api/* {
        reverse_proxy localhost:8000
    }
}
EOF

# Ensure appuser can access all necessary files
RUN chown -R appuser:appuser /app

USER appuser

# Expose ports
EXPOSE 80 8000

# Create startup script
RUN mkdir -p /app/scripts
COPY <<EOF /app/scripts/start.sh
#!/bin/bash
# Start backend API service
cd /app/backend && poetry run uvicorn main:app --host 0.0.0.0 --port 8000 &
# Start Caddy
caddy run --config /app/caddy/Caddyfile
EOF

RUN chmod +x /app/scripts/start.sh

# Startup command
CMD ["/app/scripts/start.sh"]
