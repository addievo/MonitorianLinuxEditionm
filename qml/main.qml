import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

Window {
    id: mainWindow
    visible: true
    width: 300
    height: Math.min(Math.max(200, 60 * monitorManager.monitors.length + 60), 400)
    title: "Monitor Brightness Control"
    color: "#1f1f1f"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Position window near system tray
    function showAtSystemTrayPosition() {
        var screenWidth = Screen.width
        var screenHeight = Screen.height
        mainWindow.x = screenWidth - mainWindow.width - 20
        mainWindow.y = screenHeight - mainWindow.height - 40
        mainWindow.show()
        mainWindow.raise()
        mainWindow.requestActivate()
    }

    // Show centered on screen initially
    Component.onCompleted: {
        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
    }

    // Linked monitors tracking
    property var linkedMonitors: []

    function toggleMonitorLink(monitorId, linked) {
        if (linked) {
            if (!linkedMonitors.includes(monitorId)) {
                linkedMonitors.push(monitorId)
            }
        } else {
            var index = linkedMonitors.indexOf(monitorId)
            if (index !== -1) {
                linkedMonitors.splice(index, 1)
            }
        }
    }

    function updateLinkedMonitors(sourceMonitorId, brightness) {
        if (linkedMonitors.includes(sourceMonitorId)) {
            for (var i = 0; i < monitorManager.monitors.length; i++) {
                var monitor = monitorManager.monitors[i]
                if (linkedMonitors.includes(monitor.id) && monitor.id !== sourceMonitorId) {
                    monitor.brightness = brightness
                }
            }
        }
    }

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

    // Close button
    Rectangle {
        id: closeButton
        width: 16
        height: 16
        color: closeMouseArea.containsMouse ? "#ff5555" : "transparent"
        radius: 8
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            id: closeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mainWindow.hide()
        }
    }

    // Main content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Title
        Text {
            Layout.fillWidth: true
            text: "Monitor Brightness Control"
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
            Layout.bottomMargin: 5
        }

        // Monitors list
        ListView {
            id: monitorListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            model: monitorManager.monitors

            delegate: MonitorSlider {
                width: monitorListView.width
                monitorName: modelData.displayName
                brightnessValue: modelData.brightness
                isControllable: modelData.controllable
                isLinked: linkedMonitors.includes(modelData.id)

                onBrightnessChanged: {
                    modelData.brightness = value
                    updateLinkedMonitors(modelData.id, value)
                }

                onLinkToggled: {
                    toggleMonitorLink(modelData.id, linked)
                }
            }

            // Empty state message
            Item {
                anchors.fill: parent
                visible: monitorManager.monitors.length === 0

                Text {
                    anchors.centerIn: parent
                    text: monitorManager.ddcUtilAvailable ?
                        "No compatible monitors found" :
                        "ddcutil not available. Please install it."
                    color: "#cccccc"
                    font.pixelSize: 12
                    width: parent.width - 20
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Refresh button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: refreshMouseArea.containsMouse ? "#2a2a2a" : "#262626"
            radius: 3

            Text {
                anchors.centerIn: parent
                text: "Refresh Monitors"
                color: "#ffffff"
                font.pixelSize: 12
            }

            MouseArea {
                id: refreshMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: monitorManager.detectMonitors()
            }
        }
    }

    // System tray integration
    SystemTrayIcon {
        id: sysTrayIcon
        visible: true
        tooltip: "Monitor Brightness Control"

        onActivated: {
            if (reason === SystemTrayIcon.Trigger) {
                if (mainWindow.visible) {
                    mainWindow.hide()
                } else {
                    monitorManager.detectMonitors()
                    showAtSystemTrayPosition()
                }
            }
        }

        menu: Menu {
            MenuItem {
                text: "Open"
                onTriggered: {
                    monitorManager.detectMonitors()
                    showAtSystemTrayPosition()
                }
            }
            MenuItem {
                text: "Exit"
                onTriggered: Qt.quit()
            }
        }
    }
}