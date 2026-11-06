-- LibraCore 借还事务存储过程 v1.0（第 10 周 / M3）
-- 执行：mysql --default-character-set=utf8mb4 -u <user> -p < database/procedures.sql
-- 可重复执行：每个过程先 DROP IF EXISTS 再 CREATE。
--
-- 设计说明见 docs/loan-rules.md。事务放在数据库层，保证「借阅记录」与
-- 「副本状态」要么一起成功、要么一起回滚；同时便于独立验证并发一致性。
-- 业务错误统一用 SQLSTATE 45000 + 固定 MESSAGE_TEXT，供 Controller 映射 HTTP 状态。

USE `libra_core`;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_borrow_book` $$
CREATE PROCEDURE `sp_borrow_book`(
    IN p_copy_id BIGINT,
    IN p_reader_id BIGINT,
    IN p_loan_days INT
)
BEGIN
    DECLARE v_reader_status VARCHAR(16) DEFAULT NULL;
    DECLARE v_copy_status   VARCHAR(16) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 借期规则（loan-policy）待团队确认，这里只提供默认值，不把天数写死在表里。
    IF p_loan_days IS NULL OR p_loan_days < 1 THEN
        SET p_loan_days = 30;
    END IF;

    START TRANSACTION;

    SELECT `status` INTO v_reader_status
      FROM `readers` WHERE `id` = p_reader_id FOR UPDATE;
    IF v_reader_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'READER_NOT_FOUND';
    END IF;
    IF v_reader_status <> 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'READER_SUSPENDED';
    END IF;

    -- 行锁串行化并发借阅：第二个事务拿到锁时会看到 borrowed。
    SELECT `status` INTO v_copy_status
      FROM `book_copies` WHERE `id` = p_copy_id FOR UPDATE;
    IF v_copy_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COPY_NOT_FOUND';
    END IF;
    IF v_copy_status <> 'available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COPY_UNAVAILABLE';
    END IF;

    UPDATE `book_copies` SET `status` = 'borrowed' WHERE `id` = p_copy_id;
    INSERT INTO `borrow_records`
        (`copy_id`, `reader_id`, `status`, `borrowed_at`, `due_at`, `returned_at`)
    VALUES
        (p_copy_id, p_reader_id, 'active', NOW(),
         DATE_ADD(NOW(), INTERVAL p_loan_days DAY), NULL);

    COMMIT;
    -- 返回新借阅记录 ID，让 Repository 一次 CALL 即可取回，避免依赖会话变量。
    SELECT LAST_INSERT_ID() AS `loan_id`;
END $$

DROP PROCEDURE IF EXISTS `sp_return_book` $$
CREATE PROCEDURE `sp_return_book`(IN p_loan_id BIGINT)
BEGIN
    DECLARE v_copy_id BIGINT DEFAULT NULL;
    DECLARE v_status  VARCHAR(16) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT `copy_id`, `status` INTO v_copy_id, v_status
      FROM `borrow_records` WHERE `id` = p_loan_id FOR UPDATE;
    IF v_copy_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LOAN_NOT_FOUND';
    END IF;
    IF v_status <> 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ALREADY_RETURNED';
    END IF;

    -- active_copy_id 生成列随 status 变为 NULL，释放 uk_loan_active_copy 唯一约束。
    UPDATE `borrow_records`
       SET `status` = 'returned', `returned_at` = NOW()
     WHERE `id` = p_loan_id;
    UPDATE `book_copies` SET `status` = 'available'
     WHERE `id` = v_copy_id AND `status` = 'borrowed';

    COMMIT;
    SELECT 1 AS `ok`;
END $$

DELIMITER ;
