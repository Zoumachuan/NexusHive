#!/bin/bash
# NexusHive 快速部署脚本（代码已通过git clone获取）

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  NexusHive 快速部署${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 获取配置信息
echo -e "${YELLOW}请输入服务器IP:${NC}"
read SERVER_IP

echo -e "${YELLOW}请输入MySQL root密码:${NC}"
read -s MYSQL_PASSWORD
echo ""

echo -e "${YELLOW}请输入Redis密码(如无密码直接回车):${NC}"
read -s REDIS_PASSWORD
echo ""

echo -e "${YELLOW}请输入MySQL容器名(如: 1Panel-mysql-k1fL):${NC}"
read MYSQL_CONTAINER

echo -e "${YELLOW}[1/5] 配置后端环境...${NC}"
cd /root/NexusHive/NexusHive

# 创建.env文件
cat > .env <<ENVEOF
APP_DEBUG = false

[APP]
DEFAULT_TIMEZONE = Asia/Shanghai

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
ENVEOF

# 安装后端依赖
composer install --no-dev --optimize-autoloader

# 设置权限
chmod -R 755 /root/NexusHive/NexusHive
chmod -R 777 /root/NexusHive/NexusHive/runtime

echo -e "${YELLOW}[2/5] 导入数据库...${NC}"
if [ -f "/root/nexushive-backup/database.sql" ]; then
    docker exec -i ${MYSQL_CONTAINER} mysql -uroot -p${MYSQL_PASSWORD} nexushive < /root/nexushive-backup/database.sql
    echo -e "${GREEN}✓ 数据库导入完成${NC}"
else
    echo -e "${YELLOW}未找到备份数据库，跳过导入${NC}"
fi

echo -e "${YELLOW}[3/5] 配置前端环境...${NC}"
cd /root/NexusHive/Nexus-Hive-Web

# 创建前端配置
cat > .env.production <<ENVEOF
VITE_API_URL=http://${SERVER_IP}:8000
VITE_MQTT_URL=ws://${SERVER_IP}:8083/mqtt
ENVEOF

# 安装依赖并构建
pnpm install
pnpm build

echo -e "${YELLOW}[4/5] 配置systemd服务...${NC}"
cat > /etc/systemd/system/nexushive-backend.service <<SERVICEEOF
[Unit]
Description=NexusHive Backend Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/NexusHive/NexusHive
ExecStart=/usr/bin/php /root/NexusHive/NexusHive/think run -H 0.0.0.0 -p 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable nexushive-backend
systemctl start nexushive-backend

echo -e "${YELLOW}[5/5] 生成OpenResty配置...${NC}"
cat > /tmp/nexushive.conf <<NGINXEOF
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
NGINXEOF

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  部署完成!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}剩余手动操作:${NC}"
echo "1. 将 /tmp/nexushive.conf 添加到OpenResty配置目录"
echo "2. 重启OpenResty"
echo ""
echo -e "${GREEN}访问地址:${NC}"
echo "前端: http://${SERVER_IP}"
echo "后端API: http://${SERVER_IP}:8000"
echo ""
echo -e "${GREEN}服务状态:${NC}"
systemctl status nexushive-backend --no-pager
