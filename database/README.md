# 数据库初始化与维护（zyj）

> 对应 README 第 7 节要求的 `database/README.md`；数据模型见 [`docs/database-dictionary.md`](../docs/database-dictionary.md)。

## 1. 环境要求

- MySQL **8.0+**（用到 CHECK 约束、STORED 生成列、视图）。
- 数据库名固定为 **`libra_core`**，必须与 `deploy/compose.yaml` 的 `MYSQL_DATABASE`、`server/config/config.example.json` 的 `dbname` 一致。v0.1 的 `schema.sql` 曾使用 `libracore`，会导致 Docker 初始化后数据落错库，v1.0 已修正。

## 2. 文件与执行顺序

| 顺序 | 文件 | 说明 |
| --- | --- | --- |
| 1 | `schema.sql` | 建库、建 5 张表、建 `v_book_inventory` 视图；全新库直接执行 |
| 2 | `seed.sql` | 虚构种子数据；可重复执行（先清空再插入） |
| 3 | `../tests/database/verify_schema.sql` | 结构与数据一致性校验 |

`migrations/001_align_openapi_v0_2.sql` 仅用于**从 v0.1 旧结构升级**；骨架期推荐直接重建，见第 4 节。

## 3. 初始化方式

### 方式 A：Docker Compose（推荐，与部署环境一致）

```bash
cd deploy
# 先在 deploy/.env 中设置 MYSQL_ROOT_PASSWORD / MYSQL_USER / MYSQL_PASSWORD（.env 已被 .gitignore 忽略）
docker compose up -d mysql
```

`compose.yaml` 把 `schema.sql`、`seed.sql` 挂到 `/docker-entrypoint-initdb.d/`，**只在数据卷为空的首次启动**执行。若之前已启动过旧版结构，需要先重建卷：

```bash
cd deploy
docker compose down -v      # 会清空该项目的数据库卷，确认无真实数据后再执行
docker compose up -d mysql
```

### 方式 B：本地 MySQL 客户端

```bash
# 在仓库根目录执行；密码由环境变量提供，不要写进命令行
read -rs DB_PASSWORD && export DB_PASSWORD
bash tests/database/verify_init.sh
```

或直接（**中文 Windows 必须带 `--default-character-set=utf8mb4`**，否则 mysql 客户端默认 gbk，seed.sql 的中文会报 `Data too long for column 'name'`）：

```bash
mysql --default-character-set=utf8mb4 -u <user> -p < database/schema.sql
mysql --default-character-set=utf8mb4 -u <user> -p < database/seed.sql
mysql --default-character-set=utf8mb4 -u <user> -p < tests/database/verify_schema.sql
```

### 方式 C：已有旧库升级

```bash
mysql --default-character-set=utf8mb4 -u <user> -p < database/migrations/001_align_openapi_v0_2.sql
mysql --default-character-set=utf8mb4 -u <user> -p < database/schema.sql
mysql --default-character-set=utf8mb4 -u <user> -p < database/seed.sql
```

## 4. 测试数据说明

- 全部为虚构数据，不含真实学生资料；`password_hash` 是占位字符串，不可用于真实登录。
- 15 本 `active` 书目 + 1 本 `archived` 书目（验证 `GET /books` 默认过滤）。
- 44 条实体副本：41 `available`、2 `borrowed`、1 `retired`。
- 3 条借阅记录：2 `active`、1 `returned`（验证同一副本可累积历史）。
- `total_copies` / `available_copies` **不在 books 表存储**，由 `v_book_inventory` 实时聚合；seed 脚本不写这两个字段。

## 5. 验证与持久化证据

`tests/database/verify_init.sh` 会依次执行 schema、seed、校验脚本，输出一张 `PASS/FAIL` 检查表。数据库重启后的复查步骤与测试记录模板见 [`tests/database/README.md`](../tests/database/README.md)。

## 6. 安全约定

- 数据库密码、访问令牌、`.env` 一律不入库（根 `.gitignore` 已忽略）。
- 本地配置从 `server/config/config.example.json` 复制为 `config.local.json` 后填写，该文件已被忽略。
- 校验脚本通过 `DB_PASSWORD` 环境变量读取密码，使用 `MYSQL_PWD` 传递，避免出现在 `ps` 命令行中。

## 7. 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 应用查不到表 / 表为空 | v0.1 建在 `libracore` 库，应用连 `libra_core` | 按方式 C 重建，或统一到 `libra_core` |
| Docker 重启后结构没变 | initdb 脚本只在空卷首次启动执行 | `docker compose down -v` 后重新 `up` |
| `Cannot truncate a table referenced in a foreign key constraint` | 用 TRUNCATE 清有外键的表 | seed.sql v1.0 已改用 `DELETE` + 关闭外键检查 |
| 归档书目失败 | 该书仍有 `borrowed` 副本 | 契约约定返回 409 `RESOURCE_IN_USE`，先处理归还 |
| `Data too long for column 'name'`（中文 Windows） | mysql 客户端默认字符集为 gbk，中文转换后超长 | 命令加 `--default-character-set=utf8mb4`；`verify_init.sh` 已内置 |
| `ERROR 1215 Cannot add foreign key constraint` | 被 STORED 生成列引用的列带了 `ON UPDATE CASCADE` 外键 | v1.0.1 已把 `borrow_records` 两个外键改为只写 `ON DELETE RESTRICT` |
