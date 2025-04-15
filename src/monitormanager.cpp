#include "monitormanager.h"
#include <QDebug>

MonitorManager::MonitorManager(QObject *parent)
    : QObject(parent)
    , m_ddcUtilInterface(new DDCUtilInterface(this))
    , m_refreshTimer(new QTimer(this))
{
    // Increase refresh timer interval to 30 seconds (was 5 seconds)
    m_refreshTimer->setInterval(30000);
    connect(m_refreshTimer, &QTimer::timeout, this, &MonitorManager::onRefreshTimerTimeout);
    m_refreshTimer->start();

    // Initial detection
    detectMonitors();
}

MonitorManager::~MonitorManager()
{
    clearMonitors();
}

QQmlListProperty<Monitor> MonitorManager::monitors()
{
    return QQmlListProperty<Monitor>(this, &m_monitors);
}

QList<Monitor*> MonitorManager::monitorsList() const
{
    return m_monitors;
}

bool MonitorManager::isDDCUtilAvailable() const
{
    return m_ddcUtilInterface->isAvailable();
}

void MonitorManager::detectMonitors()
{
    if (!m_ddcUtilInterface->isAvailable()) {
        emit monitorOperationFailed("ddcutil is not available. Please install it and ensure you have proper permissions.");
        return;
    }

    // Get monitors from ddcutil
    QList<DDCUtilInterface::MonitorInfo> detectedMonitors = m_ddcUtilInterface->detectMonitors();

    // Clear existing monitors
    clearMonitors();

    // Create monitor objects
    for (const auto& info : detectedMonitors) {
        Monitor* monitor = new Monitor(
            info.id,
            info.name,
            info.manufacturer,
            info.currentBrightness,
            info.maxBrightness,
            this
        );

        // Connect signals
        connect(monitor, &Monitor::brightnessChanged, this, [this, monitor](int brightness) {
            setBrightness(monitor->id(), brightness);
        });

        m_monitors.append(monitor);
    }

    emit monitorsChanged();
}

void MonitorManager::setBrightness(const QString& monitorId, int brightness)
{
    bool success = m_ddcUtilInterface->setBrightness(monitorId, brightness);

    if (!success) {
        emit monitorOperationFailed("Failed to set brightness for monitor " + monitorId);

        // Only refresh the specific monitor that failed
        for (Monitor* monitor : m_monitors) {
            if (monitor->id() == monitorId) {
                int currentBrightness = m_ddcUtilInterface->getBrightness(monitorId);
                if (currentBrightness >= 0) {
                    disconnect(monitor, &Monitor::brightnessChanged, nullptr, nullptr);
                    monitor->setBrightness(currentBrightness);
                    connect(monitor, &Monitor::brightnessChanged, this, [this, monitor](int brightness) {
                        setBrightness(monitor->id(), brightness);
                    });
                }
                break;
            }
        }
    }
}

void MonitorManager::refreshMonitors()
{
    if (!m_ddcUtilInterface->isAvailable() || m_monitors.isEmpty()) {
        return;
    }

    for (Monitor* monitor : m_monitors) {
        int brightness = m_ddcUtilInterface->getBrightness(monitor->id());
        if (brightness >= 0) {
            // Temporarily disconnect brightness changed signal to avoid loop
            disconnect(monitor, &Monitor::brightnessChanged, nullptr, nullptr);
            monitor->setBrightness(brightness);

            // Reconnect signal
            connect(monitor, &Monitor::brightnessChanged, this, [this, monitor](int brightness) {
                setBrightness(monitor->id(), brightness);
            });
        }
    }
}

void MonitorManager::onRefreshTimerTimeout()
{
    refreshMonitors();
}

void MonitorManager::clearMonitors()
{
    qDeleteAll(m_monitors);
    m_monitors.clear();
}
