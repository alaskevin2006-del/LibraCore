-- 迁移 002：v1.0.1 -> v1.1（第 10 周借还业务支持）
-- 维护人：zyj｜日期：2026-11-06
-- 前置：数据库已按 v1.0.1 的 schema.sql 建好五张表与 v_book_inventory 视图。
--
-- 本版为纯增量（新增派生视图 + 借还事务存储过程），不改动任何表结构，
-- 不需要 ALTER、不需要迁移数据，也不会影响已有业务数据。
--
-- 完整升级步骤（两步，均幂等）：
--   mysql --default-character-set=utf8mb4 -u <user> -p < database/migrations/002_week10_loans.sql
--   mysql --default-character-set=utf8mb4 -u <user> -p < database/procedures.sql
-- 全新环境直接跑 tests/database/verify_init.sh（已包含这两步）。

USE `libra_core`;

-- 1. 借阅明细基础视图：一次 JOIN 补齐书目与读者展示字段，
--    避免契约待评审项 loan-denormalization 提到的 N+1 请求。
CREATE OR REPLACE VIEW `v_loan_history` AS
SELECT
    `br`.`id`          AS `loan_id`,
    `br`.`copy_id`     AS `copy_id`,
    `c`.`book_id`      AS `book_id`,
    `b`.`title`        AS `title`,
    `b`.`author`       AS `author`,
    `br`.`reader_id`   AS `reader_id`,
    `r`.`name`         AS `reader_name`,
    `br`.`status`      AS `status`,
    `br`.`borrowed_at` AS `borrowed_at`,
    `br`.`due_at`      AS `due_at`,
    `br`.`returned_at` AS `returned_at`,
    (`br`.`status` = 'active' AND `br`.`due_at` < NOW()) AS `is_overdue`
FROM `borrow_records` `br`
JOIN `book_copies` `c` ON `c`.`id` = `br`.`copy_id`
JOIN `books`       `b` ON `b`.`id` = `c`.`book_id`
JOIN `readers`     `r` ON `r`.`id` = `br`.`reader_id`;

-- 2. 当前未归还借阅 / 逾期借阅（逾期为推导值，不是独立状态）。
CREATE OR REPLACE VIEW `v_active_loans` AS
SELECT * FROM `v_loan_history` WHERE `status` = 'active';

CREATE OR REPLACE VIEW `v_overdue_loans` AS
SELECT * FROM `v_loan_history` WHERE `status` = 'active' AND `due_at` < NOW();

-- 3. 事务性借还存储过程在 database/procedures.sql（含 DROP IF EXISTS，幂等）。
-- 4. v1.0.1 已具备的借还约束（uk_loan_active_copy、chk_loan_returned_at、
--    idx_loan_due、fk_loan_copy/reader）无需变更，此处只做复核提示：
--    SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE FROM information_schema.TABLE_CONSTRAINTS
--     WHERE TABLE_SCHEMA='libra_core' AND TABLE_NAME='borrow_records';
