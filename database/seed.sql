USE `libracore`;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE `borrow_records`;
TRUNCATE TABLE `books`;
TRUNCATE TABLE `readers`;
TRUNCATE TABLE `admins`;
SET FOREIGN_KEY_CHECKS = 1;

-- 初始管理员
INSERT INTO `admins` (`username`, `password_hash`, `name`) VALUES
('admin01', 'mock_hash_admin', '系统管理员');

-- 初始读者
INSERT INTO `readers` (`reader_card_id`, `name`, `password_hash`, `email`, `phone`, `status`) VALUES
('R2026001', '测试读者小张', 'mock_hash_user1', 'zhang@mock.edu.cn', '13800000001', 'active'),
('R2026002', '测试读者小李', 'mock_hash_user2', 'li@mock.edu.cn', '13800000002', 'active'),
('R2026003', '测试读者小王', 'mock_hash_user3', 'wang@mock.edu.cn', '13800000003', 'suspended');

-- 15 条图书种子数据（支持第1页和第2页分页测试）
INSERT INTO `books` (`id`, `isbn`, `title`, `author`, `publisher`, `publish_year`, `category`, `total_copies`, `available_copies`) VALUES
(1, '9787111544937', '深入理解计算机系统', 'Randal E. Bryant', '机械工业出版社', 2016, '计算机科学', 3, 2),
(2, '9787302423287', '软件工程：实践者的研究方法', 'Roger S. Pressman', '清华大学出版社', 2016, '软件工程', 2, 2),
(3, '9787115546081', 'C++ Primer 中文版', 'Stanley B. Lippman', '人民邮电出版社', 2013, '程序设计', 4, 3),
(4, '9787111213824', '算法导论', 'Thomas H. Cormen', '机械工业出版社', 2006, '算法', 2, 1),
(5, '9787121369970', 'MySQL是怎样运行的', '小孩子4919', '电子工业出版社', 2020, '数据库', 5, 5),
(6, '9787115275790', 'JavaScript高级程序设计', 'Nicholas C. Zakas', '人民邮电出版社', 2012, '前端开发', 2, 2),
(7, '9787111633457', '计算机网络：自顶向下方法', 'James F. Kurose', '机械工业出版社', 2018, '网络通信', 3, 2),
(8, '9787302514083', '操作系统概念', 'Abraham Silberschatz', '清华大学出版社', 2018, '操作系统', 3, 3),
(9, '9787111255831', '设计模式：可复用面向对象软件的基础', 'Erich Gamma 等', '机械工业出版社', 2007, '软件工程', 2, 2),
(10, '9787115531421', '现代心理学史', 'Duane P. Schultz', '人民邮电出版社', 2020, '心理学', 1, 1),
(11, '9787508647357', '人类简史', '尤瓦尔·赫拉利', '中信出版社', 2014, '历史', 5, 5),
(12, '9787020002207', '平凡的世界', '路遥', '人民文学出版社', 2005, '文学', 4, 4),
(13, '9787532725694', '百年孤独', '加西亚·马尔克斯', '南海出版公司', 2011, '文学', 3, 3),
(14, '9787111608332', '重构：改善既有代码的设计', 'Martin Fowler', '人民邮电出版社', 2019, '软件工程', 2, 2),
(15, '9787302330882', '编译原理', 'Alfred V. Aho', '机械工业出版社', 2008, '计算机科学', 2, 2);

-- 初始借阅记录示例
INSERT INTO `borrow_records` (`reader_id`, `book_id`, `borrow_time`, `due_time`, `status`) VALUES
(1, 1, '2026-10-20 10:00:00', '2026-11-20 10:00:00', 'active'),
(2, 4, '2026-10-22 14:30:00', '2026-11-22 14:30:00', 'active');