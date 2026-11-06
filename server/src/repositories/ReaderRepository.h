#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace repository {

// 对应 api/openapi.yaml 的 Reader（字段映射见 docs/repository-contract.md）。
// passwordHash 只在认证专用查询中填充；列表与详情查询一律不返回该字段。
struct Reader {
    int64_t id{0};
    std::string readerCardId;  // -> Reader.username
    std::string name;          // -> Reader.display_name
    std::string passwordHash;  // 仅 getReaderByCardIdForAuth 填充
    std::string email;
    std::string phone;         // 数据库内部字段，不暴露给 API
    std::string status{"active"}; // active -> is_active=true；suspended -> false
    std::string createdAt;     // UTC
};

class ReaderRepository {
public:
    using QueryCallback  = std::function<void(const std::vector<Reader>&, int64_t total)>;
    using SingleCallback = std::function<void(const Reader&, bool found)>;
    using ActionCallback = std::function<void(bool success, int64_t affectedRows)>;
    using ErrorCallback  = std::function<void(const std::string&)>;

    // 分页检索读者（按卡号或姓名模糊搜索）；page 从 1 开始，pageSize 限制 1-100。
    // 返回全部状态（含 suspended），由上层按 is_active 决定是否展示。
    void queryReaders(const std::string &keyword, int page, int pageSize,
                      const QueryCallback &successCb, const ErrorCallback &errorCb);

    // 按 ID 获取读者；不返回 password_hash。
    void getReaderById(int64_t id, const SingleCallback &successCb, const ErrorCallback &errorCb);

    // 认证专用：按卡号查询并返回 password_hash，供后端登录校验使用。
    // 禁止把该方法的结果直接序列化成 API 响应。
    void getReaderByCardIdForAuth(const std::string &cardId,
                                  const SingleCallback &successCb, const ErrorCallback &errorCb);

    // 新增读者；可空的 email/phone 以空串写入时落为 SQL NULL。
    void addReader(const Reader &reader, const std::function<void(int64_t newId)> &successCb,
                   const ErrorCallback &errorCb);

    // 更新读者资料；不修改 password_hash（改密码应由认证模块单独提供）。
    void updateReader(const Reader &reader, const ActionCallback &successCb,
                      const ErrorCallback &errorCb);

    // 软注销读者：status 置 suspended，不物理删除，借阅历史必须保留。
    void deleteReader(int64_t id, const ActionCallback &successCb, const ErrorCallback &errorCb);
};

} // namespace repository
