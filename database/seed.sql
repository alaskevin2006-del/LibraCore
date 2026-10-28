USE `libracore`;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE `borrow_records`;
TRUNCATE TABLE `books`;
TRUNCATE TABLE `readers`;
TRUNCATE TABLE `admins`;
SET FOREIGN_KEY_CHECKS = 1;

-- 插入虚构管理员 (密码仅占位，符合安全约定)
INSERT INTO `admins` (`username`, `password_hash`, `name`) VALUES
('admin01', 'mock_hash_admin', '系统管理员');

-- 插入虚构读者 (不使用真实学生隐私数据)
INSERT INTO `readers` (`reader_card_id`, `name`, `password_hash`, `email`, `phone`, `status`) VALUES
('R2026001', '测试读者小张', 'mock_hash_user1', 'zhang@mock.edu.cn', '13800000001', 'active'),
('R2026002', '测试读者小李', 'mock_hash_user2', 'li@mock.edu.cn', '13800000002', 'active');

-- 插入 10 条模拟图书书目 (含馆藏与可借册数)
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
(10, '9787115531421', '现代心理学史', 'Duane P. Schultz', '人民邮电出版社', 2020, '心理学', 1, 1);

-- 插入 2 条初始借阅记录示例
INSERT INTO `borrow_records` (`reader_id`, `book_id`, `borrow_time`, `due_time`, `status`) VALUES
(1, 1, '2026-10-20 10:00:00', '2026-11-20 10:00:00', 'active'),
(2, 4, '2026-10-22 14:30:00', '2026-11-22 14:30:00', 'active');