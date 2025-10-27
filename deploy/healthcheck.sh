#!/bin/sh
# 健康检查和诊断脚本
# 可以在容器内运行此脚本来诊断问题

set -e

echo "=========================================="
echo "Arboris Health Check & Diagnostics"
echo "=========================================="
echo ""

# 1. 检查进程
echo "1. Checking processes..."
if ps aux | grep -q "[u]vicorn"; then
    echo "✅ Uvicorn (Backend) is running"
    ps aux | grep "[u]vicorn"
else
    echo "❌ Uvicorn (Backend) is NOT running"
fi

if ps aux | grep -q "[n]ginx"; then
    echo "✅ Nginx (Frontend proxy) is running"
else
    echo "❌ Nginx is NOT running"
fi
echo ""

# 2. 检查端口
echo "2. Checking ports..."
if netstat -tln 2>/dev/null | grep -q ":8000"; then
    echo "✅ Backend listening on port 8000"
else
    echo "❌ Backend NOT listening on port 8000"
fi

if netstat -tln 2>/dev/null | grep -q ":80"; then
    echo "✅ Nginx listening on port 80"
else
    echo "❌ Nginx NOT listening on port 80"
fi
echo ""

# 3. 测试后端健康检查
echo "3. Testing backend health endpoint..."
if curl -sf http://127.0.0.1:8000/api/health > /dev/null; then
    echo "✅ Backend health check passed"
    curl -s http://127.0.0.1:8000/api/health | head -1
else
    echo "❌ Backend health check failed"
fi
echo ""

# 4. 测试 Nginx 到后端的代理
echo "4. Testing Nginx -> Backend proxy..."
if curl -sf http://127.0.0.1:80/api/health > /dev/null; then
    echo "✅ Nginx proxy to backend works"
else
    echo "❌ Nginx proxy to backend failed"
fi
echo ""

# 5. 检查存储目录
echo "5. Checking storage directory..."
STORAGE_DIR="/app/storage"
if [ -d "$STORAGE_DIR" ]; then
    echo "✅ Storage directory exists: $STORAGE_DIR"
    echo "   Permissions: $(stat -c '%a %U:%G' "$STORAGE_DIR" 2>/dev/null || stat -f '%p %Su:%Sg' "$STORAGE_DIR")"
    echo "   Contents:"
    ls -lh "$STORAGE_DIR" 2>/dev/null || echo "   (empty or no access)"
else
    echo "❌ Storage directory NOT found: $STORAGE_DIR"
fi
echo ""

# 6. 检查环境变量
echo "6. Checking environment variables..."
if [ -n "$SECRET_KEY" ]; then
    echo "✅ SECRET_KEY is set"
else
    echo "❌ SECRET_KEY is NOT set"
fi

if [ -n "$OPENAI_API_KEY" ]; then
    echo "✅ OPENAI_API_KEY is set"
else
    echo "⚠️  OPENAI_API_KEY is NOT set (required for AI features)"
fi

echo "   DB_PROVIDER: ${DB_PROVIDER:-sqlite}"
echo "   ENVIRONMENT: ${ENVIRONMENT:-production}"
echo ""

# 7. 检查 supervisor 状态
echo "7. Checking supervisor status..."
if command -v supervisorctl >/dev/null 2>&1; then
    supervisorctl status 2>/dev/null || echo "   (supervisor not responding)"
else
    echo "   (supervisorctl not available)"
fi
echo ""

# 8. 最近的错误日志
echo "8. Recent error logs (if any)..."
echo "--- Nginx errors (last 10 lines) ---"
if [ -f /var/log/nginx/error.log ]; then
    tail -10 /var/log/nginx/error.log 2>/dev/null || echo "   (no errors or no access)"
else
    echo "   (log file not found)"
fi
echo ""

echo "=========================================="
echo "Health check complete!"
echo "=========================================="

