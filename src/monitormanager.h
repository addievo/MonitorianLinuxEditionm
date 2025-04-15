#ifndef MONITORMANAGER_H
#define MONITORMANAGER_H

#include <QObject>
#include <QList>
#include <QTimer>
#include <QQmlListProperty>

#include "monitor.h"
#include "ddcutilinterface.h"

class MonitorManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQmlListProperty<Monitor> monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(bool ddcUtilAvailable READ isDDCUtilAvailable NOTIFY ddcUtilAvailableChanged)

public:
    explicit MonitorManager(QObject *parent = nullptr);
    ~MonitorManager();

    QQmlListProperty<Monitor> monitors();
    QList<Monitor*> monitorsList() const;
    bool isDDCUtilAvailable() const;

public slots:
    void detectMonitors();
    void setBrightness(const QString& monitorId, int brightness);
    void refreshMonitors();

signals:
    void monitorsChanged();
    void ddcUtilAvailableChanged(bool available);
    void monitorOperationFailed(const QString& message);

private slots:
    void onRefreshTimerTimeout();

private:
    QList<Monitor*> m_monitors;
    DDCUtilInterface* m_ddcUtilInterface;
    QTimer* m_refreshTimer;

    void clearMonitors();
};

#endif // MONITORMANAGER_H
