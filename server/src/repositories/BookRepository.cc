#include "BookRepository.h"
#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Result.h>
#include <drogon/orm/Exception.h>

namespace repository {

void BookRepository::queryBooks(const std::string &keyword, int page, int pageSize,
                                const QueryCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    if (page < 1) page = 1;
    if (pageSize < 1 || pageSize > 100) pageSize = 10;
    int offset = (page - 1) * pageSize;

    bool hasKeyword = !keyword.empty();
    std::string countSql = hasKeyword 
        ? "SELECT COUNT(*) AS total FROM books WHERE title LIKE ? OR author LIKE ? OR isbn LIKE ?"
        : "SELECT COUNT(*) AS total FROM books";

    std::string dataSql = hasKeyword
        ? "SELECT id, isbn, title, author, publisher, publish_year, category, total_copies, available_copies "
          "FROM books WHERE title LIKE ? OR author LIKE ? OR isbn LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?"
        : "SELECT id, isbn, title, author, publisher, publish_year, category, total_copies, available_copies "
          "FROM books ORDER BY id DESC LIMIT ? OFFSET ?";

    std::string pattern = "%" + keyword + "%";

    auto executeQuery = [=](int64_t total) {
        auto rowHandler = [successCb, total](const drogon::orm::Result &result) {
            std::vector<Book> books;
            books.reserve(result.size());
            for (const auto &row : result) {
                Book b;
                b.id = row["id"].as<int64_t>();
                b.isbn = row["isbn"].as<std::string>();
                b.title = row["title"].as<std::string>();
                b.author = row["author"].as<std::string>();
                b.publisher = row["publisher"].as<std::string>();
                b.publishYear = row["publish_year"].isNull() ? 0 : row["publish_year"].as<int>();
                b.category = row["category"].as<std::string>();
                b.totalCopies = row["total_copies"].as<int>();
                b.availableCopies = row["available_copies"].as<int>();
                books.push_back(std::move(b));
            }
            if (successCb) successCb(books, total);
        };

        if (hasKeyword) {
            dbClient->execSqlAsync(dataSql, rowHandler,
                [errorCb](const drogon::orm::DrogonDbException &e) { if (errorCb) errorCb(e.base().what()); },
                pattern, pattern, pattern, pageSize, offset);
        } else {
            dbClient->execSqlAsync(dataSql, rowHandler,
                [errorCb](const drogon::orm::DrogonDbException &e) { if (errorCb) errorCb(e.base().what()); },
                pageSize, offset);
        }
    };

    auto countHandler = [=](const drogon::orm::Result &countResult) {
        int64_t total = 0;
        if (!countResult.empty()) {
            total = countResult[0]["total"].as<int64_t>();
        }
        executeQuery(total);
    };

    if (hasKeyword) {
        dbClient->execSqlAsync(countSql, countHandler,
            [errorCb](const drogon::orm::DrogonDbException &e) { if (errorCb) errorCb(e.base().what()); },
            pattern, pattern, pattern);
    } else {
        dbClient->execSqlAsync(countSql, countHandler,
            [errorCb](const drogon::orm::DrogonDbException &e) { if (errorCb) errorCb(e.base().what()); });
    }
}

void BookRepository::getBookById(int64_t id, const SingleCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "SELECT id, isbn, title, author, publisher, publish_year, category, "
                      "total_copies, available_copies FROM books WHERE id = ?";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (result.empty()) {
                if (successCb) successCb(Book{}, false);
                return;
            }
            const auto &row = result[0];
            Book b;
            b.id = row["id"].as<int64_t>();
            b.isbn = row["isbn"].as<std::string>();
            b.title = row["title"].as<std::string>();
            b.author = row["author"].as<std::string>();
            b.publisher = row["publisher"].as<std::string>();
            b.publishYear = row["publish_year"].isNull() ? 0 : row["publish_year"].as<int>();
            b.category = row["category"].as<std::string>();
            b.totalCopies = row["total_copies"].as<int>();
            b.availableCopies = row["available_copies"].as<int>();
            if (successCb) successCb(b, true);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id);
}

void BookRepository::addBook(const Book &book, const std::function<void(int64_t newId)> &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "INSERT INTO books (isbn, title, author, publisher, publish_year, category, "
                      "total_copies, available_copies) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(static_cast<int64_t>(result.insertId()));
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        book.isbn, book.title, book.author, book.publisher, book.publishYear,
        book.category, book.totalCopies, book.availableCopies);
}

void BookRepository::updateBook(const Book &book, const ActionCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "UPDATE books SET isbn = ?, title = ?, author = ?, publisher = ?, "
                      "publish_year = ?, category = ?, total_copies = ?, available_copies = ? WHERE id = ?";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(true, result.affectedRows());
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        book.isbn, book.title, book.author, book.publisher, book.publishYear,
        book.category, book.totalCopies, book.availableCopies, book.id);
}

void BookRepository::deleteBook(int64_t id, const ActionCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "DELETE FROM books WHERE id = ?";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(true, result.affectedRows());
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id);
}

} // namespace repository