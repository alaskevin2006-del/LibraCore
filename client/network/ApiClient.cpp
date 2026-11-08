#include "ApiClient.h"

#include <QCoreApplication>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QUuid>

ApiClient &ApiClient::instance()
{
    static auto *client = new ApiClient(QCoreApplication::instance());
    return *client;
}

bool ApiClient::setAccessToken(const QString &token)
{
    static const QRegularExpression bearerToken(QStringLiteral("\\A[A-Za-z0-9._~+/-]+=*\\z"));
    if (!bearerToken.match(token).hasMatch())
        return false;
    accessToken = token.toLatin1();
    return true;
}

void ApiClient::clearAccessToken()
{
    accessToken.clear();
}

QNetworkReply *ApiClient::send(const QByteArray &method, const QString &path,
                               const QVariantMap &query, const QJsonDocument &body,
                               bool requiresAuth)
{
    QUrl url(qEnvironmentVariable("LIBRACORE_API_URL", "http://localhost:8080"), QUrl::StrictMode);
    if (!url.isValid() || (url.scheme() != "http" && url.scheme() != "https")
        || url.host().isEmpty() || !url.userInfo().isEmpty()
        || !path.startsWith('/') || path.startsWith("//") || path.contains('?') || path.contains('#'))
        return nullptr;

    url.setPath(path);
    url.setFragment({});
    QByteArray encodedQuery;
    for (auto it = query.cbegin(); it != query.cend(); ++it) {
        if (!encodedQuery.isEmpty())
            encodedQuery += '&';
        encodedQuery += QUrl::toPercentEncoding(it.key()) + '='
                        + QUrl::toPercentEncoding(it.value().toString());
    }
    url.setQuery(QString::fromLatin1(encodedQuery), QUrl::StrictMode);

    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json, application/problem+json");
    request.setTransferTimeout(15000);
    request.setAttribute(QNetworkRequest::AutoDeleteReplyOnFinishAttribute, true);
    if (requiresAuth || method != "GET")
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    if (requiresAuth && !accessToken.isEmpty())
        request.setRawHeader("Authorization", "Bearer " + accessToken);

    const QByteArray payload = body.isNull() ? QByteArray() : body.toJson(QJsonDocument::Compact);
    if (!payload.isEmpty())
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    if (method == "GET" && body.isNull())
        return manager.get(request);
    if (method == "POST")
        return manager.post(request, payload);
    if (method == "PUT")
        return manager.put(request, payload);
    if (method == "PATCH")
        return manager.sendCustomRequest(request, method, payload);
    if (method == "DELETE" && body.isNull())
        return manager.deleteResource(request);
    return nullptr;
}

ApiClient::Response ApiClient::readResponse(QNetworkReply &reply)
{
    Response response;
    response.status = reply.attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const auto bytes = reply.isOpen() ? reply.readAll() : QByteArray();
    QJsonParseError parseError;
    if (!bytes.isEmpty())
        response.json = QJsonDocument::fromJson(bytes, &parseError);

    if (response.status >= 300) {
        response.errorKind = "http";
        response.code = response.json.object().value("code").toString();
        response.message = response.code.isEmpty()
            ? tr("请求失败（HTTP %1）").arg(response.status)
            : tr("请求失败（HTTP %1，%2）").arg(response.status).arg(response.code);
    } else if (reply.error() != QNetworkReply::NoError || response.status < 200) {
        response.errorKind = "network";
        response.message = tr("请求失败：%1").arg(reply.errorString());
    } else if ((response.status != 204 && response.status != 205 && response.json.isNull())
               || parseError.error != QJsonParseError::NoError) {
        response.errorKind = "json";
        response.message = tr("服务器响应格式错误：需要有效的 JSON");
    }
    return response;
}

QVariantMap ApiClient::Response::toVariantMap() const
{
    return {
        {"ok", errorKind.isEmpty()},
        {"status", status},
        {"body", json.toVariant()},
        {"errorKind", errorKind},
        {"code", code},
        {"message", message}
    };
}

QString ApiClient::request(const QString &method, const QString &path, const QVariantMap &query,
                            const QVariant &body, bool requiresAuth)
{
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QJsonDocument json = QJsonDocument::fromVariant(body);
    auto *reply = !body.isNull() && json.isNull()
        ? nullptr
        : send(method.toLatin1(), path, query, json, requiresAuth);
    if (reply) {
        connect(reply, &QNetworkReply::finished, this, [this, id, reply] {
            emit requestFinished(id, readResponse(*reply).toVariantMap());
        });
    } else {
        QTimer::singleShot(0, this, [this, id] {
            Response response;
            response.errorKind = "request";
            response.message = tr("请求无效：请检查服务地址、接口路径、HTTP 方法和 JSON 请求体");
            emit requestFinished(id, response.toVariantMap());
        });
    }
    return id;
}
