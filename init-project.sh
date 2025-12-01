#!/bin/bash

# NexusHive 项目初始化脚本
# 用于在已安装环境的服务器上初始化项目

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  NexusHive 项目初始化${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 获取MySQL容器信息
echo -e "${YELLOW}请输入MySQL Docker容器名称:${NC}"
read MYSQL_CONTAINER
if [ -z "$MYSQL_CONTAINER" ]; then
    echo -e "${RED}错误: 容器名不能为空${NC}"
    exit 1
fi

echo -e "${YELLOW}请输入MySQL root密码:${NC}"
read -s MYSQL_PASSWORD
echo ""
if [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}错误: MySQL密码不能为空${NC}"
    exit 1
fi

echo -e "${YELLOW}请输入Redis密码(如无密码直接回车):${NC}"
read -s REDIS_PASSWORD
echo ""

echo -e "${YELLOW}请输入服务器IP地址:${NC}"
read SERVER_IP
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}错误: 服务器IP不能为空${NC}"
    exit 1
fi

# ===================================
# 1. 配置后端
# ===================================
echo -e "${YELLOW}[1/5] 配置后端...${NC}"
cd /root/NexusHive/NexusHive

cat > .env <<EOF
APP_DEBUG = false

[DATABASE]
TYPE = mysql
HOSTNAME = 127.0.0.1
DATABASE = nexushive
USERNAME = root
PASSWORD = ${MYSQL_PASSWORD}
HOSTPORT = 3306
CHARSET = utf8mb4
PREFIX = ba_

[REDIS]
HOST = 127.0.0.1
PORT = 6379
PASSWORD = ${REDIS_PASSWORD}
SELECT = 0

[MQTT]
HOST = 127.0.0.1
PORT = 1883
USERNAME = nexushive
PASSWORD = nexushive123
EOF

echo -e "${GREEN}✓ 后端配置完成${NC}"

# ===================================
# 安装后端依赖
# ===================================
echo -e "${YELLOW}[2/5] 安装后端依赖...${NC}"
composer install --no-dev --optimize-autoloader

# 创建必要的目录
mkdir -p /root/NexusHive/NexusHive/runtime
mkdir -p /root/NexusHive/NexusHive/public/uploads

# 设置权限
chmod -R 755 /root/NexusHive/NexusHive
chmod -R 777 /root/NexusHive/NexusHive/runtime
chmod -R 777 /root/NexusHive/NexusHive/public/uploads

echo -e "${GREEN}✓ 后端依赖安装完成${NC}"

# ===================================
# 3. 初始化数据库
# ===================================
echo -e "${YELLOW}[3/5] 初始化数据库...${NC}"

# 检查是否有SQL初始化文件
if [ -f "/root/NexusHive/NexusHive/database.sql" ]; then
    echo "导入数据库结构..."
    docker exec -i ${MYSQL_CONTAINER} mysql -uroot -p${MYSQL_PASSWORD} nexushive < /root/NexusHive/NexusHive/database.sql
    echo -e "${GREEN}✓ 数据库导入完成${NC}"
elif [ -d "/root/NexusHive/NexusHive/database/migrations" ]; then
    echo "运行数据库迁移..."
    cd /root/NexusHive/NexusHive
    php think migrate:run
    echo -e "${GREEN}✓ 数据库迁移完成${NC}"
else
    echo -e "${YELLOW}未找到数据库初始化文件,跳过${NC}"
fi

# ===================================
# 4. 编译前端
# ===================================
echo -e "${YELLOW}[4/5] 编译前端...${NC}"
cd /root/NexusHive/Nexus-Hive-Web

# 更新API地址
if [ -f "src/api/common.ts" ]; then
    sed -i "s|http://localhost:8000|http://${SERVER_IP}:8000|g" src/api/common.ts
fi

echo -e "${YELLOW}安装依赖...${NC}"
pnpm install

echo -e "${YELLOW}开始编译(限制内存使用，可能需要10-15分钟)...${NC}"
# 限制Node.js内存使用，避免OOM
export NODE_OPTIONS="--max-old-space-size=1536"
pnpm build

echo -e "${GREEN}✓ 前端编译完成${NC}"

# ===================================
# 5. 配置systemd服务
# ===================================
echo -e "${YELLOW}[5/5] 配置后端服务...${NC}"

cat > /etc/systemd/system/nexushive-backend.service <<EOF
[Unit]
Description=NexusHive Backend Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/NexusHive/NexusHive
ExecStart=/usr/bin/php think run -H 0.0.0.0 -p 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nexushive-backend
systemctl start nexushive-backend

echo -e "${GREEN}✓ 后端服务已启动${NC}"

# ===================================
# 生成OpenResty配置
# ===================================
echo -e "${YELLOW}生成OpenResty配置文件...${NC}"

cat > /tmp/nexushive-openresty.conf <<EOF
server {
    listen 80;
    server_name ${SERVER_IP};
    
    root /root/NexusHive/Nexus-Hive-Web/dist;
    index index.html;

    # 前端静态文件
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # 后端API代理
    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # MQTT WebSocket代理
    location /mqtt {
        proxy_pass http://127.0.0.1:8083;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
    }

    # 上传文件
    location /uploads {
        alias /root/NexusHive/NexusHive/public/uploads;
    }
}
EOF

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  初始化完成!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. 将 /tmp/nexushive-openresty.conf 添加到OpenResty配置"
echo "   通常位置: /usr/local/openresty/nginx/conf/conf.d/"
echo ""
echo "2. 重启OpenResty:"
echo "   systemctl restart openresty"
echo ""
echo -e "${GREEN}访问地址:${NC}"
echo "前端: http://${SERVER_IP}"
echo "后端API: http://${SERVER_IP}:8000"
echo "EMQX管理: http://${SERVER_IP}:18083 (admin/public)"
echo ""
echo -e "${GREEN}服务状态:${NC}"
echo "后端: $(systemctl is-active nexushive-backend)"
echo "EMQX: $(docker ps --filter name=nexushive_emqx --format '{{.Status}}')"
echo ""
echo -e "${YELLOW}配置文件已保存到: /root/nexushive-deployment-info.txt${NC}"

# 保存部署信息
cat > /root/nexushive-deployment-info.txt <<EOF
NexusHive 部署信息
==================
部署时间: $(date)
服务器IP: ${SERVER_IP}

目录结构:
- 后端代码: /root/NexusHive/NexusHive
- 前端代码: /root/NexusHive/Nexus-Hive-Web
- 前端构建: /root/NexusHive/Nexus-Hive-Web/dist

数据库配置:
- MySQL容器: ${MYSQL_CONTAINER}
- 数据库名: nexushive
- Redis密码: ${REDIS_PASSWORD}

访问地址:
- 前端: http://${SERVER_IP}
- 后端API: http://${SERVER_IP}:8000
- EMQX管理: http://${SERVER_IP}:18083

OpenResty配置文件: /tmp/nexushive-openresty.conf
EOF
