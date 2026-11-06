-- 迁移 001：v0.1（4 表 + 书目内冗余计数）→ v1.0（对齐 OpenAPI 0.2.0-draft）
-- 维护人：zyj｜日期：2026-11-06
--
-- 为什么采用「重建式迁移」：
--   v1.0 引入了 book_copies 实体、库存视图、以 copy_id 为主体的借阅记录、
--   生成列唯一约束与软删除语义，与 v0.1 差异过大；且当前处于骨架阶段，
--   测试库只有虚构种子数据、没有真实业务数据。逐列 ALTER 风险高且无实际收益，
--   因此直接删除受影响的表，再按 schema.sql + seed.sql 重建。
--
-- 前置条件：MySQL 8.0+；具备 DROP/CREATE 权限；已备份测试库（若有自定义数据）。
-- 执行顺序（三步，缺一不可）：
--   mysql -u <user> -p < database/migrations/001_align_openapi_v0_2.sql
--   mysql -u <user> -p < database/schema.sql
--   mysql -u <user> -p < database/seed.sql
-- 最后用 tests/database/verify_schema.sql 校验。
--
-- 注意：v0.1 的 schema.sql 使用的库名是 `libracore`，而 compose.yaml 与
-- config.example.json 使用 `libra_core`。若旧测试库确实建在 `libracore`，
-- 请先确认要迁移到哪个库；骨架期建议直接在 `libra_core` 重建（本脚本会自动建库）。

CREATE DATABASE IF NOT EXISTS `libra_core`
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `libra_core`;

-- 按「视图 → 子表 → 父表」顺序删除，避免外键约束报错。
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW  IF EXISTS `v_book_inventory`;
DROP TABLE IF EXISTS `borrow_records`;
DROP TABLE IF EXISTS `book_copies`;
DROP TABLE IF EXISTS `books`;

SET FOREIGN_KEY_CHECKS = 1;

-- readers / admins 结构在 v1.0 未变更，且认证模型仍待团队评审，故保留。
-- 若旧库的 readers 仍是 v0.1 的 `fk_borrow_reader ... ON DELETE CASCADE`，
-- 该外键已随 borrow_records 一并删除；schema.sql 重建时会按 RESTRICT 建立。
--
-- 下一步：执行 database/schema.sql（CREATE TABLE IF NOT EXISTS 会重建上面删掉的
-- 三张表与视图，跳过已存在的 readers/admins），再执行 database/seed.sql 重建数据。
