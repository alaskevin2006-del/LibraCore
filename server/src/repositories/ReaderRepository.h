#pragma once

#include <string>
#include <vector>
#include <functional>
#include <cstdint>
#include <memory>
#include <drogon/drogon.h>

namespace repository {

struct Reader {
    int64_t id{0};
    std::string readerCardId;
    std::string name;
    std::string passwordHash;
    std::string email;
    std::string phone;
    std::string status{"active"};
    std::string createdAt;
};

class ReaderRepository {
public:
    using QueryCallback = std::function<void(const std::vector<Reader>&, int64_t total)>;
    using SingleCallback = std::function<void(const Reader&, bool found)>;
    using ActionCallback = std::function<void(bool success, int64_t affectedRows)>;
    using ErrorCallback = std::function<void(const std::string&)>;

    // 分页检索读者（按卡号或姓名模糊搜索）
    void queryReaders(const std::string &keyword, int page, int pageSize,
                      const QueryCallback &successCb, const ErrorCallback &errorCb);

    // 根据 ID 获取读者
    void getReaderById(int64_t id, const SingleCallback &successCb, const ErrorCallback &errorCb);

    // 新增读者
    void addReader(const Reader &reader, const std::function<void(int64_t newId)> &successCb, const ErrorCallback &errorCb);

    // 更新读者信息
    void updateReader(const Reader &reader, const ActionCallback &successCb, const ErrorCallback &errorCb);

    // 删除读者
    void deleteReader(int64_t id, const ActionCallback &successCb, const ErrorCallback &errorCb);
};

} // namespace repositorys