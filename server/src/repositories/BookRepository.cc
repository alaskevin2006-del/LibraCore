#include "BookRepository.h"
#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Result.h>
#include <drogon/orm/Exception.h>

namespace repository {

void BookRepository::queryBooks(const std::string &keyword,
                                const QueryCallback &successCb,
                                const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) {
            errorCb("Database client is not initialized.");
        }
        return;
    }

    std::string sql;
    // 参数化查询：使用占位符 ? 杜绝 SQL 注入
    if (keyword.empty()) {
        sql = "SELECT id, isbn, title, author, publisher, publish_year, category, "
              "total_copies, available_copies FROM books ORDER BY id ASC";
        
        dbClient->execSqlAsync(
            sql,
            [successCb](const drogon::orm::Result &result) {
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
                if (successCb) {
                    successCb(books);
                }
            },
            [errorCb](const drogon::orm::DrogonDbException &e) {
                if (errorCb) {
                    errorCb(e.base().what());
                }
            }
        );
    } else {
        sql = "SELECT id, isbn, title, author, publisher, publish_year, category, "
              "total_copies, available_copies FROM books "
              "WHERE title LIKE ? OR author LIKE ? OR isbn LIKE ? ORDER BY id ASC";
        std::string pattern = "%" + keyword + "%";

        dbClient->execSqlAsync(
            sql,
            [successCb](const drogon::orm::Result &result) {
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
                if (successCb) {
                    successCb(books);
                }
            },
            [errorCb](const drogon::orm::DrogonDbException &e) {
                if (errorCb) {
                    errorCb(e.base().what());
                }
            },
            pattern, pattern, pattern // 绑定 3 个占位符
        );
    }
}

} // namespace repository