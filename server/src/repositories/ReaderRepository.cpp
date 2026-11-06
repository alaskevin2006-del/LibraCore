#include "ReaderRepository.h"

#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Result.h>
#include <drogon/orm/Exception.h>

namespace repository {
namespace {

// 列表/详情查询列：不含 password_hash。
const char *kReaderPublicColumns =
    "SELECT id, reader_card_id, name, email, phone, status, created_at FROM readers ";

const auto makeReaderFromRow = [](const auto &row, bool withHash) -> Reader {
    Reader r;
    r.id           = row["id"].as<int64_t>();
    r.readerCardId = row["reader_card_id"].as<std::string>();
    r.name         = row["name"].as<std::string>();
    r.passwordHash = withHash ? (row["password_hash"].isNull() ? ""
                                                               : row["password_hash"].as<std::string>())
                              : std::string{};
    r.email        = row["email"].isNull()    ? "" : row["email"].as<std::string>();
    r.phone        = row["phone"].isNull()    ? "" : row["phone"].as<std::string>();
    r.status       = row["status"].as<std::string>();
    r.createdAt    = row["created_at"].isNull() ? "" : row["created_at"].as<std::string>();
    return r;
};

} // namespace

void ReaderRepository::queryReaders(const std::string &keyword, int page, int pageSize,
                                    const QueryCallback &successCb, const ErrorCallback &errorCb) {
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
    const std::string where = hasKeyword
        ? "WHERE reader_card_id LIKE ? OR name LIKE ? "
        : std::string{};

    const std::string countSql = "SELECT COUNT(*) AS total FROM readers " + where;
    const std::string dataSql = std::string(kReaderPublicColumns) + where
                              + "ORDER BY id DESC LIMIT ? OFFSET ?";

    auto executeQuery = [=](int64_t total) {
        auto rowHandler = [successCb, total](const drogon::orm::Result &result) {
            std::vector<Reader> readers;
            readers.reserve(result.size());
            for (const auto &row : result) readers.push_back(makeReaderFromRow(row, false));
            if (successCb) successCb(readers, total);
        };
        auto onError = [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        };
        if (hasKeyword) {
            dbClient->execSqlAsync(dataSql, rowHandler, onError, pattern, pattern, pageSize, offset);
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
        dbClient->execSqlAsync(countSql, countHandler, onCountError, pattern, pattern);
    } else {
        dbClient->execSqlAsync(countSql, countHandler, onCountError);
    }
}

void ReaderRepository::getReaderById(int64_t id, const SingleCallback &successCb,
                                     const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql = std::string(kReaderPublicColumns) + "WHERE id = ?";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (result.empty()) {
                if (successCb) successCb(Reader{}, false);
                return;
            }
            if (successCb) successCb(makeReaderFromRow(result[0], false), true);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id);
}

void ReaderRepository::getReaderByCardIdForAuth(const std::string &cardId,
                                                const SingleCallback &successCb,
                                                const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql =
        "SELECT id, reader_card_id, name, password_hash, email, phone, status, created_at "
        "FROM readers WHERE reader_card_id = ?";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (result.empty()) {
                if (successCb) successCb(Reader{}, false);
                return;
            }
            if (successCb) successCb(makeReaderFromRow(result[0], true), true);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        cardId);
}

void ReaderRepository::addReader(const Reader &reader,
                                 const std::function<void(int64_t newId)> &successCb,
                                 const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql =
        "INSERT INTO readers (reader_card_id, name, password_hash, email, phone, status) "
        "VALUES (?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), 'active')";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(static_cast<int64_t>(result.insertId()));
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        reader.readerCardId, reader.name, reader.passwordHash, reader.email, reader.phone);
}

void ReaderRepository::updateReader(const Reader &reader, const ActionCallback &successCb,
                                    const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    // 不修改 password_hash；status 变更由上层按权限控制（ReaderPatch.is_active）。
    const std::string sql =
        "UPDATE readers SET reader_card_id = ?, name = ?, "
        "email = NULLIF(?, ''), phone = NULLIF(?, '') WHERE id = ?";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            if (successCb) successCb(true, static_cast<int64_t>(result.affectedRows()));
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        reader.readerCardId, reader.name, reader.email, reader.phone, reader.id);
}

void ReaderRepository::deleteReader(int64_t id, const ActionCallback &successCb,
                                    const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    // 软注销：物理 DELETE 会因借阅记录外键失败，且会丢失借阅历史（原实现为 ON DELETE CASCADE）。
    const std::string sql =
        "UPDATE readers SET status = 'suspended' WHERE id = ? AND status = 'active'";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            const int64_t affected = static_cast<int64_t>(result.affectedRows());
            if (successCb) successCb(affected > 0, affected);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        id);
}

} // namespace repository
