#include "BookRepository.h"

#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Result.h>
#include <drogon/orm/Exception.h>

namespace repository {
namespace {

// 泛型 lambda 避免依赖 Drogon Row 的具体类型名；所有可空列统一做 NULL 检查。
const auto makeBookFromRow = [](const auto &row) -> Book {
    Book b;
    b.id               = row["id"].as<int64_t>();
    b.isbn             = row["isbn"].isNull()           ? "" : row["isbn"].as<std::string>();
    b.title            = row["title"].as<std::string>();
    b.author           = row["author"].as<std::string>();
    b.publisher        = row["publisher"].isNull()      ? "" : row["publisher"].as<std::string>();
    b.category         = row["category"].isNull()       ? "" : row["category"].as<std::string>();
    b.publishedOn      = row["published_on"].isNull()   ? "" : row["published_on"].as<std::string>();
    b.description      = row["description"].isNull()    ? "" : row["description"].as<std::string>();
    b.status           = row["status"].as<std::string>();
    b.createdAt        = row["created_at"].isNull()     ? "" : row["created_at"].as<std::string>();
    // 视图列经 CAST(... AS SIGNED) 返回 BIGINT，先按 int64_t 读再收窄。
    b.totalCopies      = row["total_copies"].isNull()
                       ? 0 : static_cast<int>(row["total_copies"].as<int64_t>());
    b.availableCopies  = row["available_copies"].isNull()
                       ? 0 : static_cast<int>(row["available_copies"].as<int64_t>());
    return b;
};

const auto makeCopyFromRow = [](const auto &row) -> BookCopy {
    BookCopy c;
    c.id        = row["id"].as<int64_t>();
    c.bookId    = row["book_id"].as<int64_t>();
    c.barcode   = row["barcode"].as<std::string>();
    c.status    = row["status"].as<std::string>();
    c.createdAt = row["created_at"].isNull() ? "" : row["created_at"].as<std::string>();
    return c;
};

const char *kBookSelect =
    "SELECT b.id, b.isbn, b.title, b.author, b.publisher, b.category, "
    "b.published_on, b.description, b.status, b.created_at, "
    "COALESCE(inv.total_copies, 0) AS total_copies, "
    "COALESCE(inv.available_copies, 0) AS available_copies "
    "FROM books b LEFT JOIN v_book_inventory inv ON inv.book_id = b.id ";

} // namespace

void BookRepository::queryBooks(const std::string &keyword, int page, int pageSize,
                                const QueryCallback &successCb, const ErrorCallback &errorCb,
                                bool includeArchived) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    if (page < 1) page = 1;
    if (pageSize < 1 || pageSize > 100) pageSize = 10;
    const int offset = (page - 1) * pageSize;
    const bool hasKeyword = !keyword.empty();
    const std::string pattern = "%" + keyword + "%";

    std::string where;
    if (!includeArchived) where += "WHERE b.status = 'active' ";
    if (hasKeyword) {
        where += where.empty() ? "WHERE " : "AND ";
        where += "(b.title LIKE ? OR b.author LIKE ? OR b.isbn LIKE ?) ";
    }

    const std::string countSql =
        "SELECT COUNT(*) AS total FROM books b " + where;
    const std::string dataSql =
        std::string(kBookSelect) + where + "ORDER BY b.id DESC LIMIT ? OFFSET ?";

    // 注意：COUNT 与数据分两次异步查询，期间若有写入，total 可能略有偏差。
    // 强一致场景应由 Service 层用事务包裹（第 10 周 M3 联调时处理）。
    auto executeQuery = [=](int64_t total) {
        auto rowHandler = [successCb, total](const drogon::orm::Result &result) {
            std::vector<Book> books;
            books.reserve(result.size());
            for (const auto &row : result) books.push_back(makeBookFromRow(row));
            if (successCb) successCb(books, total);
        };
        auto onError = [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        };
        if (hasKeyword) {
            dbClient->execSqlAsync(dataSql, rowHandler, onError,
                                   pattern, pattern, pattern, pageSize, offset);
        } else {
            dbClient->execSqlAsync(dataSql, rowHandler, onError, pageSize, offset);
        }
    };

    auto countHandler = [=](const drogon::orm::Result &countResult) {
        int64_t total = 0;
        if (!countResult.empty()) total = countResult[0]["total"].as<int64_t>();
        executeQuery(total);
    };
    auto onCountError = [errorCb](const drogon::orm::DrogonDbException &e) {
        if (errorCb) errorCb(e.base().what());
    };
    if (hasKeyword) {
        dbClient->execSqlAsync(countSql, countHandler, onCountError, pattern, pattern, pattern);
    } else {
        dbClient->execSqlAsync(countSql, countHandler, onCountError);
    }
}

void BookRepository::getBookById(int64_t id, const SingleCallback &successCb,
                                 const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql = std::string(kBookSelect) + "WHERE b.id = ?";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (result.empty()) {
                if (successCb) successCb(Book{}, false);
                return;
            }
            if (successCb) successCb(makeBookFromRow(result[0]), true);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id);
}

void BookRepository::queryCopiesByBookId(int64_t bookId, const CopiesCallback &successCb,
                                         const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql =
        "SELECT id, book_id, barcode, status, created_at FROM book_copies "
        "WHERE book_id = ? ORDER BY id ASC";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            std::vector<BookCopy> copies;
            copies.reserve(result.size());
            for (const auto &row : result) copies.push_back(makeCopyFromRow(row));
            if (successCb) successCb(copies);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        bookId);
}

void BookRepository::addBook(const Book &book,
                             const std::function<void(int64_t newId)> &successCb,
                             const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    // NULLIF 把空串写成 SQL NULL，对应契约中可空字段；status 固定 active。
    const std::string sql =
        "INSERT INTO books (isbn, title, author, publisher, category, published_on, description, status) "
        "VALUES (NULLIF(?, ''), ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), 'active')";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(static_cast<int64_t>(result.insertId()));
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        book.isbn, book.title, book.author, book.publisher, book.category,
        book.publishedOn, book.description);
}

void BookRepository::updateBook(const Book &book, const ActionCallback &successCb,
                                const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    // 不更新 status（归档走 deleteBook），也不更新 total_copies/available_copies（只读派生值）。
    const std::string sql =
        "UPDATE books SET isbn = NULLIF(?, ''), title = ?, author = ?, "
        "publisher = NULLIF(?, ''), category = NULLIF(?, ''), "
        "published_on = NULLIF(?, ''), description = NULLIF(?, '') WHERE id = ?";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(true, static_cast<int64_t>(result.affectedRows()));
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        book.isbn, book.title, book.author, book.publisher, book.category,
        book.publishedOn, book.description, book.id);
}

void BookRepository::deleteBook(int64_t id, const ActionCallback &successCb,
                                const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    // 第一步：软归档。仍有 borrowed 副本时 affectedRows=0（契约 409 RESOURCE_IN_USE）。
    // SQL 子查询引用的是 book_copies，不是被更新的 books，MySQL 允许。
    const std::string archiveSql =
        "UPDATE books SET status = 'archived' WHERE id = ? AND status = 'active' "
        "AND NOT EXISTS (SELECT 1 FROM book_copies c WHERE c.book_id = ? AND c.status = 'borrowed')";

    dbClient->execSqlAsync(archiveSql,
        [=](const drogon::orm::Result &result) {
            const int64_t affected = static_cast<int64_t>(result.affectedRows());
            if (affected == 0) {
                if (errorCb) {
                    errorCb("Archive rejected: book not found, already archived, "
                            "or still has borrowed copies (409 RESOURCE_IN_USE).");
                }
                return;
            }
            // 第二步：把该书可借副本统一退藏。
            // 两步串行执行，尚未包在事务里；第 10 周 M3 联调时由 Service 层加事务包裹。
            const std::string retireSql =
                "UPDATE book_copies SET status = 'retired' WHERE book_id = ? AND status = 'available'";
            dbClient->execSqlAsync(retireSql,
                [successCb, affected](const drogon::orm::Result &) {
                    if (successCb) successCb(true, affected);
                },
                [errorCb](const drogon::orm::DrogonDbException &e) {
                    if (errorCb) errorCb(e.base().what());
                },
                id);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id, id);
}

} // namespace repository
