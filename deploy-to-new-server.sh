#!/bin/bash
################################################################################
# NexusHive 一键部署脚本 - 新服务器部署
# 用途: 快速在新服务器上部署前后端+数据库+EMQX
# 作者: GitHub Copilot
# 日期: 2025-12-01
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  NexusHive 一键部署脚本${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 检查是否root权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root权限运行: sudo bash deploy-to-new-server.sh${NC}"
    exit 1
fi

# 配置变量
NEW_SERVER_IP="请替换为新服务器IP"
MYSQL_ROOT_PASSWORD="mysql_$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12)"
MYSQL_DB_NAME="nexushive"
DOMAIN_NAME="your-domain.com"  # 如果有域名就填,没有填IP

echo -e "${YELLOW}[1/10] 更新系统软件包...${NC}"
apt-get update -qq
apt-get upgrade -y -qq

echo -e "${YELLOW}[2/10] 安装基础软件...${NC}"
apt-get install -y -qq \
    curl wget git vim unzip \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

echo -e "${YELLOW}[3/10] 安装Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}✓ Docker安装完成${NC}"
else
    echo -e "${GREEN}✓ Docker已安装,跳过${NC}"
fi

echo -e "${YELLOW}[4/10] 安装Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose安装完成${NC}"
else
    echo -e "${GREEN}✓ Docker Compose已安装,跳过${NC}"
fi

echo -e "${YELLOW}[5/10] 创建项目目录...${NC}"
mkdir -p /data/nexushive/{mysql,redis,emqx,logs,nginx,uploads}
mkdir -p /www/nexushive/{backend,frontend}

echo -e "${YELLOW}[6/10] 创建Docker Compose配置...${NC}"
cat > /data/nexushive/docker-compose.yml <<EOF
version: '3.8'

services:
  # MySQL数据库
  mysql:
    image: mysql:5.7
    container_name: nexushive_mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DB_NAME}
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - /data/nexushive/mysql:/var/lib/mysql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

  # Redis缓存
  redis:
    image: redis:6.0-alpine
    container_name: nexushive_redis
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - /data/nexushive/redis:/data
    command: redis-server --appendonly yes

  # EMQX MQTT服务器
  emqx:
    image: emqx/emqx:latest
    container_name: nexushive_emqx
    restart: always
    environment:
      - EMQX_NAME=nexushive
      - EMQX_HOST=127.0.0.1
    ports:
      - "1883:1883"      # MQTT
      - "8083:8083"      # WebSocket
      - "18083:18083"    # Dashboard
    volumes:
      - /data/nexushive/emqx:/opt/emqx/data

  # Nginx反向代理
  nginx:
    image: nginx:alpine
    container_name: nexushive_nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /www/nexushive/frontend:/usr/share/nginx/html
      - /data/nexushive/nginx:/etc/nginx/conf.d
      - /data/nexushive/logs:/var/log/nginx
    depends_on:
      - mysql
      - redis
      - emqx

networks:
  default:
    name: nexushive_network
EOF

echo -e "${YELLOW}[7/10] 启动Docker容器...${NC}"
cd /data/nexushive
docker-compose up -d

# 等待MySQL启动
echo -e "${YELLOW}等待MySQL启动(30秒)...${NC}"
sleep 30

echo -e "${YELLOW}[8/10] 安装PHP 8.1和相关扩展...${NC}"
add-apt-repository ppa:ondrej/php -y
apt-get update -qq
apt-get install -y -qq \
    php8.1-fpm php8.1-cli php8.1-common \
    php8.1-mysql php8.1-redis php8.1-curl \
    php8.1-gd php8.1-mbstring php8.1-xml \
    php8.1-zip php8.1-bcmath php8.1-intl

# 配置PHP-FPM
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.1/fpm/php.ini
systemctl restart php8.1-fpm
systemctl enable php8.1-fpm

echo -e "${YELLOW}[9/10] 安装Composer...${NC}"
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

echo -e "${YELLOW}[10/10] 安装Node.js 20.x和pnpm...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm
fi

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  基础环境安装完成!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}MySQL密码: ${MYSQL_ROOT_PASSWORD}${NC}"
echo -e "${YELLOW}请保存到安全的地方!${NC}"
echo ""
echo -e "${GREEN}下一步操作:${NC}"
echo "1. 在旧服务器执行: bash /root/NexusHive/export-project.sh"
echo "2. 将生成的 nexushive-backup.tar.gz 上传到新服务器"
echo "3. 在新服务器执行: bash /root/NexusHive/import-project.sh"
echo ""
echo -e "${YELLOW}容器状态:${NC}"
docker-compose ps

# 保存配置信息
cat > /root/nexushive-config.txt <<EOF
NexusHive服务器配置信息
======================
服务器IP: ${NEW_SERVER_IP}
MySQL密码: ${MYSQL_ROOT_PASSWORD}
数据库名: ${MYSQL_DB_NAME}

访问地址:
- 前端: http://${NEW_SERVER_IP}
- EMQX管理: http://${NEW_SERVER_IP}:18083 (admin/public)

目录结构:
- 后端代码: /www/nexushive/backend
- 前端代码: /www/nexushive/frontend
- 数据目录: /data/nexushive

生成时间: $(date)
EOF

echo -e "${GREEN}配置信息已保存到: /root/nexushive-config.txt${NC}"
