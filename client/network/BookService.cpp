#include "BookService.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrlQuery>
#include <cmath>

void BookService::search(const QString &keyword, int page, int pageSize)
{
    if (active) {
        auto previous = active;
        active = nullptr;
        previous->abort();
    }
    busy = true;
    message.clear();
    emit stateChanged();
    QUrl url(qEnvironmentVariable("LIBRACORE_API_URL", "http://localhost:8080"));
    url.setPath("/api/v1/books");
    QUrlQuery query;
    query.addQueryItem("q", keyword.trimmed());
    query.addQueryItem("page", QString::number(qMax(1, page)));
    query.addQueryItem("page_size", QString::number(qBound(1, pageSize, 100)));
    url.setQuery(query);
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json, application/problem+json");
    request.setTransferTimeout(15000);
    auto reply = manager.get(request);
    active = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (active != reply) return;
        active = nullptr;
        busy = false;
        QJsonParseError parseError;
        const auto doc = QJsonDocument::fromJson(reply->readAll(), &parseError);
        const auto root = doc.object();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || status != 200) {
            const QString code = root.value("code").toString();
            message = code.isEmpty() ? tr("请求失败：%1").arg(reply->errorString())
                                     : tr("请求失败（HTTP %1，%2）").arg(status).arg(code);
        } else if (parseError.error != QJsonParseError::NoError || !root.value("data").isArray()
                   || !root.value("meta").isObject()) {
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
}
