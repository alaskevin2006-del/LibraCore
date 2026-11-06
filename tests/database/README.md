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

> **状态说明（重要）**：执行本次代码核查的开发机上**没有 MySQL 客户端，也没有 Docker**，因此以下用例的脚本已备好，但**尚未在真实数据库上运行过**。表中「实际结果」留空，需在有 MySQL 8 的环境执行一次后填写，不得预先填入 PASS。执行后把 `verify_init.sh` 的完整输出保存到 `results/verify-<日期>.txt`。

| 编号 | 用例 | 预期结果 | 实际结果 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 全新空库执行 `schema.sql` | 建成 5 表 + 1 视图，无报错 | | 待执行 |
| T2 | 执行 `seed.sql` | 16 书目 / 44 副本 / 3 借阅 / 3 读者 / 1 管理员 | | 待执行 |
| T3 | `verify_schema.sql` 全部断言 | 所有 `result = PASS` | | 待执行 |
| T4 | `v_book_inventory` 汇总核对 | book1 total=3/available=2，book4 available=1，book16 total=0 | | 待执行 |
| T5 | 分页检索（page=1/2, page_size=10） | 15 条 active 书目分两页，归档书目不出现 | | 待执行 |
| T6 | 同一副本重复借出 | 因 `uk_loan_active_copy` 报 1062，不产生第二条 active | | 待执行 |
| T7 | 归档仍有 borrowed 副本的书目 | 影响行数为 0，书目仍为 active（对应 409） | | 待执行 |
| T8 | 读者软注销 | status 变 suspended，借阅历史未被删除 | | 待执行 |
| T9 | **数据库重启后复查** | 数据完整、视图可查、约束仍在 | | 待执行 |
| T10 | 再次执行 `seed.sql` | 可重复执行，数据条数不变、无外键报错 | | 待执行 |

### T9 重启持久化步骤

```bash
# 1. 记录重启前快照
mysql -u <user> -p -e "SELECT COUNT(*) FROM books; SELECT COUNT(*) FROM book_copies;" libra_core

# 2. 重启数据库
docker compose restart mysql          # Docker 方式
# 或 systemctl restart mysqld         # 本机服务方式

# 3. 重启后复查（应输出同样条数，且全部 PASS）
bash tests/database/verify_init.sh    # 若只复查，直接跑 verify_schema.sql 即可
mysql -u <user> -p < tests/database/verify_schema.sql
```

注意：Docker 的 `docker-entrypoint-initdb.d` 脚本只在**空卷首次启动**执行；重启不应重新初始化，这正是 T9 要验证的持久化行为。

## 4. 失败与修复记录

| 日期 | 现象 | 预期 | 实际 | 原因 | 修复 |
| --- | --- | --- | --- | --- | --- |
| 2026-11-06 | v0.1 `schema.sql` 使用库名 `libracore`，而 compose / config 用 `libra_core` | 应用连到有数据的库 | 数据落到另一个库 | 库名不一致 | v1.0 统一为 `libra_core`，并新增 `migrations/001` 升级路径 |
| 2026-11-06 | v0.1 `deleteBook` 物理 DELETE，且 `borrow_records` 对 books 有 RESTRICT 外键 | 可删除书目 | 有借阅记录时必然失败 | 删除语义与契约不符 | 改为软归档 + 副本退藏，有 borrowed 副本时拒绝 |
| 2026-11-06 | v0.1 `fk_borrow_reader` 为 `ON DELETE CASCADE` | 注销读者保留借阅历史 | 历史被连带删除 | 外键策略错误 | 改为 RESTRICT + 软注销 |
| 2026-11-06 | `books.total_copies/available_copies` 可由 `updateBook` 直接改写 | 契约标为 readOnly | 计数与副本状态可能不一致 | 冗余可写字段 | 移除物理列，改由 `v_book_inventory` 聚合 |
| 2026-11-06 | `ReaderRepository` 列表查询返回 `password_hash` | 列表不含密码哈希 | 哈希随列表带出 | SELECT 未过滤敏感列 | 列表/详情不查该列，另设认证专用查询 |

> 上表记录的是**静态代码审查发现并已修复的问题**，不等同于运行时测试结果；T1—T10 仍需实际执行后补充运行结果。

## 5. 证据归档

- `results/verify-<日期>.txt`：`verify_init.sh` 的完整终端输出。
- 重启前后快照可另存 `results/persistence-<日期>.txt`。
- 输出中不含任何真实密码、令牌或个人信息；提交前再确认一次。
