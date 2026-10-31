#include "ReaderRepository.h"
#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Result.h>
#include <drogon/orm/Exception.h>

namespace repository {

void ReaderRepository::queryReaders(const std::string &keyword, int page, int pageSize,
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
        ? "SELECT COUNT(*) AS total FROM readers WHERE reader_card_id LIKE ? OR name LIKE ?"
        : "SELECT COUNT(*) AS total FROM readers";

    std::string dataSql = hasKeyword
        ? "SELECT id, reader_card_id, name, password_hash, email, phone, status, created_at "
          "FROM readers WHERE reader_card_id LIKE ? OR name LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?"
        : "SELECT id, reader_card_id, name, password_hash, email, phone, status, created_at "
          "FROM readers ORDER BY id DESC LIMIT ? OFFSET ?";

    std::string pattern = "%" + keyword + "%";

    auto executeQuery = [=](int64_t total) {
        auto rowHandler = [successCb, total](const drogon::orm::Result &result) {
            std::vector<Reader> readers;
            readers.reserve(result.size());
            for (const auto &row : result) {
                Reader r;
                r.id = row["id"].as<int64_t>();
                r.readerCardId = row["reader_card_id"].as<std::string>();
                r.name = row["name"].as<std::string>();
                r.passwordHash = row["password_hash"].as<std::string>();
                r.email = row["email"].isNull() ? "" : row["email"].as<std::string>();
                r.phone = row["phone"].isNull() ? "" : row["phone"].as<std::string>();
                r.status = row["status"].as<std::string>();
                r.createdAt = row["created_at"].as<std::string>();
                readers.push_back(std::move(r));
            }
            if (successCb) successCb(readers, total);
        };

        if (hasKeyword) {
            dbClient->execSqlAsync(dataSql, rowHandler,
                [errorCb](const drogon::orm::DrogonDbException &e) { if (errorCb) errorCb(e.base().what()); },
                pattern, pattern, pageSize, offset);
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
            pattern, pattern);
    } else {
        dbClient->execSqlAsync(countSql, countHandler,
            [errorCb](const drogon::orm::DrogonDbException &e) { if (errorCb) errorCb(e.base().what()); });
    }
}

void ReaderRepository::getReaderById(int64_t id, const SingleCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "SELECT id, reader_card_id, name, password_hash, email, phone, status, created_at "
                      "FROM readers WHERE id = ?";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (result.empty()) {
                if (successCb) successCb(Reader{}, false);
                return;
            }
            const auto &row = result[0];
            Reader r;
            r.id = row["id"].as<int64_t>();
            r.readerCardId = row["reader_card_id"].as<std::string>();
            r.name = row["name"].as<std::string>();
            r.passwordHash = row["password_hash"].as<std::string>();
            r.email = row["email"].isNull() ? "" : row["email"].as<std::string>();
            r.phone = row["phone"].isNull() ? "" : row["phone"].as<std::string>();
            r.status = row["status"].as<std::string>();
            r.createdAt = row["created_at"].as<std::string>();
            if (successCb) successCb(r, true);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id);
}

void ReaderRepository::addReader(const Reader &reader, const std::function<void(int64_t newId)> &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "INSERT INTO readers (reader_card_id, name, password_hash, email, phone, status) "
                      "VALUES (?, ?, ?, ?, ?, ?)";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(static_cast<int64_t>(result.insertId()));
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        reader.readerCardId, reader.name, reader.passwordHash,
        reader.email, reader.phone, reader.status);
}

void ReaderRepository::updateReader(const Reader &reader, const ActionCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "UPDATE readers SET reader_card_id = ?, name = ?, email = ?, phone = ?, status = ? WHERE id = ?";

    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(true, result.affectedRows());
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        reader.readerCardId, reader.name, reader.email, reader.phone, reader.status, reader.id);
}

void ReaderRepository::deleteReader(int64_t id, const ActionCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }

    std::string sql = "DELETE FROM readers WHERE id = ?";

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