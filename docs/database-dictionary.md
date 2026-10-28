# 数据字典

## 1. 实体与关系
- **admins**：管理员账号表。
- **readers**：读者信息表。与 `borrow_records` 为 1:N 关系[cite: 1, 2]。
- **books**：图书书目与库存表。与 `borrow_records` 为 1:N 关系[cite: 1, 2]。
- **borrow_records**：借阅记录流水表[cite: 1, 2]。外键关联 `readers(id)`（级联删除）与 `books(id)`（限制删除）[cite: 1, 2, 12]。

## 2. 表结构定义

### 2.1 admins (管理员)
| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| id | BIGINT | PK, AUTO_INCREMENT | 管理员ID |
| username | VARCHAR(50) | NOT NULL, UNIQUE | 登录账号 |
| password_hash | VARCHAR(255) | NOT NULL | 密码哈希 |
| name | VARCHAR(50) | NOT NULL | 管理员姓名 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |

### 2.2 readers (读者)
| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| id | BIGINT | PK, AUTO_INCREMENT | 读者ID |
| reader_card_id | VARCHAR(50) | NOT NULL, UNIQUE | 读者卡号/学号 |
| name | VARCHAR(50) | NOT NULL | 读者姓名 |
| password_hash | VARCHAR(255) | NOT NULL | 密码哈希 |
| email | VARCHAR(100) | NULL | 邮箱 |
| phone | VARCHAR(20) | NULL | 电话 |
| status | ENUM('active','suspended') | NOT NULL, DEFAULT 'active' | 状态：正常/停用 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 注册时间 |

### 2.3 books (图书)
| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| id | BIGINT | PK, AUTO_INCREMENT | 图书ID |
| isbn | VARCHAR(20) | NOT NULL, UNIQUE, INDEX | 国际标准书号 |
| title | VARCHAR(200) | NOT NULL, INDEX | 书名 |
| author | VARCHAR(100) | NOT NULL | 作者 |
| publisher | VARCHAR(100) | NOT NULL | 出版社 |
| publish_year | INT | NULL | 出版年份 |
| category | VARCHAR(50) | NOT NULL, DEFAULT 'General', INDEX | 图书分类 |
| total_copies | INT | NOT NULL, DEFAULT 1 | 馆藏总册数 |
| available_copies | INT | NOT NULL, DEFAULT 1 | 当前可借册数 |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 创建时间 |

### 2.4 borrow_records (借阅记录)
| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| id | BIGINT | PK, AUTO_INCREMENT | 记录ID |
| reader_id | BIGINT | NOT NULL, FK -> readers(id) ON DELETE CASCADE | 读者ID |
| book_id | BIGINT | NOT NULL, FK -> books(id) ON DELETE RESTRICT | 图书ID |
| borrow_time | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 借阅时间 |
| due_time | DATETIME | NOT NULL | 应还时间 |
| return_time | DATETIME | NULL | 归还时间 |
| status | ENUM('active','returned','overdue') | NOT NULL, DEFAULT 'active' | 状态：借出/已还/逾期[cite: 1, 2] |