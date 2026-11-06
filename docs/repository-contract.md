# Repository 接口与字段约定（zyj → 后端集成）

> 维护人：zyj｜版本：v1.0｜更新日期：2026-11-06
> 适用：`api/openapi.yaml` 0.2.0-draft｜数据模型见 [`docs/database-dictionary.md`](database-dictionary.md)
> 用途：给 lkx 写 Controller / Service 时对接用，明确「Repository 提供什么、不提供什么」。

## 1. 文件清单

| 文件 | 职责 |
| --- | --- |
| `server/src/repositories/BookRepository.h/.cpp` | 书目 CRUD、分页检索、副本查询、软归档 |
| `server/src/repositories/ReaderRepository.h/.cpp` | 读者 CRUD、分页检索、认证专用查询、软注销 |
| `database/schema.sql` | 建表 + 视图 |
| `database/seed.sql` | 可重复执行的虚构种子数据 |
| `tests/database/verify_schema.sql` | 结构与数据一致性校验 |

> **文件名说明**：仓库的 `server/CMakeLists.txt` 使用 `file(GLOB_RECURSE ... src/*.cpp)` 收集源码，只匹配 `.cpp`。原 `BookRepository.cc` / `ReaderRepository.cc` 不会被编译，且 `src` 下无 `.cpp` 时 CMake 会直接 `FATAL_ERROR`。因此本次把两个实现文件重命名为 `.cpp`，**未修改 CMakeLists.txt**（该文件由 lkx 维护）。头文件路径不变，既有 `#include` 不受影响。

## 2. 函数签名

### BookRepository

| 方法 | 输入 | 回调 | 行为 |
| --- | --- | --- | --- |
| `queryBooks(keyword, page, pageSize, successCb, errorCb, includeArchived=false)` | keyword / page≥1 / pageSize 1–100 | `vector<Book>, total` | 模糊匹配 title、author、isbn；默认只返 `status='active'`；`ORDER BY b.id DESC` |
| `getBookById(id, successCb, errorCb)` | 书目 ID | `Book, found` | 归档书目仍可按 ID 取到 |
| `queryCopiesByBookId(bookId, successCb, errorCb)` | 书目 ID | `vector<BookCopy>` | 对应 `GET /books/{book_id}/copies`，默认含 retired |
| `addBook(book, successCb, errorCb)` | 书目元数据 | `newId` | 只写元数据，`status` 固定 active |
| `updateBook(book, successCb, errorCb)` | 书目元数据 | `success, affectedRows` | 不更新 status 与两个只读计数字段 |
| `deleteBook(id, successCb, errorCb)` | 书目 ID | `success, affectedRows` | **软归档**；有 borrowed 副本时走 errorCb（对应 409 `RESOURCE_IN_USE`） |

### ReaderRepository

| 方法 | 输入 | 回调 | 行为 |
| --- | --- | --- | --- |
| `queryReaders(keyword, page, pageSize, successCb, errorCb)` | 卡号/姓名 | `vector<Reader>, total` | 返回全部状态；**不返回 password_hash** |
| `getReaderById(id, successCb, errorCb)` | 读者 ID | `Reader, found` | 不返回 password_hash |
| `getReaderByCardIdForAuth(cardId, successCb, errorCb)` | 卡号 | `Reader, found` | **认证专用**，含 password_hash，禁止序列化进 API 响应 |
| `addReader(reader, successCb, errorCb)` | 读者资料 | `newId` | 可空字段用 `NULLIF` 落 NULL |
| `updateReader(reader, successCb, errorCb)` | 读者资料 | `success, affectedRows` | 不改 password_hash |
| `deleteReader(id, successCb, errorCb)` | 读者 ID | `success, affectedRows` | **软注销**（status='suspended'），保留借阅历史 |

## 3. 分页约定

- `page` 从 **1** 开始，非法值按 1 处理；`pageSize` 合法范围 **1–100**，越界按 10 处理；`offset = (page-1) * pageSize`。
- 与 `client/network/BookService.cpp` 的 `page` / `page_size` 参数一致（上限 100）。
- 先 `COUNT(*)` 再取数据，两次异步查询期间若有写入，`total` 可能略有偏差；强一致场景由 Service 层事务包裹。
- 契约要求列表响应带 `meta: {page, page_size, total, total_pages}`，组装在 Controller 层，Repository 只回 `total`。

## 4. 字段映射（DB → API）

| DB | API | 说明 |
| --- | --- | --- |
| `books.isbn/title/author/publisher/category/published_on/description/status/created_at` | `Book.*` 同名 | 可空 DB 列空串 ↔ API `null`，由 Controller 转换 |
| `v_book_inventory.total_copies/available_copies` | `Book.total_copies/available_copies` | `readOnly`，已由 Repository 填好 |
| `book_copies.*` | `Copy.*` | `BookCopy` 结构 |
| `borrow_records.*` | `Loan.*` | 借还 Service 负责，本版未提供 LoanRepository |
| `readers.reader_card_id / name / email` | `Reader.username / display_name / email` | 需 Controller 映射 |
| `readers.status='active'` | `Reader.is_active=true` | suspended → false |
| `admins.username / name` | `Account.username / display_name`（role=admin） | 认证模型待评审 |

所有时间列按 **UTC** 存储，Controller 输出时转 RFC 3339（如 `2026-11-10T10:00:00Z`）。`published_on` 是 DATE，输出 `YYYY-MM-DD`，不要带时间。

## 5. 语义约定

- **软删除**：书目归档、读者注销、副本退藏都不做物理 DELETE。契约 `DELETE /books/{id}` 的描述是「软归档书目、将 available 副本统一退藏；若仍有 borrowed 副本则 409」，`deleteBook` 已按此实现。
- **只读计数**：`Book.totalCopies` / `availableCopies` 在 `addBook` / `updateBook` 中被忽略，只由视图聚合。新增副本应写入 `book_copies`。
- **逾期**：不是独立状态，`status='active' AND due_at < NOW()` 即逾期，由 Controller / Qt 端展示。
- **并发**：`uk_loan_active_copy` 保证同一副本不会同时出现两条 active 借阅；Service 层仍需在事务内更新副本状态与借阅记录。
- **密码**：`password_hash` 只在 `getReaderByCardIdForAuth` 中返回，任何列表/详情路径都不会带出。

## 5.1 第 10 周：LoanRepository（借还数据层）

| 文件 | 职责 |
| --- | --- |
| `server/src/repositories/LoanRepository.h/.cpp` | 借书、还书、当前借阅、借阅历史、逾期查询 |
| `database/procedures.sql` | `sp_borrow_book` / `sp_return_book`，事务与行锁的真实实现 |
| `docs/loan-rules.md` | 借还规则、状态流转图、一致性不变量、错误码 |

| 方法 | 说明 |
| --- | --- |
| `borrowBook(copyId, readerId, loanDays, cb, errCb)` | 一次 `CALL sp_borrow_book(?,?,?)`，回调返回新 `loan_id` |
| `returnBook(loanId, cb, errCb)` | 一次 `CALL sp_return_book(?)` |
| `queryActiveLoansByReader / queryLoanHistoryByReader / queryOverdueLoans` | 分别查 `v_active_loans` / `v_loan_history` / `v_overdue_loans` |

**错误码映射（Controller 负责）**：`COPY_UNAVAILABLE`、`ALREADY_RETURNED` → 409；`COPY_NOT_FOUND`、`READER_NOT_FOUND`、`LOAN_NOT_FOUND` → 404；`READER_SUSPENDED` → 403。借期 `loanDays` 由 Service 按团队确认的 `loan-policy` 传入，不写死在数据库。

> 事务放在存储过程而非 C++ 层：数据库逻辑已可在真实 MySQL 上独立验证（含并发），C++ 层只需一次 CALL，不依赖 Drogon `Transaction` API 的具体形式。`LoanRepository` 仍需在带 Drogon 的环境编译验证。

## 6. 尚需后端（lkx）配合的事项（本次未改动他人文件）

1. `server/src/controllers/` 目前仍只有 `.gitkeep`，Controller 与借还 Service 尚未实现；图书/读者 API 的归属需按技术设计文档再确认一次。
2. `server/src/main.cpp` 尚不存在，CMake 链接需要有入口文件（可由 `drogon_ctl` 生成）。
3. `deleteBook` 的「归档 + 副本退藏」是两步串行 SQL，**尚未包在事务里**；第 10 周 M3 借还联调时应由 Service 层用事务包裹，并补 `SELECT ... FOR UPDATE` 或条件更新。
4. 未提供 `LoanRepository` / `CopyRepository`（借还、副本增删改属于第 10 周范围），需要时再与 zyj 约定函数签名。
5. `api/openapi.yaml` 由 lkx 维护，本次**未修改**；若 `x-pending-decisions` 中 `soft-delete-semantics` / `reader-account-model` 评审结论与本版不同，请同步通知 zyj 调整 schema。

## 7. 已知限制

- `queryBooks` 的 `includeArchived`、副本列表是否含 retired，取决于两个待评审项，当前取契约默认行为。
- Repository 未做字段级校验（长度、ISBN 格式），契约的 422 校验应由 Controller 承担。
- SQL 层已在真实 **MySQL 8.0.46** 上执行并通过全部 20 项校验、3 个异常用例与重启持久化复查（证据见 `tests/database/results/verify-2026-11-06.txt`）。
- Repository 代码仍未在带 Drogon 的环境编译过（本机无 Drogon），合入前需在服务器环境跑一次 CMake 构建；`server/src/main.cpp` 也尚不存在，链接需要入口文件。
