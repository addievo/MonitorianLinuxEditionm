#include "monitor.h"

// Default constructor for QML
Monitor::Monitor(QObject *parent)
    : QObject(parent)
    , m_id("0")
    , m_name("Unknown Monitor")
    , m_manufacturer("")
    , m_brightness(50)
    , m_maxBrightness(100)
    , m_controllable(false)
{
}

Monitor::Monitor(const QString& id, const QString& name, const QString& manufacturer,
                int brightness, int maxBrightness, QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_name(name)
    , m_manufacturer(manufacturer)
    , m_brightness(brightness)
    , m_maxBrightness(maxBrightness)
    , m_controllable(maxBrightness > 0 && brightness >= 0)
{
}
QString Monitor::id() const
{
    return m_id;
}

QString Monitor::displayName() const
{
    QString displayName;

    // If we have a manufacturer, include it
    if (!m_manufacturer.isEmpty())
        displayName = m_manufacturer + " ";

    // Use model name if available, otherwise a generic name
    if (!m_name.isEmpty())
        displayName += m_name;
    else
        displayName += "Display " + m_id;

    return displayName;
}

int Monitor::brightness() const
{
    return m_brightness;
}

bool Monitor::isControllable() const
{
    return m_controllable;
}

void Monitor::setBrightness(int brightness)
{
    if (m_brightness != brightness && m_controllable) {
        m_brightness = brightness;
        emit brightnessChanged(m_brightness);
    }
}

void Monitor::refresh()
{
    // This will be implemented by the MonitorManager
    // when it refreshes the monitor's brightness value
}
