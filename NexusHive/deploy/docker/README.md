# Docker 部署指南

目录位于 `deploy/docker/`，包含一键启动所需文件。

## 前提
- 服务器已安装 Docker 和 Docker Compose Plugin
- DNS 已指向服务器（用于 `DOMAIN`）

## 配置
编辑 `.env`（默认内容已填入你提供的参数）：

```
DOMAIN=fkbs.chuangxing.ren
DB_NAME=fk
DB_USER=feikong
DB_PASS=123456
MYSQL_ROOT_PASSWORD=StrongRootPwd!123
TIMEZONE=Asia/Shanghai
```

如需初始化 SQL，将文件放到 `deploy/docker/db-init/` 目录（首次启动且数据卷为空时会自动执行）。

### 数据库初始化说明
- 自动导入触发条件：首次启动且 `mysql_data` 数据卷为空；`deploy/docker/db-init/` 下的 `.sql/.sql.gz/.sh` 会被依次执行（由官方 `mysql:5.7` 入口脚本处理）。
- 日志确认执行：
```bash
docker compose logs -f mysql
```
- 已有数据（数据卷不为空）时的导入方式：
  - 方式 A（推荐）：在现有库中手动导入 SQL
```bash
docker compose exec -T mysql sh -c "mysql -u root -p${MYSQL_ROOT_PASSWORD} ${DB_NAME}" < ./db-init/fly.sql
```
  - 方式 B（会清空数据）：删除数据卷后重启（谨慎使用）
```bash
docker compose down
docker volume rm fly-sys_mysql_data
docker compose up -d
```


## 启动
在服务器执行：

```bash
cd deploy/docker
docker compose up -d
```

启动后访问：
- 站点：http://fkbs.chuangxing.ren
- MQTT WebSocket：通过 Nginx 反向代理 `http://fkbs.chuangxing.ren/mqtt/`

## 常用操作
- 查看服务状态：`docker compose ps`
- 查看日志：`docker compose logs -f nginx php mysql redis emqx`
- 重启某服务：`docker compose restart php`
- 停止并移除：`docker compose down`
- 停止但保留数据卷：`docker compose down --volumes=false`

## 说明
- Nginx 仅暴露 80 端口；EMQX 不直接对外暴露，走 Nginx `/mqtt/` 反代
- MySQL 和 Redis 使用容器名作为主机名：`mysql`、`redis`
- PHP 镜像已安装常用扩展：pdo_mysql、mysqli、gd、mbstring、bcmath、zip、intl、redis
- 如需 HTTPS，请在 Nginx 中配置证书或在外层反向代理启用
