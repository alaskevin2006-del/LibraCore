# LibraCore 数据字典 v1.0

> 维护人：zyj｜版本：v1.0｜更新日期：2026-11-06
> 依据：`api/openapi.yaml`（0.2.0-draft）的 Book / Copy / Reader / Loan；`docs/第8周任务清单.md` Z1—Z5
> 数据库：`libra_core`（与 `deploy/compose.yaml` 的 `MYSQL_DATABASE`、`server/config/config.example.json` 的 `dbname` 一致）
> 环境要求：MySQL 8.0+（用到 CHECK 约束、STORED 生成列、视图）

## 1. 实体与关系

| 实体 | 作用 | 关系 |
| --- | --- | --- |
| `admins` | 管理员账号 | 独立表，认证模型待团队评审 |
| `readers` | 读者信息 | 1:N → `borrow_records` |
| `books` | 图书**书目**（元数据） | 1:N → `book_copies` |
| `book_copies` | 馆藏**实体副本** | 1:N → `borrow_records` |
| `borrow_records` | 借阅流水 | 关联具体副本与读者 |
| `v_book_inventory` | 视图 | 按书目聚合副本数，提供只读计数 |

**核心不变量：书目 ≠ 实体副本。** 同一书目可有多本实体副本，借还对象永远是 `copy_id` 而不是 `book_id`。ER 图见 [`docs/er-diagram.md`](er-diagram.md)。

## 2. 表结构

### 2.1 admins（管理员，结构未改）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK, AUTO_INCREMENT | 管理员 ID |
| username | VARCHAR(50) | NOT NULL, UNIQUE | 登录账号 |
| password_hash | VARCHAR(255) | NOT NULL | 密码哈希，禁止明文 |
| name | VARCHAR(50) | NOT NULL | 姓名 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | UTC |

### 2.2 readers（读者，结构未改）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK, AUTO_INCREMENT | 读者 ID |
| reader_card_id | VARCHAR(50) | NOT NULL, UNIQUE, INDEX | 卡号/学号 → API `username` |
| name | VARCHAR(50) | NOT NULL, INDEX | 姓名 → API `display_name` |
| password_hash | VARCHAR(255) | NOT NULL | 仅认证查询读取，禁止随列表返回 |
| email | VARCHAR(100) | NULL | → API `email` |
| phone | VARCHAR(20) | NULL | 数据库内部字段，不暴露给 API |
| status | ENUM('active','suspended') | NOT NULL, DEFAULT 'active', INDEX | → API `is_active`（true/false） |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | UTC |

> 认证模型（reader 与登录账号是否同表、admin 是否也有 reader 记录）属于契约待评审项 `reader-account-model`，涉及后端认证模块，**本次不擅自改动 readers/admins 表结构**，仅登记字段映射。

### 2.3 books（书目，v1.0 修订）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK, AUTO_INCREMENT | 书目 ID |
| isbn | VARCHAR(20) | NULL, UNIQUE | 契约允许 null；MySQL UNIQUE 允许多个 NULL |
| title | VARCHAR(255) | NOT NULL, INDEX | 书名 |
| author | VARCHAR(255) | NOT NULL, INDEX | 作者 |
| publisher | VARCHAR(255) | NULL | 出版社 |
| category | VARCHAR(100) | NULL, INDEX | 分类 |
| published_on | DATE | NULL | 契约 `format: date`；**替代原 publish_year INT** |
| description | TEXT | NULL | 新增，对应契约 description |
| status | ENUM('active','archived') | NOT NULL, DEFAULT 'active', INDEX | **新增**，软归档；GET /books 默认只返 active |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | UTC |

**已移除**：`publish_year`、`total_copies`、`available_copies`。后两者改由视图实时聚合，避免冗余计数与副本状态不一致。

### 2.4 book_copies（实体副本，v1.0 新增）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK, AUTO_INCREMENT | 副本 ID → API `Copy.id` / `Loan.copy_id` |
| book_id | BIGINT | NOT NULL, FK → books(id) ON DELETE RESTRICT | 所属书目 |
| barcode | VARCHAR(64) | NOT NULL, UNIQUE | 馆藏条码 → API `Copy.barcode` |
| status | ENUM('available','borrowed','retired') | NOT NULL, DEFAULT 'available' | 契约 Copy.status；不可直接 PATCH 为 available/borrowed |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | UTC |

索引：`idx_copies_book_status (book_id, status)`，支撑可借副本查询与库存聚合。

### 2.5 borrow_records（借阅记录，v1.0 修订）

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| id | BIGINT | PK, AUTO_INCREMENT | → API `Loan.id` |
| copy_id | BIGINT | NOT NULL, FK → book_copies(id) ON DELETE RESTRICT | **替代原 book_id** |
| reader_id | BIGINT | NOT NULL, FK → readers(id) ON DELETE RESTRICT | 由 CASCADE 改为 RESTRICT，避免注销读者时丢失借阅历史 |
| status | ENUM('active','returned') | NOT NULL, DEFAULT 'active' | **移除 overdue**：逾期由 `due_at < NOW()` 推导 |
| borrowed_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | UTC，替代 borrow_time |
| due_at | DATETIME | NOT NULL | UTC，替代 due_time；借期长度待团队确认 |
| returned_at | DATETIME | NULL | 替代 return_time；未归还为 NULL |
| active_copy_id | BIGINT | STORED GENERATED = `CASE WHEN status='active' THEN copy_id ELSE NULL END`, UNIQUE | 保证同一副本同时最多一条 active 借阅 |

约束与索引：
- `uk_loan_active_copy (active_copy_id)`：第 10 周 M3「并发争用仅一次成功」的数据库层保障；returned 记录生成列为 NULL，可累积历史。
- `chk_loan_returned_at`：`status='returned'` 时 `returned_at` 必须非空。
- `idx_loan_reader_status (reader_id, status)`、`idx_loan_due (due_at)`：支撑我的借阅与逾期查询。

### 2.6 v_book_inventory（视图，v1.0 新增）

| 列 | 来源 | 说明 |
| --- | --- | --- |
| book_id | books.id | 书目 ID |
| total_copies | `COUNT(copies WHERE status<>'retired')` | retired 不计入总数 |
| available_copies | `COUNT(copies WHERE status='available')` | borrowed 计入总数但不计入可借数 |

对应契约 `Book.total_copies` / `available_copies`（`readOnly: true`）。接口层只读，禁止写入。

## 3. 数据库字段 ↔ API 字段映射

| 数据库列 | OpenAPI 字段 | 备注 |
| --- | --- | --- |
| books.published_on | `Book.published_on` | DATE → RFC3339 `date` |
| books.status | `Book.status` | active / archived |
| books.isbn / title / author / publisher / category / description | 同名 | 可空列以 `NULL` 对应 `nullable: true` |
| v_book_inventory.total_copies / available_copies | `Book.total_copies` / `available_copies` | readOnly |
| book_copies.id / book_id / barcode / status / created_at | `Copy.*` | |
| borrow_records.copy_id / reader_id / status / borrowed_at / due_at / returned_at | `Loan.*` | Loan 不冗余 book_id（待评审项 loan-denormalization） |
| readers.reader_card_id / name / email / status | `Reader.username` / `display_name` / `email` / `is_active` | 需接口层做一次映射 |
| admins.username / name | `Account.username` / `display_name`（role=admin） | 认证模型待评审 |

完整说明见 [`docs/repository-contract.md`](repository-contract.md)。

## 4. 待团队评审的数据模型事项

以下来自 `api/openapi.yaml` 的 `x-pending-decisions`，**本版按契约既有字段实现，未替团队做决定**：

| key | 本版处理 |
| --- | --- |
| `soft-delete-semantics` | 采用契约已定义的 `status` 字段（books.status / readers.status），未引入 deleted_at |
| `reader-account-model` | 保留 admins / readers 分表，仅登记字段映射；需与认证负责人 lkx 确认 |
| `uniqueness-rules` | ISBN 保留 UNIQUE 但允许 NULL；barcode 全局 UNIQUE |
| `loan-policy` | due_at 由种子数据给出示例值，借期规则未写入数据库 |
| `loan-denormalization` | Loan 不冗余 book_id，按 copy_id JOIN 取书目 |
| `books-archived-visibility` | GET /books 默认只返 active；Repository 提供 `includeArchived` 参数备用 |
| `copies-visibility` | `queryCopiesByBookId` 默认返回全部状态（含 retired） |

## 5. 变更记录

| 版本 | 日期 | 变更 |
| --- | --- | --- |
| v0.1 | 2026-10-28 | 4 张核心表 + 数据字典初稿（PR #3） |
| v1.0 | 2026-11-06 | 库名 `libracore` → `libra_core`；新增 `book_copies` 与 `v_book_inventory`；books 对齐契约字段并支持软归档；borrow_records 改造为以副本为借还对象并加唯一 active 约束；补齐 ER 图、迁移、初始化与验证脚本 |
