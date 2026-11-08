#pragma once

#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QVariantMap>

class QNetworkReply;

class ApiClient : public QObject {
    Q_OBJECT
public:
    struct Response {
        int status = 0;
        QJsonDocument json;
        QString errorKind;
        QString code;
        QString message;

        QVariantMap toVariantMap() const;
    };

    static ApiClient &instance();

    Q_INVOKABLE bool setAccessToken(const QString &token);
    Q_INVOKABLE void clearAccessToken();
    Q_INVOKABLE QString request(const QString &method, const QString &path,
                                const QVariantMap &query = {}, const QVariant &body = {},
                                bool requiresAuth = false);

    // The reply is deleted automatically after finished(). Read it in that signal's handler.
    QNetworkReply *send(const QByteArray &method, const QString &path, const QVariantMap &query,
                        const QJsonDocument &body = {}, bool requiresAuth = false);
    static Response readResponse(QNetworkReply &reply);

signals:
    void requestFinished(const QString &id, const QVariantMap &result);

private:
    explicit ApiClient(QObject *parent) : QObject(parent) {}

    QNetworkAccessManager manager;
    QByteArray accessToken;
};
