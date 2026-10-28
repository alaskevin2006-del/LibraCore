CREATE DATABASE IF NOT EXISTS `libracore` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `libracore`;

-- 1. 管理员表 (admins)
CREATE TABLE IF NOT EXISTS `admins` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) NOT NULL UNIQUE COMMENT '管理员登录账号',
    `password_hash` VARCHAR(255) NOT NULL COMMENT '哈希密码',
    `name` VARCHAR(50) NOT NULL COMMENT '管理员姓名',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员表';

-- 2. 读者表 (readers)
CREATE TABLE IF NOT EXISTS `readers` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `reader_card_id` VARCHAR(50) NOT NULL UNIQUE COMMENT '读者卡号/学号',
    `name` VARCHAR(50) NOT NULL COMMENT '读者姓名',
    `password_hash` VARCHAR(255) NOT NULL COMMENT '哈希密码',
    `email` VARCHAR(100) NULL COMMENT '联系邮箱',
    `phone` VARCHAR(20) NULL COMMENT '联系电话',
    `status` ENUM('active', 'suspended') NOT NULL DEFAULT 'active' COMMENT '账号状态',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_reader_card` (`reader_card_id`),
    INDEX `idx_reader_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='读者表';

-- 3. 图书表 (books)
CREATE TABLE IF NOT EXISTS `books` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `isbn` VARCHAR(20) NOT NULL UNIQUE COMMENT '标准书号 ISBN',
    `title` VARCHAR(200) NOT NULL COMMENT '书名',
    `author` VARCHAR(100) NOT NULL COMMENT '作者',
    `publisher` VARCHAR(100) NOT NULL COMMENT '出版社',
    `publish_year` INT NULL COMMENT '出版年份',
    `category` VARCHAR(50) NOT NULL DEFAULT 'General' COMMENT '图书分类',
    `total_copies` INT NOT NULL DEFAULT 1 COMMENT '馆藏总册数',
    `available_copies` INT NOT NULL DEFAULT 1 COMMENT '当前在馆可借册数',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_books_title` (`title`),
    INDEX `idx_books_author` (`author`),
    INDEX `idx_books_isbn` (`isbn`),
    INDEX `idx_books_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='图书书目表';

-- 4. 借阅记录表 (borrow_records)
CREATE TABLE IF NOT EXISTS `borrow_records` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `reader_id` BIGINT NOT NULL COMMENT '读者ID',
    `book_id` BIGINT NOT NULL COMMENT '图书ID',
    `borrow_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '借出时间',
    `due_time` DATETIME NOT NULL COMMENT '应还时间',
    `return_time` DATETIME NULL COMMENT '实际归还时间',
    `status` ENUM('active', 'returned', 'overdue') NOT NULL DEFAULT 'active' COMMENT '借阅状态',
    CONSTRAINT `fk_borrow_reader` FOREIGN KEY (`reader_id`) REFERENCES `readers` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_borrow_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='借阅记录表';