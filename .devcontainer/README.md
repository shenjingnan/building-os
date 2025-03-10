# DevContainer 测试指南

本目录包含了用于构建和测试开发容器（DevContainer）的配置文件和脚本。

## 文件结构

- `devcontainer.json` - VS Code DevContainer 配置文件
- `Dockerfile` - 用于构建开发容器的 Docker 配置
- `post_create.sh` - 容器创建后执行的用户级环境设置脚本
- `setup_mirrors.sh` - 配置镜像源的脚本（适用于中国大陆网络环境）
- `test_devcontainer.sh` - 用于验证 DevContainer 环境的测试脚本
- `.env` / `.env.cn` - 环境变量配置文件

## 自动化测试

我们使用 GitHub Actions 来自动测试 DevContainer 的构建和功能。测试工作流定义在 `.github/workflows/devcontainer-test.yml` 文件中。

测试工作流会在以下情况下触发：
- 当对 `.devcontainer` 目录中的文件进行修改并推送到 `main` 分支时
- 当创建包含 `.devcontainer` 目录修改的 Pull Request 时
- 手动触发工作流

## 本地测试

您可以在本地测试 DevContainer 的构建和功能：

### 构建 DevContainer 镜像

```bash
cd /path/to/your/project
docker build -t devcontainer-test -f .devcontainer/Dockerfile .
```

### 运行测试脚本

```bash
# 确保测试脚本可执行
chmod +x .devcontainer/test_devcontainer.sh

# 在容器中运行测试脚本
docker run --rm -v $(pwd):/workspace devcontainer-test bash -c "cd /workspace && .devcontainer/test_devcontainer.sh"
```

### 测试 post_create.sh 脚本

```bash
# 创建临时目录模拟工作区
mkdir -p /tmp/workspace
cp -r .devcontainer /tmp/workspace/
cp -r package.json /tmp/workspace/ # 如果存在
cp -r .nvmrc /tmp/workspace/ # 如果存在

# 在容器中运行 post_create.sh 脚本
docker run --rm -v /tmp/workspace:/workspace devcontainer-test bash -c "cd /workspace && chmod +x .devcontainer/post_create.sh && .devcontainer/post_create.sh"
```

## 常见问题排查

### 1. NVM 或 Node.js 不可用

检查 `post_create.sh` 脚本中的 NVM 配置是否正确，特别是 `NVM_DIR` 环境变量的设置。

### 2. Python 虚拟环境问题

确保 `post_create.sh` 脚本中正确设置了 `VIRTUAL_ENV` 路径，并且脚本有权限创建和激活虚拟环境。

### 3. 镜像源配置问题

如果您在中国大陆网络环境中遇到下载问题，请检查 `.env.cn` 文件中的镜像源配置，并确保 `setup_mirrors.sh` 脚本正确执行。

## 自定义测试

您可以根据项目需求修改 `test_devcontainer.sh` 脚本，添加更多测试项目。例如：

- 测试特定的项目依赖是否可用
- 验证特定的开发工具是否正确配置
- 检查数据库连接等

## 贡献指南

如果您对 DevContainer 配置有改进建议，请：

1. Fork 本仓库
2. 创建您的功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建一个 Pull Request

请确保在提交 PR 之前，您的更改已通过 DevContainer 测试工作流。 