-- 建表脚本（ZYJ 负责）
-- 目标：图书 / 读者 / 借阅记录三张核心表 + 管理员表
-- 约束：字段名与 api/openapi.yaml 中的接口字段保持一致
-- 注意：本文件会被 Docker 初始化执行，必须可重复执行前的 DROP 或 IF NOT EXISTS 处理由你定

-- TODO(ZYJ): 在下方补充建表语句
-- CREATE TABLE IF NOT EXISTS books (...);
-- CREATE TABLE IF NOT EXISTS readers (...);
-- CREATE TABLE IF NOT EXISTS borrow_records (...);
-- CREATE TABLE IF NOT EXISTS admins (...);
