#include "LoanRepository.h"

#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>
#include <drogon/orm/Result.h>
#include <drogon/orm/Exception.h>

namespace repository {
namespace {

const auto makeLoanFromRow = [](const auto &row) -> Loan {
    Loan l;
    l.id         = row["loan_id"].as<int64_t>();
    l.copyId     = row["copy_id"].as<int64_t>();
    l.bookId     = row["book_id"].as<int64_t>();
    l.title      = row["title"].as<std::string>();
    l.author     = row["author"].as<std::string>();
    l.readerId   = row["reader_id"].as<int64_t>();
    l.readerName = row["reader_name"].as<std::string>();
    l.status     = row["status"].as<std::string>();
    l.borrowedAt = row["borrowed_at"].isNull() ? "" : row["borrowed_at"].as<std::string>();
    l.dueAt      = row["due_at"].as<std::string>();
    l.returnedAt = row["returned_at"].isNull() ? "" : row["returned_at"].as<std::string>();
    l.isOverdue  = row["is_overdue"].as<int64_t>() != 0;
    return l;
};

const char *kLoanColumns =
    "SELECT loan_id, copy_id, book_id, title, author, reader_id, reader_name, "
    "status, borrowed_at, due_at, returned_at, is_overdue ";

} // namespace

void LoanRepository::borrowBook(int64_t copyId, int64_t readerId, int loanDays,
                                const IdCallback &successCb, const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    // 事务、行锁与错误码都在存储过程内，C++ 层不重复实现，避免半更新。
    const std::string sql = "CALL sp_borrow_book(?, ?, ?)";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            int64_t loanId = 0;
            if (!result.empty()) loanId = result[0]["loan_id"].as<int64_t>();
            if (successCb) successCb(loanId);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        copyId, readerId, loanDays);
}

void LoanRepository::returnBook(int64_t loanId, const ActionCallback &successCb,
                                const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql = "CALL sp_return_book(?)";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &) {
            if (successCb) successCb(true);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        loanId);
}

void LoanRepository::queryActiveLoansByReader(int64_t readerId,
                                              const LoansCallback &successCb,
                                              const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql = std::string(kLoanColumns) +
        "FROM v_active_loans WHERE reader_id = ? ORDER BY borrowed_at DESC";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            std::vector<Loan> loans;
            loans.reserve(result.size());
            for (const auto &row : result) loans.push_back(makeLoanFromRow(row));
            if (successCb) successCb(loans);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        readerId);
}

void LoanRepository::queryLoanHistoryByReader(int64_t readerId,
                                              const LoansCallback &successCb,
                                              const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql = std::string(kLoanColumns) +
        "FROM v_loan_history WHERE reader_id = ? ORDER BY borrowed_at DESC";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            std::vector<Loan> loans;
            loans.reserve(result.size());
            for (const auto &row : result) loans.push_back(makeLoanFromRow(row));
            if (successCb) successCb(loans);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        },
        readerId);
}

void LoanRepository::queryOverdueLoans(const LoansCallback &successCb,
                                       const ErrorCallback &errorCb) {
    auto dbClient = drogon::app().getDbClient();
    if (!dbClient) {
        if (errorCb) errorCb("Database client is not initialized.");
        return;
    }
    const std::string sql = std::string(kLoanColumns) +
        "FROM v_overdue_loans ORDER BY due_at ASC";
    dbClient->execSqlAsync(sql,
        [successCb](const drogon::orm::Result &result) {
            std::vector<Loan> loans;
            loans.reserve(result.size());
            for (const auto &row : result) loans.push_back(makeLoanFromRow(row));
            if (successCb) successCb(loans);
        },
        [errorCb](const drogon::orm::DrogonDbException &e) {
            if (errorCb) errorCb(e.base().what());
        });
}

} // namespace repository
