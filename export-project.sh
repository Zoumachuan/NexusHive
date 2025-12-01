#!/bin/bash
################################################################################
# 旧服务器 - 导出项目脚本
# 用途: 打包后端代码、前端代码、数据库
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  NexusHive 项目导出${NC}"
echo -e "${GREEN}================================${NC}"

BACKUP_DIR="/root/nexushive-backup"
BACKUP_FILE="/root/nexushive-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

rm -rf $BACKUP_DIR
mkdir -p $BACKUP_DIR

echo -e "${YELLOW}[1/5] 导出后端代码...${NC}"
mkdir -p $BACKUP_DIR/backend
cd /root/NexusHive/NexusHive
tar czf $BACKUP_DIR/backend/code.tar.gz \
    --exclude=runtime \
    --exclude=vendor \
    --exclude=.git \
    .

echo -e "${YELLOW}[2/5] 导出前端代码...${NC}"
mkdir -p $BACKUP_DIR/frontend
cd /root/NexusHive/Nexus-Hive-Web
tar czf $BACKUP_DIR/frontend/code.tar.gz \
    --exclude=node_modules \
    --exclude=dist \
    --exclude=.git \
    .

echo -e "${YELLOW}[3/5] 导出数据库...${NC}"
# 从Docker导出
docker exec nexushive_mysql mysqldump -uroot -pmysql_ppiXys nexushive > $BACKUP_DIR/database.sql

# 如果没用Docker
# mysqldump -uroot -p nexushive > $BACKUP_DIR/database.sql

echo -e "${YELLOW}[4/5] 导出上传文件...${NC}"
if [ -d "/root/NexusHive/NexusHive/public/uploads" ]; then
    mkdir -p $BACKUP_DIR/uploads
    cp -r /root/NexusHive/NexusHive/public/uploads/* $BACKUP_DIR/uploads/
fi

echo -e "${YELLOW}[5/5] 打包所有文件...${NC}"
cd /root
tar czf $BACKUP_FILE nexushive-backup/

rm -rf $BACKUP_DIR

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  导出完成!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${GREEN}备份文件: ${BACKUP_FILE}${NC}"
echo -e "文件大小: $(du -h $BACKUP_FILE | cut -f1)"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "使用 scp 或 SFTP 上传到新服务器:"
echo -e "${GREEN}scp ${BACKUP_FILE} root@新服务器IP:/root/${NC}"
