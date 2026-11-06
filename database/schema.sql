-- LibraCore 数据库结构 v1.0
-- 与 api/openapi.yaml (0.2.0-draft) 的 Book / Copy / Loan 字段对齐。
--
-- 库名必须与 deploy/compose.yaml 的 MYSQL_DATABASE、
-- server/config/config.example.json 的 dbname 保持一致：libra_core。
-- 执行：mysql -u <user> -p < database/schema.sql
--
-- 设计要点：
--   1. 书目(books) 与 实体副本(book_copies) 分离，借还对象永远是具体副本；
--   2. total_copies / available_copies 为只读派生值，由视图 v_book_inventory 汇总，
--      不在 books 表冗余存储，避免计数与副本状态不一致；
--   3. 书目删除为软归档(status=archived)，读者注销为软停用(status=suspended)，
--      不物理删除业务数据，借阅历史必须保留；
--   4. 逾期不是独立状态，由 status='active' 且 due_at < NOW() 推导。
--   5. 所有时间列按 UTC 存储，由接口层格式化为 RFC 3339。

CREATE DATABASE IF NOT EXISTS `libra_core`
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `libra_core`;

-- ---------------------------------------------------------------------------
-- 1. 管理员账号表（认证模型待团队评审，本表结构保持不变）
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admins` (
    `id`            BIGINT AUTO_INCREMENT PRIMARY KEY,
    `username`      VARCHAR(50)  NOT NULL UNIQUE COMMENT '管理员登录账号',
    `password_hash` VARCHAR(255) NOT NULL COMMENT '哈希密码，禁止明文',
    `name`          VARCHAR(50)  NOT NULL COMMENT '管理员姓名',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'UTC'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员账号表';

-- ---------------------------------------------------------------------------
-- 2. 读者表（认证模型待团队评审，本表结构保持不变）
--    status='active' <-> OpenAPI Reader.is_active=true
--    reader_card_id  <-> OpenAPI Reader.username
--    name            <-> OpenAPI Reader.display_name
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `readers` (
    `id`             BIGINT AUTO_INCREMENT PRIMARY KEY,
    `reader_card_id` VARCHAR(50)  NOT NULL UNIQUE COMMENT '读者卡号/学号；对应 Reader.username',
    `name`           VARCHAR(50)  NOT NULL COMMENT '读者姓名；对应 Reader.display_name',
    `password_hash`  VARCHAR(255) NOT NULL COMMENT '哈希密码；仅在认证查询中读取，禁止随列表返回',
    `email`          VARCHAR(100) NULL COMMENT '联系邮箱；对应 Reader.email',
    `phone`          VARCHAR(20)  NULL COMMENT '联系电话（数据库内部字段，不暴露给 API）',
    `status`         ENUM('active','suspended') NOT NULL DEFAULT 'active' COMMENT '对应 Reader.is_active',
    `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'UTC',
    INDEX `idx_reader_card` (`reader_card_id`),
    INDEX `idx_reader_name` (`name`),
    INDEX `idx_reader_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='读者表';

-- ---------------------------------------------------------------------------
-- 3. 图书书目表：只存书目元数据，不存副本计数
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `books` (
    `id`           BIGINT AUTO_INCREMENT PRIMARY KEY,
    `isbn`         VARCHAR(20)  NULL COMMENT 'ISBN；契约允许 null，MySQL UNIQUE 允许多个 NULL',
    `title`        VARCHAR(255) NOT NULL COMMENT '书名',
    `author`       VARCHAR(255) NOT NULL COMMENT '作者',
    `publisher`    VARCHAR(255) NULL COMMENT '出版社；未知时为 NULL',
    `category`     VARCHAR(100) NULL COMMENT '分类；未分类时为 NULL',
    `published_on` DATE         NULL COMMENT '出版日期；契约 format: date，不是 date-time',
    `description`  TEXT         NULL COMMENT '图书简介，最大 2000 字符',
    `status`       ENUM('active','archived') NOT NULL DEFAULT 'active' COMMENT '软归档；GET /books 默认只返回 active',
    `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'UTC',
    UNIQUE KEY `uk_books_isbn` (`isbn`),
    INDEX `idx_books_title` (`title`),
    INDEX `idx_books_author` (`author`),
    INDEX `idx_books_category` (`category`),
    INDEX `idx_books_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='图书书目表（total_copies 由视图汇总）';

-- ---------------------------------------------------------------------------
-- 4. 馆藏实体副本表：Z1 要求「同一书目可有多本副本」
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `book_copies` (
    `id`         BIGINT AUTO_INCREMENT PRIMARY KEY,
    `book_id`    BIGINT NOT NULL COMMENT '所属书目',
    `barcode`    VARCHAR(64) NOT NULL UNIQUE COMMENT '馆藏条码；对应 Copy.barcode',
    `status`     ENUM('available','borrowed','retired') NOT NULL DEFAULT 'available'
                 COMMENT '只能由借还事务或退藏操作改变，不可直接 PATCH',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'UTC',
    CONSTRAINT `fk_copies_book` FOREIGN KEY (`book_id`)
        REFERENCES `books` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX `idx_copies_book_status` (`book_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='馆藏实体副本表；借还对象是副本而非书目';

-- ---------------------------------------------------------------------------
-- 5. 借阅记录表：对应 OpenAPI Loan
--    active_copy_id 为 STORED 生成列 + UNIQUE，保证同一副本同时最多一条 active 借阅，
--    这是第 10 周 M3「并发争用仅一次成功」的数据库层保障。
--    status='returned' 时生成列为 NULL，MySQL 唯一索引允许多个 NULL，故历史记录可累积。
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `borrow_records` (
    `id`             BIGINT AUTO_INCREMENT PRIMARY KEY,
    `copy_id`        BIGINT NOT NULL COMMENT '具体馆藏副本 ID，不是书目 ID',
    `reader_id`      BIGINT NOT NULL COMMENT '读者 ID',
    `status`         ENUM('active','returned') NOT NULL DEFAULT 'active'
                     COMMENT '逾期由 due_at 推导，不设 overdue 独立状态',
    `borrowed_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'UTC',
    `due_at`         DATETIME NOT NULL COMMENT 'UTC；借期长度待团队确认',
    `returned_at`    DATETIME NULL COMMENT '未归还时为 NULL',
    `active_copy_id` BIGINT GENERATED ALWAYS AS
                     (CASE WHEN `status` = 'active' THEN `copy_id` ELSE NULL END) STORED
                     COMMENT '同一副本唯一 active 借阅约束',
    CONSTRAINT `fk_loan_copy` FOREIGN KEY (`copy_id`)
        REFERENCES `book_copies` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_loan_reader` FOREIGN KEY (`reader_id`)
        REFERENCES `readers` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    UNIQUE KEY `uk_loan_active_copy` (`active_copy_id`),
    INDEX `idx_loan_reader_status` (`reader_id`, `status`),
    INDEX `idx_loan_due` (`due_at`),
    CONSTRAINT `chk_loan_returned_at` CHECK (`status` = 'active' OR `returned_at` IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='借阅记录表；对应 OpenAPI Loan';

-- ---------------------------------------------------------------------------
-- 6. 库存汇总视图：契约中 Book.total_copies / available_copies 为 readOnly，
--    一律从副本实时聚合，禁止在 books 表冗余存储或由接口直接写入。
--    retired 副本不计入总数；borrowed 计入总数但不计入可借数。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW `v_book_inventory` AS
SELECT
    `b`.`id` AS `book_id`,
    CAST(COUNT(`c`.`id`) AS SIGNED) AS `total_copies`,
    CAST(COALESCE(SUM(CASE WHEN `c`.`status` = 'available' THEN 1 ELSE 0 END), 0) AS SIGNED)
        AS `available_copies`
FROM `books` `b`
LEFT JOIN `book_copies` `c`
    ON `c`.`book_id` = `b`.`id` AND `c`.`status` <> 'retired'
GROUP BY `b`.`id`;
