#include "BookService.h"
#include "ApiClient.h"
#include <QJsonArray>
#include <QJsonObject>
#include <cmath>

BookService::~BookService()
{
    cancelSearch();
}

void BookService::cancelSearch()
{
    if (active) {
        auto previous = active;
        active = nullptr;
        previous->abort();
    }
}

void BookService::search(const QString &keyword, int page, int pageSize)
{
    cancelSearch();
    message.clear();
    auto *reply = ApiClient::instance().send("GET", "/api/v1/books", {
        {"q", keyword.trimmed()},
        {"page", qMax(1, page)},
        {"page_size", qBound(1, pageSize, 100)}
    });
    busy = reply != nullptr;
    if (!reply) {
        message = tr("请求失败：服务地址无效");
        emit stateChanged();
        return;
    }

    active = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (active != reply) return;
        active = nullptr;
        busy = false;
        const auto response = ApiClient::readResponse(*reply);
        const auto root = response.json.object();
        if (!response.errorKind.isEmpty()) {
            message = response.message;
        } else if (response.status != 200 || !root.value("data").isArray() || !root.value("meta").isObject()) {
            message = tr("服务器响应格式错误：需要 data 数组和 meta 对象");
        } else {
            QVariantList books;
            const auto meta = root.value("meta").toObject();
            bool valid = true;
            for (const auto &key : {"page", "page_size", "total", "total_pages"}) {
                const auto v = meta.value(key);
                const double n = v.toDouble(-1);
                valid = valid && v.isDouble() && n >= 0 && std::floor(n) == n;
            }
            valid = valid && meta.value("page").toInt() >= 1
                    && meta.value("page_size").toInt() >= 1 && meta.value("page_size").toInt() <= 100;
            for (const auto &value : root.value("data").toArray()) {
                auto book = value.toObject();
                if (!value.isObject() || !book.value("title").isString()
                    || !book.value("author").isString()
                    || !(book.value("isbn").isString() || book.value("isbn").isNull())) {
                    valid = false;
                    break;
                }
                auto row = book.toVariantMap();
                row.insert("bookTitle", book.value("title").toString());
                row.insert("isbn", book.value("isbn").toString());
                books.append(row);
            }
            if (valid) emit booksReceived(books, meta.toVariantMap());
            else message = tr("服务器图书或分页字段格式错误");
        }
        emit stateChanged();
    });
    emit stateChanged();
}
