#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QNetworkReply>
#include <QVariantList>

// One instance per consumer; starting a query supersedes its previous request.
class BookService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
public:
    explicit BookService(QObject *parent = nullptr) : QObject(parent), manager(this) {}
    bool loading() const { return busy; }
    QString error() const { return message; }
    Q_INVOKABLE void search(const QString &keyword, int page = 1, int pageSize = 20);
signals:
    void stateChanged();
    void booksReceived(const QVariantList &books, const QVariantMap &meta);
private:
    QNetworkAccessManager manager;
    QPointer<QNetworkReply> active;
    bool busy = false;
    QString message;
};
