# NexusHive - 无人机云端管理平台

## 项目简介

NexusHive是一个支持多品牌无人机的云端管理平台,提供实时监控、航线规划、数据分析等功能。

### 支持设备
- ✅ DJI大疆无人机(Dock 2/3 + M3D/M4D)
- ✅ ACFLY开源无人机(基于MAVLink协议)
- 🔄 更多品牌适配中...

### 核心功能
- 🗺️ 实时地图监控(2D百度地图 + 3D Mars3D)
- 📡 MQTT物联网协议数据传输
- 🎯 航线任务管理
- 📊 飞行数据分析
- 🔐 多用户权限管理
- 📱 响应式Web界面

## 技术栈

### 后端
- ThinkPHP 8.1.1
- PHP 8.1+
- MySQL 5.7+
- Redis 6.0+
- EMQX MQTT Broker

### 前端
- Vue 3.5.13
- Vite 6.3.5
- TypeScript 5.7.2
- Pinia 2.3.0
- Mars3D 3.10.0
- 百度地图API

## 快速开始

### 环境要求
- PHP >= 8.1
- MySQL >= 5.7
- Redis >= 6.0
- Node.js >= 20.0
- Composer
- pnpm

### 一键部署(推荐)

```bash
# 新服务器初始化
wget https://raw.githubusercontent.com/你的用户名/NexusHive/main/deploy-to-new-server.sh
chmod +x deploy-to-new-server.sh
sudo bash deploy-to-new-server.sh
```

### 手动部署

详细步骤请参考 [MANUAL-DEPLOY.md](./MANUAL-DEPLOY.md)

## 项目迁移

### 从旧服务器导出
```bash
cd /path/to/NexusHive
bash export-project.sh
```

### 导入到新服务器
```bash
scp nexushive-backup-*.tar.gz root@新服务器:/root/
ssh root@新服务器
bash import-project.sh
```

## 配置说明

### 后端配置 (.env)
```ini
[DATABASE]
HOSTNAME = 127.0.0.1
DATABASE = nexushive
USERNAME = root
PASSWORD = your_password

[REDIS]
HOST = 127.0.0.1
PORT = 6379

[MQTT]
HOST = 127.0.0.1
PORT = 1883
USERNAME = nexushive
PASSWORD = your_mqtt_password
```

### 前端配置 (.env.production)
```bash
VITE_AXIOS_BASE_URL='http://your-server-ip:8000'
VITE_MQTT_HOST='your-server-ip'
VITE_MQTT_PORT=1883
VITE_MQTT_WS_PORT=8083
```

## 访问地址

- 前端管理界面: `http://your-server-ip`
- 后端API: `http://your-server-ip:8000`
- EMQX管理后台: `http://your-server-ip:18083` (admin/public)

## 项目结构

```
NexusHive/
├── NexusHive/                 # 后端代码(ThinkPHP)
│   ├── app/                   # 应用目录
│   │   ├── admin/            # 管理后台模块
│   │   ├── api/              # API接口模块
│   │   └── common/           # 公共模块
│   ├── config/               # 配置文件
│   ├── extend/               # 扩展类库
│   │   ├── dji/             # DJI设备适配
│   │   ├── mqtt/            # MQTT处理
│   │   └── acfly/           # ACFLY设备适配(开发中)
│   ├── public/              # 静态资源
│   └── runtime/             # 运行时文件
│
├── Nexus-Hive-Web/          # 前端代码(Vue3)
│   ├── src/
│   │   ├── api/            # API封装
│   │   ├── components/     # 公共组件
│   │   ├── views/          # 页面视图
│   │   ├── stores/         # Pinia状态管理
│   │   └── router/         # 路由配置
│   └── public/
│       ├── config/         # 地图配置
│       └── model/          # 3D模型
│
├── deploy-to-new-server.sh  # 一键部署脚本
├── export-project.sh        # 项目导出脚本
└── import-project.sh        # 项目导入脚本
```

## ACFLY开源无人机适配

### 协议支持
- ✅ MAVLink 1.0/2.0
- ✅ JSON状态上报
- ✅ MQTT数据传输
- 🔄 远程控制指令(开发中)

### 现场部署

在地面站电脑运行Python桥接脚本:
```bash
pip3 install paho-mqtt
python3 acfly_mqtt_bridge.py
```

详细协议说明: [ACFLY地面站与飞控交互协议.md](./ACFLY地面站与飞控交互协议.md)

## 开发指南

### 后端开发
```bash
cd NexusHive
composer install
php think run
```

### 前端开发
```bash
cd Nexus-Hive-Web
pnpm install
pnpm dev
```

## 数据库迁移

```bash
# 导出
php think migrate:run

# 导入
mysql -u root -p nexushive < database.sql
```

## Docker部署

```bash
cd /data/nexushive
docker-compose up -d

# 查看容器状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

## 常见问题

### 1. MQTT连接失败
检查EMQX服务状态:
```bash
docker logs nexushive_emqx
```
访问管理界面配置用户: http://ip:18083

### 2. 前端访问404
检查Nginx配置和文件权限:
```bash
docker logs nexushive_nginx
ls -la /www/nexushive/frontend/dist
```

### 3. 数据库连接失败
检查MySQL容器和配置:
```bash
docker exec nexushive_mysql mysql -uroot -p -e "SHOW DATABASES;"
```

更多问题请查看: [MANUAL-DEPLOY.md](./MANUAL-DEPLOY.md)

## 许可证

MIT License

## 作者

- 项目维护: [你的GitHub用户名]
- 技术支持: [联系方式]

## 致谢

- [BuildAdmin](https://buildadmin.com/) - 后端框架基础
- [Mars3D](http://mars3d.cn/) - 三维地图引擎
- [EMQX](https://www.emqx.io/) - MQTT服务器
- [ACFLY](https://www.acfly.cn/) - 开源飞控协议支持
