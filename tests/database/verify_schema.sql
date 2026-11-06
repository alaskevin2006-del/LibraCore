-- LibraCore 数据库结构与数据一致性校验（zyj）
-- 前置：已按顺序执行 database/schema.sql 与 database/seed.sql
-- 执行：mysql -u <user> -p < tests/database/verify_schema.sql
-- 输出：每张检查一行，result = PASS / FAIL；任何 FAIL 都需定位后重跑。

USE `libra_core`;

SELECT 'tables_present' AS check_item, 5 AS expected,
       COUNT(*) AS actual, IF(COUNT(*) = 5, 'PASS', 'FAIL') AS result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'libra_core'
  AND TABLE_NAME IN ('admins', 'readers', 'books', 'book_copies', 'borrow_records')
UNION ALL
SELECT 'inventory_view_present', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'libra_core' AND TABLE_NAME = 'v_book_inventory'
UNION ALL
SELECT 'generated_active_copy_column', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'libra_core' AND TABLE_NAME = 'borrow_records'
  AND COLUMN_NAME = 'active_copy_id' AND EXTRA LIKE '%GENERATED%'
UNION ALL
SELECT 'returned_at_check_constraint', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'libra_core' AND TABLE_NAME = 'borrow_records'
  AND CONSTRAINT_TYPE = 'CHECK'
UNION ALL
SELECT 'no_cascade_fk_on_loans', 0, COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'libra_core' AND TABLE_NAME = 'borrow_records'
  AND DELETE_RULE = 'CASCADE'
UNION ALL
SELECT 'active_books', 15, COUNT(*), IF(COUNT(*) = 15, 'PASS', 'FAIL')
FROM books WHERE status = 'active'
UNION ALL
SELECT 'archived_books', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM books WHERE status = 'archived'
UNION ALL
SELECT 'copies_total', 44, COUNT(*), IF(COUNT(*) = 44, 'PASS', 'FAIL')
FROM book_copies
UNION ALL
SELECT 'copies_available', 41, COUNT(*), IF(COUNT(*) = 41, 'PASS', 'FAIL')
FROM book_copies WHERE status = 'available'
UNION ALL
SELECT 'copies_borrowed', 2, COUNT(*), IF(COUNT(*) = 2, 'PASS', 'FAIL')
FROM book_copies WHERE status = 'borrowed'
UNION ALL
SELECT 'copies_retired', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM book_copies WHERE status = 'retired'
UNION ALL
SELECT 'loans_active', 2, COUNT(*), IF(COUNT(*) = 2, 'PASS', 'FAIL')
FROM borrow_records WHERE status = 'active'
UNION ALL
SELECT 'loans_returned', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM borrow_records WHERE status = 'returned'
UNION ALL
SELECT 'book1_total_copies', 3,
       (SELECT total_copies FROM v_book_inventory WHERE book_id = 1),
       IF((SELECT total_copies FROM v_book_inventory WHERE book_id = 1) = 3, 'PASS', 'FAIL')
UNION ALL
SELECT 'book1_available_copies', 2,
       (SELECT available_copies FROM v_book_inventory WHERE book_id = 1),
       IF((SELECT available_copies FROM v_book_inventory WHERE book_id = 1) = 2, 'PASS', 'FAIL')
UNION ALL
SELECT 'book4_available_copies', 1,
       (SELECT available_copies FROM v_book_inventory WHERE book_id = 4),
       IF((SELECT available_copies FROM v_book_inventory WHERE book_id = 4) = 1, 'PASS', 'FAIL')
UNION ALL
SELECT 'retired_excluded_from_total', 0,
       (SELECT total_copies FROM v_book_inventory WHERE book_id = 16),
       IF((SELECT total_copies FROM v_book_inventory WHERE book_id = 16) = 0, 'PASS', 'FAIL')
UNION ALL
SELECT 'active_loan_copy_state_consistent', 0, COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM borrow_records br JOIN book_copies c ON c.id = br.copy_id
WHERE br.status = 'active' AND c.status <> 'borrowed'
UNION ALL
SELECT 'returned_loans_have_returned_at', 0, COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM borrow_records WHERE status = 'returned' AND returned_at IS NULL
UNION ALL
SELECT 'no_duplicate_active_copy', 0, COUNT(*), IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM (
    SELECT active_copy_id FROM borrow_records WHERE status = 'active'
    GROUP BY active_copy_id HAVING COUNT(*) > 1
) AS dup;

-- ---------------------------------------------------------------------------
-- 手工验证用例（不放在自动校验里，因为它们预期「应当失败」）
-- ---------------------------------------------------------------------------
-- 1) 同一副本重复借出应被 uk_loan_active_copy 拒绝（预期 ERROR 1062 Duplicate entry）：
--    INSERT INTO borrow_records (copy_id, reader_id, status, borrowed_at, due_at)
--    SELECT c.id, 1, 'active', NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY)
--    FROM book_copies c WHERE c.barcode = 'LC-001-03';
--
-- 2) 仍有 borrowed 副本的书目不可归档（预期 affectedRows = 0，由 Repository 转 409）：
--    UPDATE books SET status = 'archived' WHERE id = 1 AND status = 'active'
--      AND NOT EXISTS (SELECT 1 FROM book_copies c WHERE c.book_id = 1 AND c.status = 'borrowed');
--    SELECT status FROM books WHERE id = 1;  -- 应仍为 active
--
-- 3) 读者软注销后借阅历史仍在：
--    UPDATE readers SET status = 'suspended' WHERE id = 3;
--    SELECT COUNT(*) FROM borrow_records WHERE reader_id = 3;  -- 不应因注销被删除
--    验证完执行 seed.sql 恢复初始数据。
