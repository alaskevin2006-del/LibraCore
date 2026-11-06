-- LibraCore 测试数据 v1.0（全部为虚构数据，不含任何真实个人信息）
-- 前置：先执行 database/schema.sql
-- 执行：mysql -u <user> -p < database/seed.sql
--
-- 可重复执行：按子表 -> 父表顺序清空后重建。
-- 借还对象是具体副本(copy_id)；视图 v_book_inventory 会自动汇总
-- total_copies / available_copies，本脚本不再手工写入计数字段。
--
-- 数据规模：15 本 active 书目 + 1 本 archived 书目（验证归档过滤）
--           44 条副本（41 available / 2 borrowed / 1 retired）
--           3 条借阅记录（2 active / 1 returned）
--           3 名读者 + 1 名管理员

USE `libra_core`;

-- 密码仅为占位哈希，用于结构验证，不可用于真实登录；
-- 认证接入由后端负责人(lkx)替换为实际哈希算法后重新生成。
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM `borrow_records`;
DELETE FROM `book_copies`;
DELETE FROM `books`;
DELETE FROM `readers`;
DELETE FROM `admins`;
ALTER TABLE `borrow_records` AUTO_INCREMENT = 1;
ALTER TABLE `book_copies`    AUTO_INCREMENT = 1;
ALTER TABLE `books`          AUTO_INCREMENT = 1;
ALTER TABLE `readers`        AUTO_INCREMENT = 1;
ALTER TABLE `admins`         AUTO_INCREMENT = 1;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. 管理员
INSERT INTO `admins` (`username`, `password_hash`, `name`) VALUES
('admin01', 'mock_hash_admin', '系统管理员');

-- 2. 读者（status='active'/'suspended' 对应 OpenAPI is_active）
INSERT INTO `readers` (`reader_card_id`, `name`, `password_hash`, `email`, `phone`, `status`) VALUES
('R2026001', '测试读者小张', 'mock_hash_user1', 'zhang@mock.edu.cn', '13800000001', 'active'),
('R2026002', '测试读者小李', 'mock_hash_user2', 'li@mock.edu.cn',   '13800000002', 'active'),
('R2026003', '测试读者小王', 'mock_hash_user3', 'wang@mock.edu.cn', '13800000003', 'suspended');

-- 3. 书目（published_on 为 DATE；status 默认 active；第 16 条用于归档过滤验证）
INSERT INTO `books`
    (`id`, `isbn`, `title`, `author`, `publisher`, `category`, `published_on`, `description`, `status`) VALUES
(1,  '9787111544937', '深入理解计算机系统',       'Randal E. Bryant',       '机械工业出版社', '计算机科学', '2016-01-01', '从程序员视角讲解计算机系统底层原理的示例简介。', 'active'),
(2,  '9787302423287', '软件工程：实践者的研究方法', 'Roger S. Pressman',      '清华大学出版社', '软件工程',   '2016-01-01', '软件工程过程与实践方法的示例简介。',           'active'),
(3,  '9787115546081', 'C++ Primer 中文版',         'Stanley B. Lippman',     '人民邮电出版社', '程序设计',   '2013-01-01', 'C++ 语言入门与标准库的示例简介。',              'active'),
(4,  '9787111213824', '算法导论',                   'Thomas H. Cormen',       '机械工业出版社', '算法',       '2006-01-01', NULL,                                        'active'),
(5,  '9787121369970', 'MySQL是怎样运行的',          '小孩子4919',             '电子工业出版社', '数据库',     '2020-01-01', 'MySQL 存储与查询原理的示例简介。',              'active'),
(6,  '9787115275790', 'JavaScript高级程序设计',     'Nicholas C. Zakas',      '人民邮电出版社', '前端开发',   '2012-01-01', NULL,                                        'active'),
(7,  '9787111633457', '计算机网络：自顶向下方法',    'James F. Kurose',        '机械工业出版社', '网络通信',   '2018-01-01', NULL,                                        'active'),
(8,  '9787302514083', '操作系统概念',               'Abraham Silberschatz',   '清华大学出版社', '操作系统',   '2018-01-01', NULL,                                        'active'),
(9,  '9787111255831', '设计模式：可复用面向对象软件的基础', 'Erich Gamma 等', '机械工业出版社', '软件工程',   '2007-01-01', NULL,                                        'active'),
(10, '9787115531421', '现代心理学史',               'Duane P. Schultz',       '人民邮电出版社', '心理学',     '2020-01-01', NULL,                                        'active'),
(11, '9787508647357', '人类简史',                   '尤瓦尔·赫拉利',          '中信出版社',     '历史',       '2014-01-01', '人类文明发展脉络的示例简介。',                  'active'),
(12, '9787020002207', '平凡的世界',                 '路遥',                   '人民文学出版社', '文学',       '2005-01-01', NULL,                                        'active'),
(13, '9787532725694', '百年孤独',                   '加西亚·马尔克斯',        '南海出版公司',   '文学',       '2011-01-01', NULL,                                        'active'),
(14, '9787111608332', '重构：改善既有代码的设计',    'Martin Fowler',          '人民邮电出版社', '软件工程',   '2019-01-01', NULL,                                        'active'),
(15, '9787302330882', '编译原理',                   'Alfred V. Aho',          '机械工业出版社', '计算机科学', '2008-01-01', NULL,                                        'active'),
(16, '9787000000001', '示例归档书目',               '示例作者',               '示例出版社',     '其他',       '2001-01-01', '仅用于验证 GET /books 默认不返回 archived 书目。', 'archived');

-- 4. 实体副本：barcode 规则 LC-<书目ID 3位>-<副本序号 2位>
--    LC-001-03 与 LC-004-02 处于 borrowed（与下方 active 借阅记录一致）
--    LC-016-01 为 retired，且不计入 v_book_inventory.total_copies
INSERT INTO `book_copies` (`book_id`, `barcode`, `status`) VALUES
(1,  'LC-001-01', 'available'), (1,  'LC-001-02', 'available'), (1,  'LC-001-03', 'borrowed'),
(2,  'LC-002-01', 'available'), (2,  'LC-002-02', 'available'),
(3,  'LC-003-01', 'available'), (3,  'LC-003-02', 'available'), (3,  'LC-003-03', 'available'), (3,  'LC-003-04', 'available'),
(4,  'LC-004-01', 'available'), (4,  'LC-004-02', 'borrowed'),
(5,  'LC-005-01', 'available'), (5,  'LC-005-02', 'available'), (5,  'LC-005-03', 'available'), (5,  'LC-005-04', 'available'), (5,  'LC-005-05', 'available'),
(6,  'LC-006-01', 'available'), (6,  'LC-006-02', 'available'),
(7,  'LC-007-01', 'available'), (7,  'LC-007-02', 'available'), (7,  'LC-007-03', 'available'),
(8,  'LC-008-01', 'available'), (8,  'LC-008-02', 'available'), (8,  'LC-008-03', 'available'),
(9,  'LC-009-01', 'available'), (9,  'LC-009-02', 'available'),
(10, 'LC-010-01', 'available'),
(11, 'LC-011-01', 'available'), (11, 'LC-011-02', 'available'), (11, 'LC-011-03', 'available'), (11, 'LC-011-04', 'available'), (11, 'LC-011-05', 'available'),
(12, 'LC-012-01', 'available'), (12, 'LC-012-02', 'available'), (12, 'LC-012-03', 'available'), (12, 'LC-012-04', 'available'),
(13, 'LC-013-01', 'available'), (13, 'LC-013-02', 'available'), (13, 'LC-013-03', 'available'),
(14, 'LC-014-01', 'available'), (14, 'LC-014-02', 'available'),
(15, 'LC-015-01', 'available'), (15, 'LC-015-02', 'available'),
(16, 'LC-016-01', 'retired');

-- 5. 借阅记录：用 barcode 反查 copy_id，不依赖 AUTO_INCREMENT 的具体取值
--    两条 active：验证「副本状态 borrowed <-> 借阅记录 active」一致
--    一条 returned：验证同一副本可累积历史记录、returned_at 非空
INSERT INTO `borrow_records` (`copy_id`, `reader_id`, `status`, `borrowed_at`, `due_at`, `returned_at`)
SELECT `c`.`id`, 1, 'active', '2026-10-20 10:00:00', '2026-11-20 10:00:00', NULL
FROM `book_copies` `c` WHERE `c`.`barcode` = 'LC-001-03';

INSERT INTO `borrow_records` (`copy_id`, `reader_id`, `status`, `borrowed_at`, `due_at`, `returned_at`)
SELECT `c`.`id`, 2, 'active', '2026-10-22 14:30:00', '2026-11-22 14:30:00', NULL
FROM `book_copies` `c` WHERE `c`.`barcode` = 'LC-004-02';

INSERT INTO `borrow_records` (`copy_id`, `reader_id`, `status`, `borrowed_at`, `due_at`, `returned_at`)
SELECT `c`.`id`, 2, 'returned', '2026-09-01 09:00:00', '2026-09-30 09:00:00', '2026-09-25 14:00:00'
FROM `book_copies` `c` WHERE `c`.`barcode` = 'LC-002-01';

-- 初始化结果请用 tests/database/verify_schema.sql 核对。
