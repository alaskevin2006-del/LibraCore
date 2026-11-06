# 数据库测试与验收证据（zyj）

> 对应交付项：第 8 周 **Z5 数据验证**；`docs/评分标准+验收清单.md` 的 3.2 数据存储与查询、3.3 数据一致性与完整性、3.4 数据库初始化与配置、5.1 主要业务流程测试、5.3 测试记录与问题修复。
> 本目录只负责数据库层；会议纪要与开发报告由本人另行维护。

## 1. 文件

| 文件 | 用途 |
| --- | --- |
| `verify_init.sh` | 一键执行 schema → seed → 校验，输出 PASS/FAIL 检查表 |
| `verify_schema.sql` | 20 项结构与数据一致性断言，含 3 个手工异常用例（注释形式） |
| `results/` | 存放实际运行输出，作为 Z5 与评分证据 |

## 2. 执行方式

```bash
# 在仓库根目录，Git Bash / Linux / macOS 均可
read -rs DB_PASSWORD && export DB_PASSWORD    # 避免密码进入 shell 历史
DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=root bash tests/database/verify_init.sh
```

Docker 环境（对应 `deploy/compose.yaml`）：

```bash
cd deploy && docker compose up -d mysql
# 首次启动会自动执行 schema.sql + seed.sql；再单独跑校验：
docker compose exec -T mysql sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" libra_core' \
  < ../tests/database/verify_schema.sql
```

期望结果：`verify_schema.sql` 输出的所有 `result` 均为 `PASS`。

## 3. 测试记录

> **执行状态**：2026-11-06 已在真实 **MySQL 8.0.46**（本机免安装临时实例，`127.0.0.1:3307`）上全部执行完毕，输出见 `results/verify-2026-11-06.txt`。T1—T10 全部通过；T6 预期报错 1062、T7 预期影响 0 行，均按预期生效。执行过程中发现并修复了 1 个建表错误与 1 个文档坑（见第 4 节）。

| 编号 | 用例 | 预期结果 | 实际结果 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 全新空库执行 `schema.sql` | 建成 5 表 + 1 视图，无报错 | 5 张表 + `v_book_inventory` 视图，无报错 | 通过 |
| T2 | 执行 `seed.sql` | 16 书目 / 44 副本 / 3 借阅 / 3 读者 / 1 管理员 | 全部一致 | 通过 |
| T3 | `verify_schema.sql` 全部断言 | 所有 `result = PASS` | 20/20 PASS | 通过 |
| T4 | `v_book_inventory` 汇总核对 | book1 total=3/available=2，book4 available=1，book16 total=0 | 3/2、1、0，全部一致 | 通过 |
| T5 | 分页检索（page=1/2, page_size=10） | 15 条 active 书目分两页，归档书目不出现 | 第 1 页 10 行、第 2 页 5 行，archived id=16 未泄漏 | 通过 |
| T6 | 同一副本重复借出 | 因 `uk_loan_active_copy` 报 1062，不产生第二条 active | `ERROR 1062 ... uk_loan_active_copy`，active 仍为 2 条 | 通过 |
| T7 | 归档仍有 borrowed 副本的书目 | 影响行数为 0，书目仍为 active（对应 409） | `ROW_COUNT()=0`，id=1 仍为 active | 通过 |
| T8 | 读者软注销 | status 变 suspended，借阅历史未被删除 | status=suspended，借阅记录 2→2 条未变 | 通过 |
| T9 | **数据库重启后复查** | 数据完整、视图可查、约束仍在 | 优雅 shutdown 后重启同一数据目录：16/44/3 不变，20/20 PASS | 通过 |
| T10 | 再次执行 `seed.sql` | 可重复执行，数据条数不变、无外键报错 | 多次重跑均成功、条数不变（需 utf8mb4 客户端） | 通过 |

### T9 重启持久化步骤

```bash
# 1. 记录重启前快照
mysql --default-character-set=utf8mb4 -u <user> -p -e "SELECT COUNT(*) FROM books; SELECT COUNT(*) FROM book_copies;" libra_core

# 2. 重启数据库
docker compose restart mysql                    # Docker 方式
# 或 mysqladmin -u <user> -p shutdown 后重新执行 mysqld（免安装版）

# 3. 重启后复查（应输出同样条数，且全部 PASS）
mysql --default-character-set=utf8mb4 -u <user> -p libra_core < tests/database/verify_schema.sql
```

注意：Docker 的 `docker-entrypoint-initdb.d` 脚本只在**空卷首次启动**执行；重启不应重新初始化，这正是 T9 要验证的持久化行为。本次实测使用免安装版：优雅 shutdown 后重启同一数据目录，数据条数与 20 项断言全部保持不变。

## 4. 失败与修复记录

| 日期 | 现象 | 预期 | 实际 | 原因 | 修复 |
| --- | --- | --- | --- | --- | --- |
| 2026-11-06 | v0.1 `schema.sql` 使用库名 `libracore`，而 compose / config 用 `libra_core` | 应用连到有数据的库 | 数据落到另一个库 | 库名不一致 | v1.0 统一为 `libra_core`，并新增 `migrations/001` 升级路径 |
| 2026-11-06 | v0.1 `deleteBook` 物理 DELETE，且 `borrow_records` 对 books 有 RESTRICT 外键 | 可删除书目 | 有借阅记录时必然失败 | 删除语义与契约不符 | 改为软归档 + 副本退藏，有 borrowed 副本时拒绝 |
| 2026-11-06 | v0.1 `fk_borrow_reader` 为 `ON DELETE CASCADE` | 注销读者保留借阅历史 | 历史被连带删除 | 外键策略错误 | 改为 RESTRICT + 软注销 |
| 2026-11-06 | `books.total_copies/available_copies` 可由 `updateBook` 直接改写 | 契约标为 readOnly | 计数与副本状态可能不一致 | 冗余可写字段 | 移除物理列，改由 `v_book_inventory` 聚合 |
| 2026-11-06 | `ReaderRepository` 列表查询返回 `password_hash` | 列表不含密码哈希 | 哈希随列表带出 | SELECT 未过滤敏感列 | 列表/详情不查该列，另设认证专用查询 |
| 2026-11-06 | **真实执行 `schema.sql`**：`ERROR 1215 Cannot add foreign key constraint`（`borrow_records`） | 5 张表全部建成 | 仅建成 4 张 | `copy_id` 被 STORED 生成列 `active_copy_id` 表达式引用，MySQL 8 禁止该列上的外键带 `ON UPDATE CASCADE` | 二分测试定位后，两个外键统一改为只写 `ON DELETE RESTRICT`（ID 为自增主键，业务不 UPDATE）；重跑 20/20 PASS |
| 2026-11-06 | 手动重跑 `seed.sql`：`ERROR 1406 Data too long for column 'name'` | 正常插入中文数据 | 插入失败 | 中文 Windows 下 mysql 客户端默认字符集为 **gbk** | 手动命令一律加 `--default-character-set=utf8mb4`（`verify_init.sh` 已内置）；已补进 `database/README.md` |

> 前 5 行为静态代码审查发现并修复的问题，后 2 行为**真实数据库执行时**发现并修复的问题。T1—T10 的运行时结果见第 3 节与 `results/verify-2026-11-06.txt`。

## 5. 证据归档

- `results/verify-2026-11-06.txt`：本次 `verify_init.sh` 完整输出、重启前快照、T9 重启后复查的 20 项断言。
- 输出中不含任何真实密码、令牌或个人信息；提交前再确认一次。

## 6. 第 10 周借还验证（M3）

`verify_loans.py` 在真实 MySQL 上覆盖第 10 周评分点，执行方式：

```bash
DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=<user> DB_PASSWORD=<pwd> \
    python tests/database/verify_loans.py
```

| 用例 | 内容 |
| --- | --- |
| T10-1 | 正常借 → 副本变 borrowed → 记录 active → 可借数减 1 → 当前借阅视图可见 |
| T10-2 | 已借出的副本再次借：`COPY_UNAVAILABLE`，且不产生第二条 active |
| T10-3 | 正常还 → 副本回 available → `returned_at` 非空 → 可借数恢复 |
| T10-4 | 重复还：`ALREADY_RETURNED` |
| T10-5~7 | 无效读者 / 停用读者 / 无效副本 / 无效借阅记录 |
| T10-8 | **两个连接并发争抢同一副本**：仅一次成功，副本状态与 active 记录一致，无半更新 |
| T10-9 | 验证后恢复初始数据（16/44/3），不污染后续校验 |

结果自动写入 `results/verify-loans-<日期>.txt`。事务与规则说明见 `docs/loan-rules.md`。
