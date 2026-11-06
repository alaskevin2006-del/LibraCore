#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace repository {

// 对应 api/openapi.yaml 的 Loan，字段来自 v_loan_history / v_active_loans / v_overdue_loans。
// 借还对象永远是具体副本 copy_id；is_overdue 由 (status='active' AND due_at < NOW()) 推导。
struct Loan {
    int64_t id{0};
    int64_t copyId{0};
    int64_t bookId{0};
    int64_t readerId{0};
    std::string title;
    std::string author;
    std::string readerName;
    std::string status{"active"}; // active | returned
    std::string borrowedAt;       // UTC
    std::string dueAt;            // UTC
    std::string returnedAt;       // active 时为空串
    bool isOverdue{false};
};

class LoanRepository {
public:
    using LoansCallback  = std::function<void(const std::vector<Loan>&)>;
    using IdCallback     = std::function<void(int64_t loanId)>;
    using ActionCallback = std::function<void(bool success)>;
    using ErrorCallback  = std::function<void(const std::string&)>;

    // 借书：调用 sp_borrow_book，事务由存储过程保证；成功回调返回新借阅记录 ID。
    // loanDays 由 Service 层按团队确认的借期规则传入（NULL/<1 时过程内默认 30 天）。
    // 失败原因见 errorCb：COPY_UNAVAILABLE / COPY_NOT_FOUND / READER_NOT_FOUND /
    // READER_SUSPENDED，Controller 据此映射 409 / 404 / 403。
    void borrowBook(int64_t copyId, int64_t readerId, int loanDays,
                    const IdCallback &successCb, const ErrorCallback &errorCb);

    // 还书：调用 sp_return_book；重复还或记录不存在时走 errorCb。
    void returnBook(int64_t loanId, const ActionCallback &successCb,
                    const ErrorCallback &errorCb);

    // 当前借阅（对应「我的借阅」页面）
    void queryActiveLoansByReader(int64_t readerId, const LoansCallback &successCb,
                                  const ErrorCallback &errorCb);

    // 借阅历史（含已归还）
    void queryLoanHistoryByReader(int64_t readerId, const LoansCallback &successCb,
                                  const ErrorCallback &errorCb);

    // 逾期借阅（M3 / 后续超期提醒复用）
    void queryOverdueLoans(const LoansCallback &successCb, const ErrorCallback &errorCb);
};

} // namespace repository
