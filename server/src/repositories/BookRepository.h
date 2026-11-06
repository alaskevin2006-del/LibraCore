#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace repository {

// 对应 api/openapi.yaml 的 Copy
struct BookCopy {
    int64_t id{0};
    int64_t bookId{0};
    std::string barcode;
    std::string status{"available"};
    std::string createdAt;
};

// 对应 api/openapi.yaml 的 Book。
// totalCopies / availableCopies 是只读派生值，由 v_book_inventory 汇总，
// addBook / updateBook 一律忽略这两个字段，避免计数与副本状态不一致。
struct Book {
    int64_t id{0};
    std::string isbn;
    std::string title;
    std::string author;
    std::string publisher;
    std::string category;
    std::string publishedOn;   // YYYY-MM-DD；空串代表 SQL NULL
    std::string description;
    std::string status{"active"}; // active | archived
    int totalCopies{0};           // readOnly，来自视图
    int availableCopies{0};       // readOnly，来自视图
    std::string createdAt;        // UTC
};

class BookRepository {
public:
    using QueryCallback  = std::function<void(const std::vector<Book>&, int64_t total)>;
    using SingleCallback = std::function<void(const Book&, bool found)>;
    using CopiesCallback = std::function<void(const std::vector<BookCopy>&)>;
    using ActionCallback = std::function<void(bool success, int64_t affectedRows)>;
    using ErrorCallback  = std::function<void(const std::string&)>;

    // 分页检索图书：keyword 模糊匹配 title/author/isbn；page 从 1 开始；pageSize 限制 1-100。
    // 契约 GET /books 默认只返回 active；includeArchived=true 供管理员使用（待团队评审）。
    void queryBooks(const std::string &keyword, int page, int pageSize,
                    const QueryCallback &successCb, const ErrorCallback &errorCb,
                    bool includeArchived = false);

    // 按 ID 查单本；归档书目仍可按 ID 访问（待确认项 books-archived-visibility）。
    void getBookById(int64_t id, const SingleCallback &successCb, const ErrorCallback &errorCb);

    // 查询某书目下的实体副本，对应 GET /books/{book_id}/copies。
    // 默认包含 retired；是否过滤由待确认项 copies-visibility 决定。
    void queryCopiesByBookId(int64_t bookId, const CopiesCallback &successCb,
                             const ErrorCallback &errorCb);

    // 新增书目：只写书目元数据，不写计数字段。
    void addBook(const Book &book, const std::function<void(int64_t newId)> &successCb,
                 const ErrorCallback &errorCb);

    // 更新书目元数据：忽略 status 与两个只读计数字段。
    void updateBook(const Book &book, const ActionCallback &successCb, const ErrorCallback &errorCb);

    // 软归档书目。保留方法名以兼容既有调用方，但不再执行物理 DELETE：
    // 仍有 borrowed 副本时拒绝归档（契约 409），成功后把 available 副本统一退藏。
    void deleteBook(int64_t id, const ActionCallback &successCb, const ErrorCallback &errorCb);
};

} // namespace repository
