#!/bin/bash
################################################################################
# 新服务器 - 导入项目脚本
# 用途: 解压代码、恢复数据库、配置环境
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  NexusHive 项目导入${NC}"
echo -e "${GREEN}================================${NC}"

# 检查备份文件
BACKUP_FILE=$(ls -t /root/nexushive-backup-*.tar.gz 2>/dev/null | head -1)
if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}错误: 未找到备份文件${NC}"
    echo "请先上传 nexushive-backup-*.tar.gz 到 /root/"
    exit 1
fi

echo -e "${YELLOW}找到备份: ${BACKUP_FILE}${NC}"

# 获取MySQL密码
echo -e "${YELLOW}请输入MySQL root密码(甲方已安装):${NC}"
read -s MYSQL_PASSWORD
echo ""

if [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}错误: MySQL密码不能为空${NC}"
    exit 1
fi

# 获取Redis密码
echo -e "${YELLOW}请输入Redis密码(甲方已安装,如无密码直接回车):${NC}"
read -s REDIS_PASSWORD
echo ""

echo -e "${YELLOW}[1/6] 解压备份文件...${NC}"
cd /root
tar xzf $BACKUP_FILE

echo -e "${YELLOW}[2/6] 恢复后端代码...${NC}"
mkdir -p /www/nexushive/backend
cd /www/nexushive/backend
tar xzf /root/nexushive-backup/backend/code.tar.gz

echo -e "${YELLOW}[3/6] 配置后端环境...${NC}"
# 更新.env文件
cat > /www/nexushive/backend/.env <<EOF
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
DEBUG = false

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

# 安装依赖
cd /www/nexushive/backend
composer install --no-dev --optimize-autoloader

# 设置权限
chown -R www-data:www-data /www/nexushive/backend
chmod -R 755 /www/nexushive/backend
chmod -R 777 /www/nexushive/backend/runtime

echo -e "${YELLOW}[4/6] 恢复数据库...${NC}"
# 导入到甲方已安装的MySQL
mysql -uroot -p${MYSQL_PASSWORD} nexushive < /root/nexushive-backup/database.sql

if [ $? -ne 0 ]; then
    echo -e "${RED}数据库导入失败,请检查:${NC}"
    echo "1. MySQL是否正常运行?"
    echo "2. nexushive数据库是否已创建?"
    echo "3. root密码是否正确?"
    exit 1
fi

echo -e "${GREEN}✓ 数据库导入成功${NC}"

echo -e "${YELLOW}[5/6] 恢复前端代码...${NC}"
cd /www/nexushive/frontend
tar xzf /root/nexushive-backup/frontend/code.tar.gz

# 获取服务器公网IP
SERVER_IP=$(curl -s ifconfig.me)

# 更新前端环境变量
cat > /www/nexushive/frontend/.env.production <<EOF
NODE_ENV=production
VITE_AXIOS_BASE_URL='http://${SERVER_IP}:8000'
VITE_MQTT_HOST='${SERVER_IP}'
VITE_MQTT_PORT=1883
VITE_MQTT_WS_PORT=8083
EOF

# 安装依赖并构建
cd /www/nexushive/frontend
pnpm install
pnpm build

# 部署到OpenResty
echo -e "${YELLOW}OpenResty配置文件需要手动创建:${NC}"
cat > /tmp/nexushive-nginx.conf <<EOF
server {
    listen 80;
    server_name ${SERVER_IP};
    
    root /www/nexushive/frontend/dist;
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
        alias /www/nexushive/backend/public/uploads;
    }
}
EOF

echo -e "${GREEN}配置文件已生成: /tmp/nexushive-nginx.conf${NC}"
echo -e "${YELLOW}请将此配置添加到OpenResty配置目录${NC}"
echo ""

echo -e "${YELLOW}[6/6] 配置完成提示...${NC}"

echo -e "${YELLOW}[7/7] 启动后端服务...${NC}"
cd /www/nexushive/backend

# 创建systemd服务
cat > /etc/systemd/system/nexushive-backend.service <<EOF
[Unit]
Description=NexusHive Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/www/nexushive/backend
ExecStart=/usr/bin/php /www/nexushive/backend/think worker:server start
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nexushive-backend
systemctl start nexushive-backend

# 恢复上传文件
if [ -d "/root/nexushive-backup/uploads" ]; then
    echo -e "${YELLOW}恢复上传文件...${NC}"
    mkdir -p /www/nexushive/backend/public/uploads
    cp -r /root/nexushive-backup/uploads/* /www/nexushive/backend/public/uploads/
    chown -R www-data:www-data /www/nexushive/backend/public/uploads
fi

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  代码部署完成!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}剩余手动操作:${NC}"
echo "1. 将 /tmp/nexushive-nginx.conf 添加到OpenResty配置"
echo "2. 重启OpenResty: systemctl restart openresty"
echo "3. 检查后端服务: systemctl status nexushive-backend"
echo ""
echo -e "${GREEN}访问地址:${NC}"
echo "前端: http://${SERVER_IP}"
echo "后端API: http://${SERVER_IP}:8000"
echo "EMQX管理: http://${SERVER_IP}:18083 (admin/public)"
echo ""
echo -e "${GREEN}服务状态:${NC}"
echo "MySQL: (甲方已安装)"
echo "Redis: (甲方已安装)"
echo "EMQX: $(docker ps --filter name=nexushive_emqx --format '{{.Status}}')"
echo "后端: $(systemctl is-active nexushive-backend)"
echo ""
echo -e "${YELLOW}清理备份文件:${NC}"
echo "rm -rf /root/nexushive-backup*"
