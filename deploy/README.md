# 部署说明（LKX）

当前为骨架阶段，仅提供可直接使用的 MySQL 服务；后端容器的 Dockerfile 待补。

## 目录

| 文件 | 用途 |
| --- | --- |
| compose.yaml | Docker Compose 编排 |
| Dockerfile.server | TODO：Drogon 后端镜像构建文件（多阶段：构建 → 运行） |
| .env | 本地机密，不入库（见根 .gitignore） |

## 使用

```bash
# 1. 在 deploy/ 下创建 .env（不入库）
cat > .env <<'EOF'
MYSQL_ROOT_PASSWORD=改成强密码
MYSQL_USER=libra
MYSQL_PASSWORD=改成强密码
EOF

# 2. 只起数据库（server 的 Dockerfile 补齐前，不要启动全部）
docker compose up -d mysql

# 3. Dockerfile.server 就绪后
docker compose up -d --build
```

首次启动会自动执行 `database/schema.sql` 与 `database/seed.sql` 初始化数据。

## 注意事项

- 数据库端口 3306 已映射到宿主机，公网部署建议改为只监听内网并用防火墙限制。
- 后端监听端口 8080，与 Drogon `config.json` 中的 listeners 保持一致。
- 服务器安全组需放行 8080（API 对外），3306 不要对外暴露。
