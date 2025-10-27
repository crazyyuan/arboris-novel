# Coolify 部署指南

本文档详细说明如何在 Coolify 平台上部署 Arboris Novel Generator。

## 🚨 常见问题：502 错误

如果你在 Coolify 上部署后遇到 502 错误（前端可访问但 API 不可用），通常是以下原因之一：

### 问题 1：后端启动时间过长

**症状**：前端可以访问，但登录或其他 API 请求返回 502

**原因**：
- 后端（FastAPI + Uvicorn）需要初始化数据库、加载配置等，可能需要 10-30 秒
- Nginx 在后端完全启动前就开始接收请求
- Coolify 的健康检查可能在后端准备好之前就判定为失败

**解决方案**：
1. 查看容器日志，确认后端是否成功启动
2. 等待 1-2 分钟后再次尝试
3. 检查 Coolify 的健康检查设置，增加 `start_period` 时间

### 问题 2：环境变量缺失

**症状**：容器启动失败或后端报错

**必需的环境变量**：
```bash
SECRET_KEY=你的随机密钥（必须设置！）
OPENAI_API_KEY=你的API密钥
```

**检查方法**：
1. 在 Coolify 中进入应用的 "Environment Variables" 页面
2. 确保至少设置了 `SECRET_KEY`
3. 查看容器日志，启动脚本会检查并提示缺失的变量

### 问题 3：存储卷权限问题

**症状**：数据库无法创建，应用启动失败

**原因**：Coolify 挂载的卷权限与容器内用户（UID 1000）不匹配

**解决方案**：
- 应用的 entrypoint 脚本会自动修正权限
- 如果仍有问题，检查 Coolify 的卷配置
- 查看容器日志中的权限相关警告

### 问题 4：Coolify 代理配置

**症状**：前端可访问，API 请求返回 502 或 404

**检查项**：
1. **端口配置**：确保 Coolify 暴露的端口是 `80`（不是 8000）
2. **路径配置**：不需要额外的路径前缀，应用自带 Nginx 反向代理
3. **健康检查**：确认健康检查路径为 `/api/health`

## 📋 Coolify 部署步骤

### 1. 创建应用

在 Coolify 中：
1. 点击 "New Resource" → "Docker Compose"
2. 选择 Git 仓库或使用 Docker Image
3. **推荐**：使用预构建镜像 `tiechui251/arboris-app:latest`

### 2. 配置环境变量

在 Coolify 的 Environment Variables 中添加：

```bash
# 必需配置
SECRET_KEY=your-random-secret-key-here-change-it
OPENAI_API_KEY=sk-your-openai-api-key

# 可选配置
OPENAI_API_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL_NAME=gpt-4o-mini
ADMIN_DEFAULT_USERNAME=admin
ADMIN_DEFAULT_PASSWORD=YourSecurePassword123!
ALLOW_USER_REGISTRATION=false
```

### 3. 配置端口

- **容器端口**：80
- **公开端口**：由 Coolify 自动分配（或使用自定义域名）
- **协议**：HTTP（Coolify 会处理 HTTPS）

### 4. 配置健康检查

Coolify 通常会自动检测 `docker-compose.yml` 中的健康检查配置：

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:8000/api/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 90s  # 重要：给后端足够的启动时间
```

### 5. 配置持久化存储

**SQLite 数据库**（默认）：
- Coolify 会自动为 Docker 卷创建持久化存储
- 数据库文件位于容器内的 `/app/storage/arboris.db`
- 确保挂载点正确：`/app/storage`

**MySQL 数据库**（可选）：
```bash
DB_PROVIDER=mysql
MYSQL_HOST=your-mysql-host
MYSQL_PORT=3306
MYSQL_USER=arboris
MYSQL_PASSWORD=your-secure-password
MYSQL_DATABASE=arboris
```

## 🔍 调试步骤

### 1. 查看容器日志

在 Coolify 中点击 "Logs"，查看：

**正常启动日志应该包含**：
```
==========================================
Arboris Novel Generator - Starting up
==========================================
Creating storage directory: /app/storage
Environment: production
Database Provider: sqlite
Starting supervisord...
==========================================
```

然后会看到 Uvicorn 和 Nginx 的启动日志。

**错误日志示例**：
- `ERROR: SECRET_KEY is not set!` → 需要设置环境变量
- `Permission denied` → 存储卷权限问题
- `Connection refused` → 后端未启动或启动失败

### 2. 测试健康检查端点

部署成功后，访问：
```
https://your-domain.com/api/health
```

应该返回：
```json
{
  "status": "healthy",
  "app": "AI Novel Generator API",
  "version": "1.0.0"
}
```

### 3. 使用内置诊断脚本（推荐）

容器内置了健康检查脚本，可以快速诊断问题。进入容器终端（Coolify 提供 Shell 功能）：

```bash
# 运行诊断脚本
/app/healthcheck.sh
```

这会自动检查：
- ✅ 进程是否运行
- ✅ 端口是否监听
- ✅ 健康检查端点是否正常
- ✅ 存储目录权限
- ✅ 环境变量配置
- ✅ 最近的错误日志

### 4. 手动检查后端（高级）

如果需要更详细的检查：
```bash
# 检查进程
ps aux | grep uvicorn

# 测试后端端口
curl http://127.0.0.1:8000/api/health

# 检查 Nginx 配置
nginx -t

# 查看 supervisor 状态
supervisorctl status
```

### 5. 查看 Nginx 错误日志

在容器中：
```bash
tail -f /var/log/nginx/error.log
```

常见错误：
- `Connection refused` → Uvicorn 未启动
- `Upstream timed out` → 后端响应太慢
- `Permission denied` → 文件权限问题

## 🎯 推荐的 Coolify 配置

### Docker Compose 方式

如果使用 Docker Compose 部署，在 Coolify 中上传以下配置：

```yaml
services:
  app:
    image: tiechui251/arboris-app:latest
    ports:
      - "80:80"
    environment:
      SECRET_KEY: ${SECRET_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      OPENAI_API_BASE_URL: ${OPENAI_API_BASE_URL:-https://api.openai.com/v1}
      OPENAI_MODEL_NAME: ${OPENAI_MODEL_NAME:-gpt-4o-mini}
      ADMIN_DEFAULT_PASSWORD: ${ADMIN_DEFAULT_PASSWORD:-ChangeMe123!}
      DB_PROVIDER: sqlite
      ENVIRONMENT: production
      DEBUG: false
    volumes:
      - app-storage:/app/storage
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://127.0.0.1:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s

volumes:
  app-storage:
```

### 单容器方式

如果直接使用 Docker Image：
1. **Image**：`tiechui251/arboris-app:latest`
2. **Port**：80
3. **Volume**：`/app/storage`
4. **Environment Variables**：参考上面的环境变量部分

## 🚀 性能优化建议

### 1. 使用外部 MySQL 数据库

对于生产环境，推荐使用外部 MySQL：
- 更好的性能
- 更容易备份
- 支持多实例部署

### 2. 配置域名和 HTTPS

Coolify 自动处理 HTTPS，你只需：
1. 在 Coolify 中添加自定义域名
2. Coolify 会自动申请 Let's Encrypt 证书

### 3. 配置资源限制

在 Coolify 中设置：
- **Memory**：建议至少 512MB（1GB 更佳）
- **CPU**：建议至少 0.5 核

## ❓ 常见问题解答

**Q: 为什么本地正常，Coolify 上报 502？**  
A: 最常见原因是后端启动慢。Coolify 可能在后端完全启动前就判定健康检查失败。解决方法：
- 查看日志确认后端是否真的启动了
- 增加健康检查的 `start_period`
- 等待 1-2 分钟后重试

**Q: 如何查看详细的错误信息？**  
A: 在 Coolify 中：
1. 点击应用 → Logs
2. 查看实时日志流
3. 注意 `ERROR` 或 `WARNING` 标记的行

**Q: 数据会丢失吗？**  
A: 不会，只要正确配置了卷挂载。Coolify 会自动持久化 `/app/storage` 目录。

**Q: 可以使用环境变量覆盖配置吗？**  
A: 可以！所有配置都支持环境变量，参考 `backend/env.example`。

**Q: 如何更新到新版本？**  
A: 
1. 如果使用 Git 部署：在 Coolify 中点击 "Redeploy"
2. 如果使用 Docker Image：更新 image tag 后重新部署
3. 数据不会丢失（存储在持久卷中）

## 📞 获取帮助

如果问题仍未解决：
1. 查看项目的 [GitHub Issues](https://github.com/your-repo/issues)
2. 提供详细的错误日志
3. 说明你的配置（环境变量、Coolify 设置等）

---

**最后更新**：2025-10-27

