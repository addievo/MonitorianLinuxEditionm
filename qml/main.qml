import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

Window {
    id: mainWindow
    visible: true
    width: 320
    height: Math.min(Math.max(150, 48 * monitorManager.monitors.length + 100), 400) * 1.15
    title: "Monitor Brightness Control"
    color: "#f5f5f5"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Shadow effect for the window
    Rectangle {
        id: shadowRect
        anchors.fill: parent
        color: "transparent"
        border.color: "#20000000"
        border.width: 1
        radius: 4
    }

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

    // Linked monitors management
    property var linkedMonitors: []
    signal linkedMonitorsUpdated() // Changed from linkedMonitorsChanged to avoid conflict

    function toggleMonitorLink(monitorId, linked) {
        if (linked) {
            if (!linkedMonitors.includes(monitorId)) {
                linkedMonitors.push(monitorId)
                console.log("Linked monitor: " + monitorId)
            }
        } else {
            var index = linkedMonitors.indexOf(monitorId)
            if (index !== -1) {
                linkedMonitors.splice(index, 1)
                console.log("Unlinked monitor: " + monitorId)
            }
        }
        linkedMonitorsUpdated()
    }

    function updateLinkedMonitors(sourceMonitorId, brightness) {
        // Only update if the source monitor is linked
        if (linkedMonitors.includes(sourceMonitorId)) {
            for (var i = 0; i < monitorManager.monitors.length; i++) {
                var monitor = monitorManager.monitors[i]
                if (linkedMonitors.includes(monitor.id) && monitor.id !== sourceMonitorId) {
                    console.log("Syncing monitor: " + monitor.id + " to brightness: " + brightness)
                    monitor.brightness = brightness
                }
            }
        }
    }

    function isAllLinked() {
        if (monitorManager.monitors.length === 0) return false

        for (var i = 0; i < monitorManager.monitors.length; i++) {
            if (!linkedMonitors.includes(monitorManager.monitors[i].id)) {
                return false
            }
        }
        return true
    }

    function linkAllMonitors(link) {
        if (link) {
            // Link all monitors
            linkedMonitors = []
            for (var i = 0; i < monitorManager.monitors.length; i++) {
                linkedMonitors.push(monitorManager.monitors[i].id)
            }
        } else {
            // Unlink all monitors
            linkedMonitors = []
        }
        linkedMonitorsUpdated()
    }

    // Allow dragging the window
    Rectangle {
        id: titleBar
        height: 32
        color: "#007ACC"
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        radius: 4

        // Only top corners should be rounded
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: parent.radius
            color: parent.color
        }

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }
            text: "Monitor Brightness Control"
            color: "#ffffff"
            font.pixelSize: 13
            font.bold: true
        }

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
            width: 32
            height: parent.height
            color: closeMouseArea.containsMouse ? "#E81123" : "transparent"
            anchors.right: parent.right
            anchors.top: parent.top

            Text {
                anchors.centerIn: parent
                text: "×"
                color: "#ffffff"
                font.pixelSize: 18
                font.bold: true
            }

            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: mainWindow.hide()
            }
        }

        // Minimize button
        Rectangle {
            id: minimizeButton
            width: 32
            height: parent.height
            color: minimizeMouseArea.containsMouse ? "#3A3A3A" : "transparent"
            anchors.right: closeButton.left
            anchors.top: parent.top

            Text {
                anchors.centerIn: parent
                text: "−"
                color: "#ffffff"
                font.pixelSize: 18
                font.bold: true
            }

            MouseArea {
                id: minimizeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: mainWindow.showMinimized()
            }
        }
    }

    // Main content
    Item {
        anchors {
            top: titleBar.bottom
            left: parent.left
            right: parent.right
            bottom: statusBar.top
            margins: 0
        }

        // Monitors list
        ListView {
            id: monitorListView
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            spacing: 8
            model: monitorManager.monitors
            interactive: false // Disable scrolling

            delegate: MonitorSlider {
                width: monitorListView.width
                monitorName: modelData.displayName
                brightnessValue: modelData.brightness
                isControllable: modelData.controllable
                isLinked: linkedMonitors.includes(modelData.id)

                // Respond to global linked monitors changes
                Connections {
                    target: mainWindow
                    function onLinkedMonitorsUpdated() {
                        isLinked = linkedMonitors.includes(modelData.id)
                    }
                }

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

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.9
                    height: 100
                    color: "#f0f0f0"
                    radius: 4
                    border.color: "#e0e0e0"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: monitorManager.ddcUtilAvailable ?
                                "No compatible monitors found" :
                                "ddcutil not available"
                            color: "#505050"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: monitorManager.ddcUtilAvailable ?
                                "Connect DDC-compatible monitors" :
                                "Please install ddcutil and ensure proper permissions"
                            color: "#707070"
                            font.pixelSize: 12
                            width: parent.width - 20
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Status bar
    Rectangle {
        id: statusBar
        height: 40
        color: "#f0f0f0"
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        radius: 4

        // Only bottom corners should be rounded
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: parent.radius
            color: parent.color
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 8

            // Refresh button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: refreshMouseArea.containsMouse ? "#e6e6e6" : "#f0f0f0"
                radius: 3
                border.color: "#d0d0d0"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        id: refreshIcon
                        text: "⟳"
                        color: "#404040"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter

                        // Rotation behavior
                        Behavior on rotation {
                            NumberAnimation { duration: 500 }
                        }
                    }

                    Text {
                        text: "Refresh"
                        color: "#404040"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        refreshIcon.rotation += 360
                        monitorManager.detectMonitors()
                    }
                }
            }

            // Link/Unlink all button
            Rectangle {
                id: linkAllButton
                Layout.preferredWidth: 110
                Layout.preferredHeight: 28
                color: isAllLinked() ? "#e2f0ff" : (linkAllMouseArea.containsMouse ? "#e6e6e6" : "#f0f0f0")
                radius: 3
                border.color: isAllLinked() ? "#6bbbff" : "#d0d0d0"
                border.width: 1
                visible: monitorManager.monitors.length > 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 2
                        color: isAllLinked() ? "#007ACC" : "transparent"
                        border.color: isAllLinked() ? "#007ACC" : "#888888"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#ffffff"
                            font.pixelSize: 9
                            visible: isAllLinked()
                        }
                    }

                    Text {
                        text: isAllLinked() ? "Unlink All" : "Link All"
                        color: "#404040"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: linkAllMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        linkAllMonitors(!isAllLinked())
                    }
                }
            }
        }
    }

    // Status notification
    Rectangle {
        id: notification
        width: notificationText.width + 32
        height: 36
        color: "#4C4C4C"
        radius: 4
        opacity: 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10

        Text {
            id: notificationText
            anchors.centerIn: parent
            color: "#ffffff"
            font.pixelSize: 12
        }

        // Show/hide animations
        NumberAnimation on opacity {
            id: showNotification
            from: 0
            to: 1
            duration: 200
            running: false
        }

        NumberAnimation on opacity {
            id: hideNotification
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
            // Only show error messages that are NOT related to brightness setting
            if (!message.includes("Failed to set brightness")) {
                notificationText.text = message
                showNotification.start()
                notificationTimer.restart()
            }
        }
    }

    Timer {
        id: notificationTimer
        interval: 3000
        onTriggered: hideNotification.start()
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