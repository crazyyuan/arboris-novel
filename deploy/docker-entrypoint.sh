#!/bin/sh

set -e

echo "=========================================="
echo "Arboris Novel Generator - Starting up"
echo "=========================================="

STORAGE_DIR="${STORAGE_DIR:-/app/storage}"

# 确保存储目录存在，处理首次启动或宿主机空目录的情况
if [ ! -d "$STORAGE_DIR" ]; then
    echo "Creating storage directory: $STORAGE_DIR"
    mkdir -p "$STORAGE_DIR"
fi

# 检查目录所有权是否为应用用户，若不是则修正以避免挂载权限问题
if [ "$(stat -c %u "$STORAGE_DIR" 2>/dev/null || echo)" != "1000" ] || \
   [ "$(stat -c %g "$STORAGE_DIR" 2>/dev/null || echo)" != "1000" ]; then
    echo "Adjusting storage directory ownership..."
    chown -R appuser:appuser "$STORAGE_DIR" || echo "Warning: unable to adjust ownership of $STORAGE_DIR"
fi

# 检查必需的环境变量
echo "Checking environment variables..."
if [ -z "$SECRET_KEY" ]; then
    echo "ERROR: SECRET_KEY is not set!"
    exit 1
fi

echo "Environment: ${ENVIRONMENT:-production}"
echo "Database Provider: ${DB_PROVIDER:-sqlite}"
echo "Storage Directory: $STORAGE_DIR"

# 等待一下确保文件系统就绪（特别是在 Coolify 等平台上）
sleep 2

echo "Starting supervisord..."
echo "=========================================="

exec "$@"
