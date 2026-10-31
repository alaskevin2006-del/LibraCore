#pragma once

#include <string>
#include <vector>
#include <functional>
#include <cstdint>
#include <memory>
#include <drogon/drogon.h>

namespace repository {

struct Book {
    int64_t id{0};
    std::string isbn;
    std::string title;
    std::string author;
    std::string publisher;
    int publishYear{0};
    std::string category;
    int totalCopies{1};
    int availableCopies{1};
};

class BookRepository {
public:
    using QueryCallback = std::function<void(const std::vector<Book>&, int64_t total)>;
    using SingleCallback = std::function<void(const Book&, bool found)>;
    using ActionCallback = std::function<void(bool success, int64_t affectedRows)>;
    using ErrorCallback = std::function<void(const std::string&)>;

    // 1. 分页检索图书（keyword 支持书名、作者、ISBN 模糊匹配，page 从 1 开始）
    void queryBooks(const std::string &keyword, int page, int pageSize,
                    const QueryCallback &successCb, const ErrorCallback &errorCb);

    // 2. 根据 ID 查询单本图书详情
    void getBookById(int64_t id, const SingleCallback &successCb, const ErrorCallback &errorCb);

    // 3. 新增图书
    void addBook(const Book &book, const std::function<void(int64_t newId)> &successCb, const ErrorCallback &errorCb);

    // 4. 更新图书信息
    void updateBook(const Book &book, const ActionCallback &successCb, const ErrorCallback &errorCb);

    // 5. 删除图书
    void deleteBook(int64_t id, const ActionCallback &successCb, const ErrorCallback &errorCb);
};

} // namespace repository