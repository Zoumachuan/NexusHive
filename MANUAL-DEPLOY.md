# NexusHive 手动迁移指南

如果脚本执行失败,可以按照此指南手动操作

## 一、新服务器环境准备

### 1. 安装Docker
```bash
curl -fsSL https://get.docker.com | bash
systemctl start docker
systemctl enable docker
```

### 2. 安装Docker Compose
```bash
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 3. 创建docker-compose.yml
```bash
mkdir -p /data/nexushive
cd /data/nexushive

cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  mysql:
    image: mysql:5.7
    container_name: nexushive_mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 你的密码
      MYSQL_DATABASE: nexushive
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:6.0-alpine
    container_name: nexushive_redis
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - ./redis:/data

  emqx:
    image: emqx/emqx:latest
    container_name: nexushive_emqx
    restart: always
    ports:
      - "1883:1883"
      - "8083:8083"
      - "18083:18083"
    volumes:
      - ./emqx:/opt/emqx/data

  nginx:
    image: nginx:alpine
    container_name: nexushive_nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - /www/nexushive/frontend/dist:/usr/share/nginx/html
      - ./nginx:/etc/nginx/conf.d
EOF

docker-compose up -d
```

### 4. 安装PHP环境
```bash
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y php8.1-fpm php8.1-cli php8.1-mysql php8.1-redis \
    php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip
```

### 5. 安装Composer
```bash
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
```

### 6. 安装Node.js和pnpm
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g pnpm
```

---

## 二、导出旧服务器数据

### 1. 导出数据库
```bash
# 如果用Docker
docker exec nexushive_mysql mysqldump -uroot -p nexushive > /root/nexushive.sql

# 如果直接装的MySQL
mysqldump -uroot -p nexushive > /root/nexushive.sql
```

### 2. 打包后端代码
```bash
cd /root/NexusHive
tar czf nexushive-backend.tar.gz \
    --exclude=NexusHive/runtime \
    --exclude=NexusHive/vendor \
    NexusHive/
```

### 3. 打包前端代码
```bash
cd /root/NexusHive
tar czf nexushive-frontend.tar.gz \
    --exclude=Nexus-Hive-Web/node_modules \
    --exclude=Nexus-Hive-Web/dist \
    Nexus-Hive-Web/
```

### 4. 上传到新服务器
```bash
scp nexushive-backend.tar.gz root@新IP:/root/
scp nexushive-frontend.tar.gz root@新IP:/root/
scp nexushive.sql root@新IP:/root/
```

---

## 三、新服务器部署

### 1. 解压后端代码
```bash
mkdir -p /www/nexushive/backend
cd /www/nexushive/backend
tar xzf /root/nexushive-backend.tar.gz --strip-components=1
```

### 2. 配置后端环境
```bash
# 修改.env文件
vim /www/nexushive/backend/.env

# 修改这些配置:
DATABASE = nexushive
HOSTNAME = 127.0.0.1
USERNAME = root
PASSWORD = 你的MySQL密码

[REDIS]
HOST = 127.0.0.1
PORT = 6379
```

### 3. 安装后端依赖
```bash
cd /www/nexushive/backend
composer install --no-dev
chmod -R 777 runtime
```

### 4. 导入数据库
```bash
# 等MySQL启动完成
sleep 10

# 导入数据
docker exec -i nexushive_mysql mysql -uroot -p你的密码 nexushive < /root/nexushive.sql
```

### 5. 部署前端
```bash
mkdir -p /www/nexushive/frontend
cd /www/nexushive/frontend
tar xzf /root/nexushive-frontend.tar.gz --strip-components=1

# 修改环境变量
vim .env.production
# VITE_AXIOS_BASE_URL='http://新服务器IP:8000'

# 构建
pnpm install
pnpm build

# 复制到Nginx
cp -r dist/* /www/nexushive/frontend/dist/
```

### 6. 配置Nginx
```bash
cat > /data/nexushive/nginx/default.conf <<'EOF'
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://宿主机IP:8000;
        proxy_set_header Host $host;
    }
}
EOF

docker restart nexushive_nginx
```

### 7. 启动后端服务
```bash
cd /www/nexushive/backend
nohup php think worker:server start > /var/log/nexushive-backend.log 2>&1 &
```

---

## 四、验证部署

```bash
# 检查容器
docker ps

# 检查后端
curl http://localhost:8000/api/common/init

# 检查前端
curl http://localhost

# 查看日志
tail -f /var/log/nexushive-backend.log
```

---

## 五、常见问题

### 问题1: 前端访问404
```bash
# 检查Nginx配置
docker logs nexushive_nginx

# 检查文件权限
ls -la /www/nexushive/frontend/dist
```

### 问题2: 后端连不上数据库
```bash
# 检查MySQL状态
docker exec nexushive_mysql mysql -uroot -p -e "SHOW DATABASES;"

# 检查.env配置
cat /www/nexushive/backend/.env | grep DATABASE
```

### 问题3: MQTT连不上
```bash
# 检查EMQX状态
docker logs nexushive_emqx

# 访问管理界面
http://新IP:18083 (admin/public)
```

### 问题4: 端口被占用
```bash
# 查看端口占用
netstat -tuln | grep -E '80|3306|6379|1883|8083'

# 停止冲突服务
systemctl stop mysql  # 如果本地装了MySQL
systemctl stop nginx  # 如果本地装了Nginx
```
