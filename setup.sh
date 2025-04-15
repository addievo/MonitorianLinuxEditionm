#!/bin/bash

# Create directory structure
mkdir -p src qml resources/icons

# Copy source files to their correct locations
# Main files
echo "Creating C++ source files..."
cat > src/main.cpp << 'EOF'
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "monitormanager.h"
#include "monitor.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName("Monitor Brightness Control");
    app.setOrganizationName("MonitorControl");

    // Initialize monitor manager
    MonitorManager monitorManager;

    // Set up QML engine
    QQmlApplicationEngine engine;

    // Register custom types
    qmlRegisterType<Monitor>("MonitorControl", 1, 0, "Monitor");

    // Expose monitor manager to QML
    engine.rootContext()->setContextProperty("monitorManager", &monitorManager);

    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
EOF

# Create monitor.h
cat > src/monitor.h << 'EOF'
#ifndef MONITOR_H
#define MONITOR_H

#include <QObject>
#include <QString>

class Monitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString displayName READ displayName CONSTANT)
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool controllable READ isControllable CONSTANT)

public:
    explicit Monitor(const QString& id, const QString& name, const QString& manufacturer,
                    int brightness, int maxBrightness, QObject *parent = nullptr);

    QString id() const;
    QString displayName() const;
    int brightness() const;
    bool isControllable() const;

public slots:
    void setBrightness(int brightness);
    void refresh();

signals:
    void brightnessChanged(int brightness);
    void brightnessUpdateFailed();

private:
    QString m_id;
    QString m_name;
    QString m_manufacturer;
    int m_brightness;
    int m_maxBrightness;
    bool m_controllable;
};

#endif // MONITOR_H
EOF

# Create monitor.cpp
cat > src/monitor.cpp << 'EOF'
#include "monitor.h"

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
EOF

# Create ddcutilinterface.h
cat > src/ddcutilinterface.h << 'EOF'
#ifndef DDCUTILINTERFACE_H
#define DDCUTILINTERFACE_H

#include <QObject>
#include <QProcess>
#include <QMap>
#include <QString>
#include <QStringList>

class DDCUtilInterface : public QObject
{
    Q_OBJECT

public:
    explicit DDCUtilInterface(QObject *parent = nullptr);
    ~DDCUtilInterface();

    struct MonitorInfo {
        QString id;
        QString name;
        QString manufacturer;
        int currentBrightness;
        int maxBrightness;
    };

    bool isAvailable() const;
    QList<MonitorInfo> detectMonitors();
    bool setBrightness(const QString& monitorId, int brightness);
    int getBrightness(const QString& monitorId);

private:
    bool checkDDCUtilInstalled();
    QString executeCommand(const QString& command, const QStringList& arguments);
    QMap<QString, MonitorInfo> parseDetectOutput(const QString& output);

    bool m_isAvailable;
};

#endif // DDCUTILINTERFACE_H
EOF

# Create ddcutilinterface.cpp
cat > src/ddcutilinterface.cpp << 'EOF'
#include "ddcutilinterface.h"
#include <QDebug>
#include <QRegularExpression>

DDCUtilInterface::DDCUtilInterface(QObject *parent)
    : QObject(parent)
    , m_isAvailable(false)
{
    m_isAvailable = checkDDCUtilInstalled();
}

DDCUtilInterface::~DDCUtilInterface()
{
}

bool DDCUtilInterface::isAvailable() const
{
    return m_isAvailable;
}

bool DDCUtilInterface::checkDDCUtilInstalled()
{
    QProcess process;
    process.start("which", QStringList() << "ddcutil");
    process.waitForFinished();

    if (process.exitCode() != 0) {
        qWarning() << "ddcutil is not installed on this system";
        return false;
    }

    // Also check if the user has the necessary permissions
    process.start("ddcutil", QStringList() << "capabilities");
    process.waitForFinished();

    if (process.exitCode() != 0) {
        QString error = process.readAllStandardError();
        if (error.contains("permission denied") || error.contains("requires root privileges")) {
            qWarning() << "ddcutil permission issues. Make sure you have proper access to I2C devices";
            return false;
        }
    }

    return true;
}

QString DDCUtilInterface::executeCommand(const QString& command, const QStringList& arguments)
{
    QProcess process;
    process.start(command, arguments);
    process.waitForFinished(10000); // 10 second timeout

    if (process.exitCode() != 0) {
        qWarning() << "Command execution failed:" << command << arguments;
        qWarning() << "Error:" << process.readAllStandardError();
        return QString();
    }

    return process.readAllStandardOutput();
}

QList<DDCUtilInterface::MonitorInfo> DDCUtilInterface::detectMonitors()
{
    if (!m_isAvailable) {
        return QList<MonitorInfo>();
    }

    QString output = executeCommand("ddcutil", QStringList() << "detect" << "--brief");
    if (output.isEmpty()) {
        return QList<MonitorInfo>();
    }

    QMap<QString, MonitorInfo> monitors = parseDetectOutput(output);

    // Get current brightness values for each monitor
    for (auto it = monitors.begin(); it != monitors.end(); ++it) {
        it.value().currentBrightness = getBrightness(it.key());
    }

    return monitors.values();
}

QMap<QString, DDCUtilInterface::MonitorInfo> DDCUtilInterface::parseDetectOutput(const QString& output)
{
    QMap<QString, MonitorInfo> monitors;
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);

    MonitorInfo currentMonitor;

    for (const QString& line : lines) {
        // New display found
        if (line.contains("Display", Qt::CaseInsensitive) && line.contains("/dev/i2c-")) {
            if (!currentMonitor.id.isEmpty()) {
                monitors[currentMonitor.id] = currentMonitor;
            }

            currentMonitor = MonitorInfo();

            // Extract display number/id
            QRegularExpression reDisplay("/dev/i2c-(\\d+)");
            QRegularExpressionMatch match = reDisplay.match(line);
            if (match.hasMatch()) {
                currentMonitor.id = match.captured(1);
            }
            currentMonitor.maxBrightness = 100; // Default max brightness
        }

        // Monitor model info
        else if (line.contains("Monitor:", Qt::CaseInsensitive) || line.contains("Model:", Qt::CaseInsensitive)) {
            QRegularExpression reName("(?:Monitor|Model):\\s+(.+)");
            QRegularExpressionMatch match = reName.match(line);
            if (match.hasMatch()) {
                currentMonitor.name = match.captured(1).trimmed();
            }
        }

        // Manufacturer info
        else if (line.contains("Mfg id:", Qt::CaseInsensitive)) {
            QRegularExpression reManufacturer("Mfg id:\\s+(.+)");
            QRegularExpressionMatch match = reManufacturer.match(line);
            if (match.hasMatch()) {
                currentMonitor.manufacturer = match.captured(1).trimmed();
            }
        }
    }

    // Add the last monitor if we have one
    if (!currentMonitor.id.isEmpty()) {
        monitors[currentMonitor.id] = currentMonitor;
    }

    return monitors;
}

bool DDCUtilInterface::setBrightness(const QString& monitorId, int brightness)
{
    if (!m_isAvailable) {
        return false;
    }

    // Clamp brightness to 0-100
    brightness = qBound(0, brightness, 100);

    QString output = executeCommand("ddcutil", QStringList()
                                   << "--bus" << monitorId
                                   << "setvcp" << "10" << QString::number(brightness));

    return !output.isEmpty();
}

int DDCUtilInterface::getBrightness(const QString& monitorId)
{
    if (!m_isAvailable) {
        return -1;
    }

    QString output = executeCommand("ddcutil", QStringList()
                                   << "--bus" << monitorId
                                   << "getvcp" << "10");

    if (output.isEmpty()) {
        return -1;
    }

    // Parse current brightness value
    // Expected format: "VCP 10 (Brightness): current value = 75, max value = 100"
    QRegularExpression reBrightness("current value\\s*=\\s*(\\d+)");
    QRegularExpressionMatch match = reBrightness.match(output);

    if (match.hasMatch()) {
        return match.captured(1).toInt();
    }

    return -1;
}
EOF

# Create monitormanager.h
cat > src/monitormanager.h << 'EOF'
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
EOF

# Create monitormanager.cpp
cat > src/monitormanager.cpp << 'EOF'
#include "monitormanager.h"
#include <QDebug>

MonitorManager::MonitorManager(QObject *parent)
    : QObject(parent)
    , m_ddcUtilInterface(new DDCUtilInterface(this))
    , m_refreshTimer(new QTimer(this))
{
    // Set up refresh timer to periodically check monitor states
    m_refreshTimer->setInterval(5000); // 5 seconds
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

        // Refresh the monitor to get actual value
        refreshMonitors();
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
EOF

# Create QML files
echo "Creating QML files..."

# Create main.qml
cat > qml/main.qml << 'EOF'
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: mainWindow
    visible: true
    width: 320
    height: Math.min(80 * monitorManager.monitors.length + 40, 480)
    title: "Monitor Brightness Control"
    color: "#1f1f1f"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Allow dragging the window
    MouseArea {
        anchors.fill: parent
        property point clickPos: "0,0"
        onPressed: {
            clickPos = Qt.point(mouse.x, mouse.y)
        }
        onPositionChanged: {
            var delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y)
            mainWindow.x += delta.x
            mainWindow.y += delta.y
        }
    }

    // Close button in the top right
    Rectangle {
        id: closeButton
        width: 20
        height: 20
        color: closeMouseArea.containsMouse ? "#ff5555" : "transparent"
        radius: 10
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
        }

        MouseArea {
            id: closeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Qt.quit()
        }
    }

    // Main content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 0

        // Title
        Text {
            Layout.fillWidth: true
            text: "Monitor Brightness Control"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            Layout.bottomMargin: 10
        }

        // Monitor list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                // No monitors message
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    visible: monitorManager.monitors.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: monitorManager.ddcUtilAvailable ?
                              "No compatible monitors found" :
                              "ddcutil not available. Please install it."
                        color: "#cccccc"
                        font.pixelSize: 14
                    }
                }

                // Monitor sliders
                Repeater {
                    model: monitorManager.monitors

                    MonitorSlider {
                        Layout.fillWidth: true
                        monitorName: modelData.displayName
                        brightnessValue: modelData.brightness
                        isControllable: modelData.controllable

                        onBrightnessChanged: {
                            modelData.brightness = value
                        }
                    }
                }
            }
        }

        // Refresh button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: refreshMouseArea.containsMouse ? "#2a2a2a" : "#262626"
            radius: 4

            Text {
                anchors.centerIn: parent
                text: "Refresh Monitors"
                color: "#ffffff"
                font.pixelSize: 14
            }

            MouseArea {
                id: refreshMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: monitorManager.detectMonitors()
            }
        }
    }

    // Status message
    Rectangle {
        id: statusMessage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 30
        width: statusText.width + 20
        color: "#3a3a3a"
        radius: 4
        opacity: 0

        Text {
            id: statusText
            anchors.centerIn: parent
            color: "#ffffff"
            font.pixelSize: 13
        }

        // Animation for showing/hiding
        NumberAnimation on opacity {
            id: showAnimation
            from: 0
            to: 1
            duration: 200
            running: false
        }

        NumberAnimation on opacity {
            id: hideAnimation
            from: 1
            to: 0
            duration: 200
            running: false
        }
    }

    // Handle error messages
    Connections {
        target: monitorManager

        function onMonitorOperationFailed(message) {
            statusText.text = message
            showAnimation.start()
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: hideAnimation.start()
    }
}
EOF

# Create MonitorSlider.qml
cat > qml/MonitorSlider.qml << 'EOF'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: parent.width
    height: 80
    color: "transparent"

    property string monitorName: "Unknown Monitor"
    property int brightnessValue: 50
    property bool isControllable: true

    signal brightnessChanged(int value)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        // Monitor name
        Text {
            Layout.fillWidth: true
            text: monitorName
            color: "#ffffff"
            font.pixelSize: 16
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Brightness slider
            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: brightnessValue
                enabled: isControllable

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: brightnessSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#3a3a3a"

                    Rectangle {
                        width: brightnessSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#2982cc"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: 20
                    height: 20
                    radius: 10
                    color: brightnessSlider.pressed ? "#1c86ee" : "#5ca4de"
                    border.color: "#2982cc"
                    border.width: 1
                }

                onMoved: {
                    root.brightnessChanged(value)
                }
            }

            // Brightness value
            Text {
                text: Math.round(brightnessValue)
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
                Layout.minimumWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
EOF

# Create CMakeLists.txt
echo "Creating CMakeLists.txt..."
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.14)
project(monitor-control LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Quick)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Quick)

# Source files
set(PROJECT_SOURCES
    src/main.cpp
    src/monitor.h
    src/monitor.cpp
    src/monitormanager.h
    src/monitormanager.cpp
    src/ddcutilinterface.h
    src/ddcutilinterface.cpp
)

# Create QRC file
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/resources.qrc
"<RCC>
    <qresource prefix=\"/\">
        <file>qml/main.qml</file>
        <file>qml/MonitorSlider.qml</file>
    </qresource>
</RCC>")

# Add resources
set(RESOURCE_FILES ${CMAKE_CURRENT_BINARY_DIR}/resources.qrc)
qt5_add_resources(RESOURCES ${RESOURCE_FILES})

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(monitor-control
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
        ${RESOURCES}
    )
else()
    add_executable(monitor-control
        ${PROJECT_SOURCES}
        ${RESOURCES}
    )
endif()

target_link_libraries(monitor-control
  PRIVATE Qt${QT_VERSION_MAJOR}::Core Qt${QT_VERSION_MAJOR}::Quick)

# Finalization step for Qt 6
if(QT_VERSION_MAJOR EQUAL 6)
    qt_finalize_executable(monitor-control)
endif()
EOF

echo "Setup completed successfully!"
echo "To build the project, run:"
echo "mkdir -p build"
echo "cd build"
echo "cmake .."
echo "make"
EOF