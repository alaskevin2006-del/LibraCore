#pragma once

#include <string>
#include <vector>
#include <functional>
#include <cstdint>
#include <memory>

namespace repository {

// 图书实体定义（与数据库 books 表字段严格一致）
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
    using QueryCallback = std::function<void(const std::vector<Book>&)>;
    using ErrorCallback = std::function<void(const std::string&)>;

    // 查询图书列表：keyword 为空时查全部，非空时按书名、作者或 ISBN 模糊搜索
    void queryBooks(const std::string &keyword,
                    const QueryCallback &successCb,
                    const ErrorCallback &errorCb);
};

} // namespace repository